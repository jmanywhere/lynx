//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "./interfaces/ILynxStaking.sol";
import "./interfaces/ILynxVault.sol";
import "openzeppelin/token/ERC20/IERC20.sol";

error LYNXStaking__InvalidDepositAmount();
error LYNXStaking__InvalidAprSelected();
error LYNXStaking__WithdrawLocked(uint lockEndTime);

contract LynxStaking is ILynxStaking {
    //--------------------------------------------------------------------
    // State Variables
    //--------------------------------------------------------------------
    mapping(address => Stake) public stake;
    mapping(uint8 => AprConfig) public aprConfig;

    address[] public stakers;
    IERC20 public lynx;
    ILynxVault public vault;
    uint256 public totalStaked;
    uint256 public totalClaimed;
    uint256 public constant REWARD_APR_BASE = 100_00; // 100.00%
    uint256 public immutable LockStart;

    //--------------------------------------------------------------------
    // Modifiers
    //--------------------------------------------------------------------
    modifier checkApr(uint8 aprSelector) {
        if (aprConfig[aprSelector].setup) _;
        else revert LYNXStaking__InvalidAprSelected();
    }

    //--------------------------------------------------------------------
    // Construtor
    //--------------------------------------------------------------------
    constructor(uint weekStart, address _lynx, address _vault) {
        LockStart = weekStart;
        aprConfig[0] = AprConfig(17_99, 2, true);
        aprConfig[1] = AprConfig(20_00, 4, true);
        aprConfig[2] = AprConfig(25_00, 12, true);
        lynx = IERC20(_lynx);
        vault = ILynxVault(_vault);
    }

    //--------------------------------------------------------------------
    // External / Public Functions
    //--------------------------------------------------------------------
    function deposit(
        uint amount,
        uint8 apr_choice
    ) external checkApr(apr_choice) {
        if (amount == 0) revert LYNXStaking__InvalidDepositAmount();
        Stake storage currentStake = stake[msg.sender];
        AprConfig storage aprSelected = aprConfig[apr_choice];
        uint16 duration = aprSelected.duration;

        if (currentStake.set) {
            uint reward = currentRewards(msg.sender);
            // IF reward time is over, claim rewards and reset the user
            if (currentStake.rewardEnd < block.timestamp) {
                // claim rewards
                totalClaimed += reward;
                vault.withdrawTo(msg.sender, reward);
                emit ClaimRewards(msg.sender, reward);
                // update user.
                currentStake.apr_choice = apr_choice;
            }
            // ELSE
            else {
                // lock rewards accrued so far and add the new deposit to the existing one
                currentStake.lockedRewards += reward;
                emit LockedRewards(msg.sender, reward);
                // select the longest duration
                // reset the lock time to whichever APR is higher.
                duration = currentStake.apr_choice > apr_choice
                    ? currentStake.apr_choice
                    : apr_choice;
                currentStake.apr_choice = uint8(duration);
                duration = aprConfig[uint8(duration)].duration;
            }
            currentStake.depositAmount += amount;
        } else {
            currentStake.depositAmount = amount;
            currentStake.posIndex = stakers.length;
            currentStake.apr_choice = apr_choice;
            currentStake.set = true;
            stakers.push(msg.sender);
        }

        currentStake.startStake = block.timestamp;
        currentStake.rewardEnd = calculateEndTime(duration);
        // Transfer Deposit amounts to Vault
        lynx.transferFrom(msg.sender, address(vault), amount);
        emit Deposit(msg.sender, amount, duration, currentStake.rewardEnd);
    }

    function withdraw() external {
        Stake storage currentStake = stake[msg.sender];
        if (block.timestamp < currentStake.rewardEnd)
            revert LYNXStaking__WithdrawLocked(currentStake.rewardEnd);

        // Claim rewards
        uint reward = currentRewards(msg.sender);
        emit ClaimRewards(msg.sender, reward);
        vault.withdrawTo(msg.sender, reward + currentStake.depositAmount);

        // remove user from stake list
        address lastIdxUser = stakers[stakers.length - 1];
        stakers[currentStake.posIndex] = lastIdxUser;
        stake[lastIdxUser].posIndex = currentStake.posIndex;
        stakers.pop();
        // reset the user
        stake[msg.sender] = Stake(0, 0, 0, 0, 0, 0, false);
    }

    function currentRewards(address user) public view returns (uint256) {
        Stake storage currentStake = stake[user];

        AprConfig storage aprSelected = aprConfig[currentStake.apr_choice];

        if (currentStake.depositAmount == 0 || !currentStake.set) return 0;

        uint256 rewardEnd = currentStake.rewardEnd;
        uint256 rewardAmount = 0;

        if (block.timestamp > rewardEnd) {
            rewardAmount = rewardEnd - currentStake.startStake;
        } else {
            rewardAmount = block.timestamp - currentStake.startStake;
        }

        rewardAmount =
            (currentStake.depositAmount * rewardAmount * aprSelected.apr) /
            (REWARD_APR_BASE * 365 days);

        return rewardAmount;
    }

    function calculateEndTime(uint16 duration) public view returns (uint256) {
        uint currentWeek = (block.timestamp - LockStart) / 1 weeks;
        currentWeek = currentWeek + uint256(duration) + 1;
        return LockStart + (currentWeek * 1 weeks);
    }

    function getStakers()
        external
        view
        returns (address[] memory users, uint256[] memory balances)
    {
        users = new address[](stakers.length);
        balances = new uint256[](stakers.length);
        for (uint i = 0; i < stakers.length; i++) {
            users[i] = stakers[i];
            balances[i] = stake[stakers[i]].depositAmount;
        }
    }

    //--------------------------------------------------------------------
    // Internal / Private Functions
    //--------------------------------------------------------------------
}
