// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {OracleClient} from "../src/oracle/OracleClient.sol";

contract DeployOracleClient is Script {
    address supraOraclePull = address(0xF439Cea7B2ec0338Ee7EC16ceAd78C9e1f47bc4c);

    function run() external {
        vm.startBroadcast();

        OracleClient oracleClient = new OracleClient(supraOraclePull);

        console.log("OracleClient deployed at:", address(oracleClient));

        vm.stopBroadcast();
    }
}
