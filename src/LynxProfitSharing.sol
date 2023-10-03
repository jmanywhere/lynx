//SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/security/ReentrancyGuard.sol";
import "./interfaces/ILynx.sol";
import "./interfaces/ILynxHolder.sol";

error LynxPS__InvalidETHAmount();
error LynxPS__InvalidDistributionAmount();
error LynxPS__AddressExcluded();
error LynxPS__UnableToClaim();

contract LynxProfitSharing is Ownable, ReentrancyGuard {
    //-------------------------------------------------------------------------
    // Data Types
    //-------------------------------------------------------------------------
    struct Distribution {
        uint totalPot; // total ETH to Distribute
        uint tier1Divs; // 60% of totalPot distributed in all t1 tokens
        uint tier2Divs; // 40% of totalPot distributed in all t2 tokens
        uint qualifyingSnapshot;
        uint verificationSnapshot;
        uint claimedt1;
        uint claimedt2;
    }

    struct Excluded {
        bool token; // true if token already takes care of reductions
        bool status; // is the main status exclusion
    }
    //-------------------------------------------------------------------------
    // State Variables
    //-------------------------------------------------------------------------
    mapping(uint distributedIDs => Distribution) public distributions;
    mapping(address excludedAddress => Excluded) public excluded;
    mapping(address user => mapping(uint distId => bool claimed))
        public claimed;
    mapping(address contractAddress => uint index) public alterations;

    address[] public alterationList = [address(0)];
    address[] public excludedList;

    ILynx public immutable lynx;

    uint public distributionId;

    uint public tier1Divs = 6;
    uint public tier2Divs = 4;
    uint public totalTiers = 10;
    uint private constant TIER_1 = 50_000 ether;
    uint private constant TIER_2 = 1_000 ether;
    uint private constant MAGNIFIER = 1e18;

    //-------------------------------------------------------------------------
    // Events
    //-------------------------------------------------------------------------
    event DistributeDividends(
        address indexed sender,
        uint amount,
        uint startSnapshotId,
        uint endSnapshotId
    );
    event UpdateTierDistribution(uint tier1Divs, uint tier2Divs);
    event ExcludeAddressFromDividends(address user);

    //-------------------------------------------------------------------------
    // CONSTRUCTOR
    //-------------------------------------------------------------------------
    constructor(address _lynx) {
        lynx = ILynx(_lynx);
    }

    //-------------------------------------------------------------------------
    // External & Public Functions
    //-------------------------------------------------------------------------
    /**
     * Updates the tier proportions for the NEXT distribution of dividends
     * @param _tier1Divs Tier 1 proportion of the total distribution
     * @param _tier2Divs Tier 2 proportion of the total distribution
     */
    function setTierProportions(
        uint _tier1Divs,
        uint _tier2Divs
    ) external onlyOwner {
        if (_tier1Divs == 0 || _tier2Divs == 0)
            revert LynxPS__InvalidDistributionAmount();

        totalTiers = _tier1Divs + _tier2Divs;
        tier1Divs = _tier1Divs;
        tier2Divs = _tier2Divs;

        emit UpdateTierDistribution(_tier1Divs, _tier2Divs);
    }

    /**
     * Exclude an address from receiving dividends
     * @param user Address to exclude
     * @dev the user is set as excluded and added to the excluded list
     * @dev this is a permanent action with no reversal action added to it
     */
    function excludeAddressFromDividends(address user) public onlyOwner {
        bool tokenExempt = lynx.isDividendExempt(user);
        excluded[user] = Excluded({status: true, token: tokenExempt});
        excludedList.push(user);
        emit ExcludeAddressFromDividends(user);
    }

    /**
     * @notice Distribute the dividends to all the holders
     */
    function distributeDividends() external payable nonReentrant {
        if (msg.value == 0) revert LynxPS__InvalidETHAmount();
        uint currentValue = msg.value;
        // Get the current snapshot ID
        uint qualifyingSnapshot = lynx.currentSnapId();
        (uint ad_t1, uint ad_t2, uint sum_t2) = tierAdjustments();
        lynx.takeSnapshot();
        (uint t1, uint t2, ) = lynx.snapshots(qualifyingSnapshot);

        t1 -= ad_t1;
        t2 = t2 - ad_t2 + sum_t2;

        ad_t1 = (currentValue * MAGNIFIER * tier1Divs) / (totalTiers * t1);
        ad_t2 = (currentValue * MAGNIFIER * tier2Divs) / (totalTiers * t2);

        Distribution storage distribution = distributions[distributionId];
        distributionId++;

        distribution.totalPot = msg.value;
        distribution.qualifyingSnapshot = qualifyingSnapshot;
        distribution.verificationSnapshot = qualifyingSnapshot + 1;
        distribution.tier1Divs = ad_t1;
        distribution.tier2Divs = ad_t2;
    }

    function claimDividends(uint[] calldata idsToClaim) external {
        uint totalToClaim;
        uint idsToClaimLength = idsToClaim.length;

        if (excluded[msg.sender].status) revert LynxPS__AddressExcluded();

        for (uint i = 0; i < idsToClaimLength; i++) {
            uint id = idsToClaim[i];
            totalToClaim += _claimDividendsById(msg.sender, id);
        }

        if (totalToClaim > 0) {
            (bool succ, ) = payable(msg.sender).call{value: totalToClaim}("");
            if (!succ) revert LynxPS__UnableToClaim();
        }
    }

    function claimDividends(uint id) public {
        if (excluded[msg.sender].status) revert LynxPS__AddressExcluded();
        uint totalToClaim = _claimDividendsById(msg.sender, id);
        if (totalToClaim > 0) {
            (bool succ, ) = payable(msg.sender).call{value: totalToClaim}("");
            if (!succ) revert LynxPS__UnableToClaim();
        }
    }

    function claimForUsers(address[] calldata users, uint distId) external {
        uint userLength = users.length;
        for (uint i = 0; i < userLength; i++) {
            address userToClaim = users[i];
            uint claimAmount = _claimDividendsById(userToClaim, distId);
            if (claimAmount > 0) {
                (bool succ, ) = payable(userToClaim).call{value: claimAmount}(
                    ""
                );
                if (!succ) revert LynxPS__UnableToClaim();
            }
        }
    }

    /**
     * Add address to the list of alterations. This is used to add contracts that hold tokens they are not the final owners of the tokens.
     * @param _user The wallet to add to the alterations list
     */
    function addAddressToDiffs(address _user) external onlyOwner {
        if (excluded[_user].status) revert LynxPS__AddressExcluded();
        claimed[_user][distributionId] = true;

        excluded[_user] = Excluded({
            status: true,
            token: lynx.isDividendExempt(_user)
        });

        alterations[_user] = alterationList.length;
        alterationList.push(_user);
    }

    /**
     * @notice Get the tier1 and 2 adjustments to make the distribution more accurate
     * @return tier1 Amount of Tier1 that is not elligible for dividends
     * @return tier2 Amount of Tier2 that is not elligible for dividends
     * @return t2Sum Amount of Tier2 that is elligible for dividends but it's hidden inside a t1 total holder
     */
    function tierAdjustments()
        public
        view
        returns (uint tier1, uint tier2, uint t2Sum)
    {
        uint excludedLength = excludedList.length;
        for (uint i = 0; i < excludedLength; i++) {
            address testedAddress = excludedList[i];
            (uint t1, uint t2) = _checkAddressBalance(testedAddress);
            tier1 += t1;
            tier2 += t2;
        }
        excludedLength = alterationList.length;
        for (uint i = 1; i < excludedLength; i++) {
            address testedAddress = alterationList[i];
            (uint t1, uint t2) = _checkAddressBalance(testedAddress);
            (uint ad1, uint ad2) = ILynxHolder(testedAddress).getTiers();
            if (t1 > ad1) {
                tier1 += t1 - ad1;
                t2Sum += ad2;
            } else if (t2 > 0) {
                tier2 += ad2;
            }
        }
    }

    //-------------------------------------------------------------------------
    // Internal & Private Functions
    //-------------------------------------------------------------------------

    /**
     *
     * @param _user The User to claim the dividends
     * @param _id The Distribution ID to claim the dividends
     * @return dividends The amount of dividends to be claimed
     */
    function _claimDividendsById(
        address _user,
        uint _id
    ) private returns (uint dividends) {
        if (claimed[_user][_id]) return 0;
        claimed[_user][_id] = true;
        uint divAmount = _claimDividends(_user, _id);

        uint totalAlterations = alterationList.length;
        if (totalAlterations > 1) {
            for (uint j = 1; j < totalAlterations; j++) {
                address alt = alterationList[j];
                divAmount += _claimAlteredDividends(msg.sender, alt, _id);
            }
        }

        return divAmount;
    }

    /**
     * Finds out if tokens belong to tier 1, tier 2 or none
     * @param _user The owner of LYNX tokens
     * @return t1 Amount of tokens in tier 1
     * @return t2 Amount of tokens in tier 2
     */
    function _checkAddressBalance(
        address _user
    ) private view returns (uint t1, uint t2) {
        Excluded memory testedExcluded = excluded[_user];
        if (testedExcluded.token) return (0, 0);
        uint balance = lynx.balanceOf(_user);
        if (balance >= TIER_1) t1 += balance;
        else if (balance >= TIER_2) t2 += balance;
    }

    /**
     * @notice Claim the dividends for a specific distribution
     * @param _user The user to claim the dividends for
     * @param _id The distribution ID to claim the dividends for
     * @return divAmount The amount of dividends claimed
     */
    function _claimDividends(
        address _user,
        uint _id
    ) private view returns (uint divAmount) {
        Distribution storage distribution = distributions[_id];
        if (distribution.totalPot == 0) return 0;
        if (distribution.verificationSnapshot > lynx.currentSnapId()) return 0;

        uint qualifying = lynx.getUserSnapshotAt(
            _user,
            distribution.qualifyingSnapshot
        );
        if (qualifying == 0) return 0;

        if (qualifying >= TIER_1) divAmount = distribution.tier1Divs;
        else if (qualifying >= TIER_2) divAmount = distribution.tier2Divs;

        uint verified = lynx.getUserSnapshotAt(
            _user,
            distribution.verificationSnapshot
        );

        if (qualifying > verified) return 0;

        divAmount = (divAmount * qualifying) / MAGNIFIER;
    }

    /**
     * @notice Claim the dividends on a contract that holds tokens for other users
     * @param _user The user to claim the dividends for
     * @param _alt The address of the contract that holds the tokens
     * @param _distId The distribution ID to claim the dividends for
     * @return divAmount The amount of dividends claimed
     */

    function _claimAlteredDividends(
        address _user,
        address _alt,
        uint _distId
    ) private view returns (uint divAmount) {
        Distribution storage distribution = distributions[_distId];
        if (distribution.totalPot == 0) return 0;
        if (distribution.verificationSnapshot > lynx.currentSnapId()) return 0;

        uint qualifying = ILynxHolder(_alt).getUserBalanceAtSnapId(
            _user,
            distribution.qualifyingSnapshot
        );
        if (qualifying >= TIER_1) divAmount = distribution.tier1Divs;
        else if (qualifying >= TIER_2) divAmount = distribution.tier2Divs;

        uint verified = ILynxHolder(_alt).getUserBalanceAtSnapId(
            _user,
            distribution.verificationSnapshot
        );

        if (qualifying > verified) return 0;

        divAmount = (divAmount * qualifying) / MAGNIFIER;
    }
}
