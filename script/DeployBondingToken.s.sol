// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {BondingToken} from "src/tokens/BondingToken.sol";

contract DeployBondingToken is Script {

    function run() external {
        vm.startBroadcast();

        BondingToken bondingToken = new BondingToken();

        console.log("BondingToken deployed at:", address(bondingToken));

        vm.stopBroadcast();
    }
}
