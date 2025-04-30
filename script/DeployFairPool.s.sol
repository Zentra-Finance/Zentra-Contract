// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {FairPool} from "src/FairPool.sol";

contract DeployFairPool is Script {

    function run() external {
        vm.startBroadcast();

        FairPool fairPool = new FairPool();

        console.log("FairPool deployed at:", address(fairPool));

        vm.stopBroadcast();
    }
}
