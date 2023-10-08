//SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import {Ownable} from "openzeppelin/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin/security/ReentrancyGuard.sol";
import "./interfaces/ILynx.sol";

error LynxPS__InvalidMsgValue();
error LynxPS__InvalidIndexesLength();
error LynxPS__InvalidClaimer();
error LynxPS__ExcludedClaimer();
error LynxPS__AlreadyClaimedOrInvalidSnapshotClaim();
error LynxPS__ETHTransferFailed();
error LynxPS__VerificationTierFailure(uint snapId, uint tierQ, uint tierV);
error LynxPS__InvalidReclaim();

contract LynxManualProfitDistribution is Ownable, ReentrancyGuard {
    //------------------------
    //  Type Definitions
    //------------------------
    struct Snapshot {
        address[] holders;
        uint128[] balances;
        uint128 totalTier1;
        uint128 totalTier2;
        uint128 t1Claimed;
        uint128 t2Claimed;
        uint128 t1Distribution;
        uint128 t2Distribution;
        bool fullClaim;
    }
    //------------------------
    //  State Variables
    //------------------------
    ILynx public immutable lynx;
    mapping(uint _snapId => Snapshot) public snapshots;
    mapping(address user => mapping(uint _snapId => bool)) public claimed;
    mapping(address user => bool) public excluded;

    uint128 public tier1;
    uint128 public tier2;
    uint128 public totalTiers;
    uint private constant TIER1 = 50_000 ether;
    uint private constant TIER2 = 1_000 ether;
    uint128 private constant MAGNIFIER = 1 ether;

    //------------------------
    //  Events
    //------------------------
    event CreateSnapshot(
        uint indexed snapId,
        uint128 t1Distribution,
        uint128 t2Distribution
    );

    event ExcludeAddress(address indexed user);
    event ExcludeMultipleAddresses(address[] indexed users);
    event ReclaimDivs(uint indexed snapId, uint128 amount);

    //------------------------
    //  Constructor
    //------------------------
    constructor(address _lynx, address _newOwner) {
        lynx = ILynx(_lynx);
        tier1 = 60;
        tier2 = 40;
        totalTiers = 100;
        transferOwnership(_newOwner);
    }

    //------------------------
    //  External Functions
    //------------------------

    /**
     *
     * @param holders Array to all VALID holders
     * @param balances Array of balances of each holder
     * @param t1Excluded Amount of tokens excluded from TIER 1 (That are not already divExcluded in Token)
     * @param t2Excluded Amount of tokens excluded from TIER 2 (That are not already divExcluded in Token)
     */
    function createSnapshot(
        address[] calldata holders,
        uint128[] calldata balances,
        uint128 t1Excluded,
        uint128 t2Excluded
    ) external payable onlyOwner {
        if (msg.value == 0) revert LynxPS__InvalidMsgValue();
        // TAKE SNAPSHOT
        uint currentSnapId = lynx.currentSnapId();
        lynx.takeSnapshot();
        // GET TOTAL TIERS FROM SNAPSHOT
        (uint tier1Total, uint tier2Total, ) = lynx.snapshots(currentSnapId);
        tier1Total -= t1Excluded;
        tier2Total -= t2Excluded;
        // SET TIMESTAMP (JUST FOR REFERENCE)
        snapshots[currentSnapId].totalTier1 = uint128(tier1Total);
        snapshots[currentSnapId].totalTier2 = uint128(tier2Total);
        snapshots[currentSnapId].holders = holders;
        snapshots[currentSnapId].balances = balances;
        // GET THE DISTRIBUTION AMOUNTS PER TOKEN
        uint128 t1Distribution = (uint128(msg.value) * tier1) / totalTiers;
        uint128 t2Distribution = uint128(msg.value) - t1Distribution;

        t1Distribution = (t1Distribution * MAGNIFIER) / uint128(tier1Total);
        t2Distribution = (t2Distribution * MAGNIFIER) / uint128(tier2Total);
        snapshots[currentSnapId].t1Distribution = uint128(t1Distribution);
        snapshots[currentSnapId].t2Distribution = uint128(t2Distribution);
        emit CreateSnapshot(currentSnapId, t1Distribution, t2Distribution);
    }

    /**
     *
     * @param claimIds Array of snapshot IDs to claim
     * @param claimQualifierIndexId The index of the user in the qualifier snapshot
     * @param claimVerifierIndexId The index of the user in the verifier snapshot
     */
    function claimDivs(
        uint[] calldata claimIds,
        uint[] calldata claimQualifierIndexId,
        uint[] calldata claimVerifierIndexId
    ) external nonReentrant {
        if (excluded[msg.sender]) revert LynxPS__ExcludedClaimer();
        uint currentSnapId = lynx.currentSnapId();
        uint claimsLength = claimIds.length;
        if (
            claimsLength != claimQualifierIndexId.length ||
            claimsLength != claimVerifierIndexId.length
        ) revert LynxPS__InvalidIndexesLength();
        uint128 totalReward;
        for (uint8 i = 0; i < claimsLength; i++) {
            uint qualifyId = claimIds[i];
            uint verifyId = qualifyId + 1;
            // Already claimed || invalid claimID
            if (
                claimed[msg.sender][qualifyId] ||
                qualifyId >= currentSnapId ||
                snapshots[qualifyId].fullClaim
            ) revert LynxPS__AlreadyClaimedOrInvalidSnapshotClaim();
            if (
                snapshots[qualifyId].holders[claimQualifierIndexId[i]] !=
                msg.sender ||
                snapshots[verifyId].holders[claimVerifierIndexId[i]] !=
                msg.sender
            ) revert LynxPS__InvalidClaimer();

            // Get balances
            uint128 qualifyBalance = snapshots[qualifyId].balances[
                claimQualifierIndexId[i]
            ];
            uint128 verifyBalance = snapshots[verifyId].balances[
                claimVerifierIndexId[i]
            ];

            // Verify initial Tier
            uint8 initialTier = getTierOfBalance(qualifyBalance);
            if (initialTier == 0)
                revert LynxPS__VerificationTierFailure(
                    qualifyId,
                    initialTier,
                    0
                );
            uint8 verifyTier = getTierOfBalance(verifyBalance);
            // Check balances remained in same tier
            if (initialTier != verifyTier)
                revert LynxPS__VerificationTierFailure(
                    qualifyId,
                    initialTier,
                    verifyTier
                );
            totalReward += calculateReward(
                qualifyId,
                qualifyBalance,
                initialTier
            );
        }

        totalReward /= MAGNIFIER;

        if (totalReward > 0) {
            (bool status, ) = payable(msg.sender).call{value: totalReward}("");
            if (!status) revert LynxPS__ETHTransferFailed();
        }
    }

    /**
     * Excluded users can't claim rewards forever
     * @param _user User to exclude
     */
    function excludeUser(address _user) external onlyOwner {
        _excludeUser(_user);
        emit ExcludeAddress(_user);
    }

    /**
     * Excluded users can't claim rewards forever
     * @param _users Array of users to exclude
     */
    function excludeMultipleUsers(
        address[] calldata _users
    ) external onlyOwner {
        for (uint i = 0; i < _users.length; i++) {
            _excludeUser(_users[i]);
        }
        emit ExcludeMultipleAddresses(_users);
    }

    /**
     * To prevent stuck rewards for too long (and incentivize more user interaction)
     * @param id Snapshot ID to remove unclaimed rewards from
     * @dev This function can only be called 30 days after the snapshot by owner
     */
    function removeUnclaimedRewards(uint id) external onlyOwner {
        // unclaimed can only be called 30days after the snapshot
        (, , uint snapshotTimestamp) = lynx.snapshots(id);
        Snapshot storage snap = snapshots[id];
        if (block.timestamp < snapshotTimestamp + 30 days || snap.fullClaim)
            revert LynxPS__InvalidReclaim();
        uint128 t1Unclaimed = snap.totalTier1 *
            snap.t1Distribution -
            snap.t1Claimed;
        uint128 t2Unclaimed = snap.totalTier2 *
            snap.t2Distribution -
            snap.t2Claimed;

        snap.t1Claimed += t1Unclaimed;
        snap.t2Claimed += t2Unclaimed;
        snap.fullClaim = true;

        t1Unclaimed += t2Unclaimed;
        t1Unclaimed = t1Unclaimed / MAGNIFIER;

        emit ReclaimDivs(id, t1Unclaimed);
        if (t1Unclaimed > 1 gwei) {
            (bool status, ) = payable(owner()).call{value: t1Unclaimed}("");
            if (!status) revert LynxPS__ETHTransferFailed();
        }
    }

    //------------------------
    //  Private Functions
    //------------------------

    /**
     * Change excluded status to true
     * @param _user User to set
     */
    function _excludeUser(address _user) private {
        excluded[_user] = true;
    }

    /**
     *
     * @param snapId ID of the snapshot
     * @param balance Of the user
     * @param _tier to check rewards against
     * @return _reward Amount of rewards Magnified
     * @dev the rewards are magnified so we can do a single division for all things
     */
    function calculateReward(
        uint snapId,
        uint128 balance,
        uint8 _tier
    ) private returns (uint128 _reward) {
        uint128 reward;
        if (_tier == 1) {
            reward = (balance * snapshots[snapId].t1Distribution);
            snapshots[snapId].t1Claimed += reward;
        } else if (_tier == 2) {
            reward = (balance * snapshots[snapId].t2Distribution);
            snapshots[snapId].t2Claimed += reward;
        }
        claimed[msg.sender][snapId] = true;
        return reward;
    }

    //------------------------
    //  View Functions
    //------------------------

    /**
     * Get the index of the user in the snapshot
     * @param snapId The snapshotID to check
     * @param user The user we're searching the Index for
     */
    function getIndexOfUser(
        uint snapId,
        address user
    ) public view returns (uint) {
        uint maxLength = snapshots[snapId].holders.length;
        for (uint i = 0; i < maxLength; i++) {
            if (snapshots[snapId].holders[i] == user) return i;
        }
        return type(uint).max;
    }

    /**
     * Return all indexes of the user in the specific snapshots
     * @param ids Array of snapshot IDs to check
     * @return qualifierIndexes Indexes of the user in the qualifier snapshot
     * @return verificationIndexes Indexes of the user in the verifier snapshot
     * @dev if the user is NOT found in snapshot, the index will be type(uint).max
     * @dev THIS FUNCTION IS ONLY MEANT TO BE CALLED IN THE FRONTEND DUE TO THE EXTREME GAS USAGE IF USED IN CONTRACT
     */
    function getIndexesOfUser(
        uint[] calldata ids
    )
        external
        view
        returns (
            uint[] memory qualifierIndexes,
            uint[] memory verificationIndexes
        )
    {
        uint length = ids.length;
        qualifierIndexes = new uint[](length);
        verificationIndexes = new uint[](length);
        uint currentIndex = lynx.currentSnapId();
        for (uint i = 0; i < length; i++) {
            if (ids[i] >= currentIndex) {
                qualifierIndexes[i] = type(uint).max;
                verificationIndexes[i] = type(uint).max;
                continue;
            }
            uint checkId = ids[i];
            // get qualification index
            qualifierIndexes[i] = getIndexOfUser(checkId, msg.sender);
            // get verification index
            checkId++;
            verificationIndexes[i] = getIndexOfUser(checkId, msg.sender);
        }
    }

    /**
     * @notice Returns all snapshots and the user's index in each snapshot
     * @param user User to check
     * @return ids This is an array of length of all snapshots, the value is the index of the user in the snapshot, while the index is the snapshot ID
     * @return claimable If the index is already claimed
     * @dev THIS FUNCTION IS ONLY MEANT TO BE CALLED IN THE FRONTEND DUE TO THE EXTREME GAS USAGE IF USED IN CONTRACT
     * @dev if the user is NOT found in snapshot, the value at the index will be type(uint).max
     */
    function getAllUserParticipatingSnapshots(
        address user
    ) external view returns (uint[] memory ids, bool[] memory claimable) {
        uint currentSnapId = lynx.currentSnapId();
        ids = new uint[](currentSnapId);
        claimable = new bool[](currentSnapId);
        for (uint i = 0; i < currentSnapId; i++) {
            uint qualifyIndex = getIndexOfUser(i, user);
            ids[i] = qualifyIndex;
            claimable[i] = !claimed[user][i];
        }
    }

    //------------------------
    //  Pure Functions
    //------------------------

    /**
     * Return the tier the balance belongs to ( NO TIER - 0, TIER 1 - 1, TIER 2 - 2)
     * @param amount Amount to check
     * @return _tier Tier of the balance
     */
    function getTierOfBalance(uint amount) private pure returns (uint8 _tier) {
        if (amount >= TIER1) return 1;
        if (amount >= TIER2) return 2;
        return 0;
    }
}