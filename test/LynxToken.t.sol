// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import "../src/LynxToken.sol";

contract TestLynxToken is Test {
    Lynx token;

    address admin = makeAddr("admin");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address black = makeAddr("black");
    uint maxSupply = 5_000_000 ether;
    uint tier1 = 50_000 ether;
    uint tier2 = 1_000 ether;

    function setUp() public {
        token = new Lynx(admin);
    }

    function test_init() public {
        assertEq(token.name(), "LYNX");
        assertEq(token.symbol(), "LYNX");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), maxSupply);
        assertEq(token.balanceOf(address(this)), maxSupply);
        assertEq(token.maxWallet(), 75_000 ether);
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

        vm.expectRevert();
        vm.prank(user2);
        token.transfer(user1, tier1);
    }

    function test_blacklist() public {
        token.blacklistAddress(black);
        assertTrue(token.isBlacklisted(black));

        vm.expectRevert();
        token.transfer(black, tier1);
    }
}
