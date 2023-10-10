// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import "../src/LynxToken.sol";

contract TestLynxToken is Test {
    Lynx token;
    IUniswapV2Router02 router;
    IUniswapV2Pair mainPair;

    address admin = makeAddr("admin");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address black = makeAddr("black");
    address blacklister = makeAddr("blacklister");
    uint maxSupply = 5_000_000 ether;
    uint tier1 = 50_000 ether;
    uint tier2 = 1_000 ether;

    function setUp() public {
        token = new Lynx(admin, address(this));
        router = token.router();
        mainPair = IUniswapV2Pair(token.mainPair());

        vm.deal(admin, 10 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(black, 10 ether);

        token.setBlacklister(blacklister);
    }

    function test_init() public {
        assertEq(token.name(), "LYNX");
        assertEq(token.symbol(), "LYNX");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), maxSupply);
        assertEq(token.balanceOf(address(this)), maxSupply);
        assertEq(token.maxWallet(), 75_000 ether);
        assertEq(token.taxThreshold(), 500 ether);
    }

    function test_transfer_regular() public {
        token.transfer(user1, tier1);
        assertEq(token.balanceOf(user1), tier1);
        assertEq(token.balanceOf(address(this)), maxSupply - tier1);
        (uint t1, uint t2, uint time) = token.snapshots(0);
        assertEq(t1, tier1); // user1's balance at current editable snapshot
        assertEq(t2, 0);
        assertEq(time, 0);
        token.transfer(user2, tier1);

        vm.expectRevert(LYNX__TradingNotEnabled.selector);
        vm.prank(user2);
        token.transfer(user1, tier1);

        token.enableTrading();

        vm.expectRevert(
            abi.encodeWithSelector(
                LYNX__MaxWalletReached.selector,
                user1,
                tier1 * 2
            )
        );
        vm.prank(user2);
        token.transfer(user1, tier1);
    }

    function test_blacklist() public {
        token.transfer(black, tier1);

        token.blacklistAddress(black);
        assertTrue(token.isBlacklisted(black));

        (uint totalTier1, , ) = token.snapshots(0);
        assertEq(totalTier1, 0);

        vm.expectRevert();
        token.transfer(black, tier1);

        vm.prank(blacklister);
        token.unblacklistAddress(black);
        assertFalse(token.isBlacklisted(black));

        (totalTier1, , ) = token.snapshots(0);
        assertEq(totalTier1, tier1);
    }

    function test_addLiquidity() public {
        token.approve(address(router), maxSupply);
        //OWNER CAN ADD LIQUIDITY
        router.addLiquidityETH{value: 10 ether}(
            address(token),
            2_000_000 ether,
            2_000_000 ether,
            10 ether,
            address(this),
            block.timestamp
        );

        assertEq(token.balanceOf(address(mainPair)), 2_000_000 ether);
        assertGt(mainPair.totalSupply(), 0);
        assertGt(mainPair.balanceOf(address(this)), 0);
    }

    modifier addedLiquidity() {
        token.approve(address(router), maxSupply);
        //OWNER CAN ADD LIQUIDITY
        router.addLiquidityETH{value: 10 ether}(
            address(token),
            2_000_000 ether,
            2_000_000 ether,
            10 ether,
            address(this),
            block.timestamp
        );
        _;
    }

    function test_disabledTrading() public addedLiquidity {
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(token);

        // We do not set the exact message since uniswap uses it's own error message...
        vm.expectRevert();
        vm.prank(user1);
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: 0.1 ether
        }(0, path, user1, block.timestamp);
    }

    function test_enabledTrading() public addedLiquidity {
        token.enableTrading();
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(token);

        vm.prank(user1);
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: 0.1 ether
        }(0, path, user1, block.timestamp);

        assertGt(token.balanceOf(user1), 0);
    }

    function test_buyTaxes() public addedLiquidity {
        token.enableTrading();

        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(token);

        vm.prank(user1);
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: 0.1 ether
        }(0, path, user1, block.timestamp);

        uint tokenBalance = token.balanceOf(address(token));
        uint userBalance = token.balanceOf(user1);
        assertGt(token.balanceOf(address(token)), 0);

        assertEq(tokenBalance, ((tokenBalance + userBalance) * 5) / 100);
    }

    function test_sellTaxes() public addedLiquidity {
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = router.WETH();

        token.enableTrading();

        token.transfer(user1, 50_000 ether);

        vm.startPrank(user1);
        token.approve(address(router), 1_000 ether);
        uint prevETHBalance = user1.balance;
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            1_000 ether,
            0,
            path,
            user1,
            block.timestamp
        );
        vm.stopPrank();

        assertEq(token.balanceOf(address(token)), 50 ether);
        assertGt(user1.balance, prevETHBalance);
    }

    function test_internalSwap() public addedLiquidity {
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = router.WETH();

        token.enableTrading();

        token.transfer(user1, 10_000 ether);
        token.transfer(user2, 10_000 ether);

        vm.startPrank(user1);
        token.approve(address(router), 10_000 ether);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            10_000 ether,
            0,
            path,
            user1,
            block.timestamp
        );
        vm.stopPrank();

        assertEq(token.balanceOf(address(token)), 500 ether);

        uint adminBalance = admin.balance;

        vm.prank(user2);
        token.transfer(user1, 10 ether);

        // Swap was successful
        assertGt(admin.balance, adminBalance);
        assertLt(token.balanceOf(address(token)), 1 ether);
    }

    function test_snapshotTaking() public {
        token.enableTrading();
        token.transfer(user1, 50_000 ether);
        // USER1 is part of tier1
        (uint totalTier1, uint totalTier2, uint time) = token.snapshots(0);
        assertEq(totalTier1, 50_000 ether);
        assertEq(totalTier2, 0);
        assertEq(time, 0);
        // USER1 drops to tier2
        vm.prank(user1);
        token.transfer(address(this), 1_000 ether);

        (totalTier1, totalTier2, time) = token.snapshots(0);
        assertEq(totalTier1, 0);
        assertEq(totalTier2, 49_000 ether);
        assertEq(time, 0);
        // Take snapshot
        token.takeSnapshot();

        (, , time) = token.snapshots(0);
        assertEq(time, block.timestamp);
        // Check that new current snapshot has previous totals
        (totalTier1, totalTier2, time) = token.snapshots(1);
        assertEq(totalTier1, 0);
        assertEq(totalTier2, 49_000 ether);
        assertEq(time, 0);
        // USER 1 drops to NO TIER
        vm.prank(user1);
        token.transfer(address(this), 48_001 ether);
        (totalTier1, totalTier2, time) = token.snapshots(1);

        assertEq(totalTier1, 0);
        assertEq(totalTier2, 0);
        assertEq(time, 0);

        uint snapBalance = token.getUserSnapshotAt(user1, 0);
        assertEq(snapBalance, 49_000 ether);
        snapBalance = token.getUserSnapshotAt(user1, 1);
        assertEq(snapBalance, 999 ether);
    }

    function test_snapshotTaking_interval() public {
        token.enableTrading();
        token.transfer(user1, 50_000 ether);
        // USER1 is part of tier1 in snapshot 0
        token.takeSnapshot();

        // USER1 is part of tier1 in snapshot 1
        token.takeSnapshot();

        token.transfer(user1, 10_000 ether);
        // user1 is part of tier1 in snapshot 2
        // token.takeSnapshot();

        assertEq(token.getUserSnapshotAt(user1, 0), 50_000 ether);
        console.log("Shit hits the fan");
        assertEq(token.getUserSnapshotAt(user1, 1), 50_000 ether);
        // assertEq(token.getUserSnapshotAt(user1, 2), 60_000 ether);
    }
}
