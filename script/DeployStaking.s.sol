// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../src/LynxStaking.sol";
import "../src/LynxToken.sol";
import "../src/LynxVault.sol";

import {Script, console} from "forge-std/Script.sol";

contract DeployStaking is Script {
    Lynx public token = Lynx(0x80D186B4C786Ea66592b2c52e2004AB10CfE4CF3);

    function run() public {
        vm.startBroadcast();
        // LynxVault vault = new LynxVault(address(token));
        LynxVault vault = LynxVault(0xcF3FdD93bD43F24c84Aa1002735F07Ee83e194Ec);

        uint startTime = 1702684800;

        // LynxStaking staking_1 = new LynxStaking(
        //     startTime,
        //     address(token),
        //     address(vault),
        //     17_99,
        //     2
        // );
        // LynxStaking staking_2 = new LynxStaking(
        //     startTime,
        //     address(token),
        //     address(vault),
        //     20_00,
        //     4
        // );
        LynxStaking staking_3 = new LynxStaking(
            startTime,
            address(token),
            address(vault),
            25_00,
            12
        );
        // console.log("Staking 1 address: %s", address(staking_1));
        // console.log("Staking 2 address: %s", address(staking_2));
        console.log("Staking 3 address: %s", address(staking_3));

        vm.stopBroadcast();
    }
}
