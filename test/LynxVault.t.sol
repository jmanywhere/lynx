// SPDX-License-Identifier: MIT

pragma solidity >=0.8.21;

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "../src/LynxVault.sol";
import "forge-std/Test.sol";

contract Test_Vault is Test {
    IERC20 token;
    IERC20 other_token;
    LynxVault vault;

    address owner = makeAddr("owner");
    address other = makeAddr("other");

    function setUp() public {
        token = IERC20(
            new ERC20PresetFixedSupply("Lynx", "LYNX", 1_000_000 ether, owner)
        );
        other_token = IERC20(
            new ERC20PresetFixedSupply(
                "notlynx",
                "notlynx",
                1_000_000 ether,
                owner
            )
        );
        vault = new LynxVault(address(token));
    }

    function test_lock_tokens() public {
        vm.startPrank(owner);
        token.transfer(address(vault), 100 ether);

        vm.expectRevert();
        vault.withdraw(100 ether);

        assertEq(token.balanceOf(address(vault)), 100 ether);

        vm.expectRevert();
        vault.recoverERC20(address(token));

        vm.stopPrank();

        vm.expectRevert();
        vault.recoverERC20(address(token));
    }

    function test_token_recovery() public {
        vm.startPrank(owner);
        other_token.transfer(address(vault), 100 ether);

        vm.expectRevert();
        vault.recoverERC20(address(other_token));
        vm.stopPrank();

        vault.recoverERC20(address(other_token));
        assertEq(other_token.balanceOf(address(this)), 100 ether);
        assertEq(other_token.balanceOf(address(vault)), 0);
    }

    function test_withdraw_tokens() public {
        vm.startPrank(owner);
        token.transfer(address(vault), 100 ether);

        vm.expectRevert();
        vault.withdraw(100 ether);

        assertEq(token.balanceOf(address(vault)), 100 ether);

        vm.stopPrank();

        vault.withdraw(10 ether);

        assertEq(token.balanceOf(address(vault)), 90 ether);
        assertEq(token.balanceOf(address(this)), 10 ether);

        vault.withdrawTo(other, 5 ether);
        assertEq(token.balanceOf(address(vault)), 85 ether);
    }
}
