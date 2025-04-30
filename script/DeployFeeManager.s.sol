// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {FeeManager} from "src/FeeManager.sol";

contract DeployFeeManager is Script {
    address owner = address(0x6c8fcDeb117a1d40Cd2c2eB6ECDa58793FD636b1);

    function run() external {
        vm.startBroadcast();

        FeeManager feeManager = new FeeManager(owner);

        console.log("FeeManager deployed at:", address(feeManager));

        vm.stopBroadcast();
    }
}

//╰─ forge verify-contract 0x9a76954a5b317aFCC9ec85070515B2273a8c3395 FeeManager --constructor-args 0x6c8fcDeb117a1d40Cd2c2eB6ECDa58793FD636b1 --verifier blockscout --verifier-url $VERIFIER_URL