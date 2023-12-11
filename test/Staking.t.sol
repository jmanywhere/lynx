// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import "../src/LynxStaking.sol";
import "../src/LynxVault.sol";
import "openzeppelin/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract Test_Staking is Test {
    LynxStaking staking;
    LynxVault vault;
    ERC20PresetFixedSupply lynx;
    uint currentTime;

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    address user4 = makeAddr("user4");

    uint constant DEPOSIT_AMOUNT = 1_000 ether;
    uint constant INIT_VAULT = 1_000_000 ether;

    function setUp() public {
        lynx = new ERC20PresetFixedSupply(
            "Lynx",
            "LYNX",
            10_000_000 ether,
            address(this)
        );
        vault = new LynxVault(address(lynx));
        staking = new LynxStaking(
            block.timestamp,
            address(lynx),
            address(vault),
            17_99,
            2
        );
        currentTime = staking.LockStart();
        lynx.transfer(address(vault), INIT_VAULT);
        lynx.transfer(user1, 1_000 ether);
        lynx.transfer(user2, 1_000 ether);
        lynx.transfer(user3, 1_100 ether);
        lynx.transfer(user4, 1_000 ether);
        vm.prank(user1);
        lynx.approve(address(staking), type(uint).max);
        vm.prank(user2);
        lynx.approve(address(staking), type(uint).max);
        vm.prank(user3);
        lynx.approve(address(staking), type(uint).max);
        vm.prank(user4);
        lynx.approve(address(staking), type(uint).max);
        vault.setWhitelistStatus(address(staking), true);
    }

    function test_calculate_end_time() public {
        uint endStakeTime = staking.calculateEndTime(2 weeks);
        assertEq(endStakeTime, currentTime + 3 weeks);
    }

    function test_deposit() public {
        vm.startPrank(user1);
        staking.deposit(DEPOSIT_AMOUNT);

        (
            uint deposit,
            uint start,
            uint end,
            uint pos,
            uint locked,
            bool set
        ) = staking.stake(user1);
        (, uint apr, ) = staking.aprConfig();

        assertEq(lynx.balanceOf(address(staking)), 0);
        assertEq(lynx.balanceOf(address(vault)), INIT_VAULT + DEPOSIT_AMOUNT);
        assertEq(deposit, DEPOSIT_AMOUNT);
        assertEq(start, block.timestamp);
        assertEq(end, staking.calculateEndTime(2 weeks));
        assertEq(pos, 0);
        assertEq(locked, 0);
        assertEq(apr, 17_99);
        assertTrue(set);

        vm.expectRevert(
            abi.encodeWithSelector(LYNXStaking__WithdrawLocked.selector, end)
        );
        staking.withdraw();
        vm.stopPrank();
    }

    function test_reward_calc() public {
        vm.prank(user2);
        staking.deposit(DEPOSIT_AMOUNT);

        skip(3 hours);

        uint rewardsExpected = uint(1_000 ether * 17_99 * 3 hours) /
            (100_00 * 365 days);

        uint rewards = staking.currentRewards(user2);

        assertEq(rewardsExpected, rewards);
    }

    function test_withdraw() public {
        vm.prank(user1);
        staking.deposit(DEPOSIT_AMOUNT);

        skip(3 weeks);

        // Rewards should be truncated;
        uint expectedRewards = uint(1_000 ether * 17_99 * 3 weeks) /
            (100_00 * 365 days);
        uint rewards = staking.currentRewards(user1);
        assertEq(expectedRewards, rewards);

        (, , uint end, , , ) = staking.stake(user1);
        assertEq(end, block.timestamp);

        vm.prank(user1);
        staking.withdraw();
        assertEq(lynx.balanceOf(user1), DEPOSIT_AMOUNT + expectedRewards);
        assertEq(lynx.balanceOf(address(vault)), INIT_VAULT - expectedRewards);
    }

    function test_doubleDeposit() public {
        vm.prank(user3);
        staking.deposit(DEPOSIT_AMOUNT);

        skip(1 weeks);

        uint expectedLock = staking.currentRewards(user3);
        vm.prank(user3);
        staking.deposit(10 ether);

        (uint dep, , uint nextWithdraw, , uint locked, ) = staking.stake(user3);
        assertEq(lynx.balanceOf(user3), 90 ether);
        assertEq(dep, DEPOSIT_AMOUNT + 10 ether);
        assertEq(locked, expectedLock);
        assertEq(0, staking.currentRewards(user3));

        assertEq(nextWithdraw, block.timestamp + 3 weeks);
    }
}
