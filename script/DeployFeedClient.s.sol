// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {FeedClient} from "../src/oracle/FeedClient.sol";

contract DeployFeedClient is Script {
    address sValueFeedAddress = address(0xf08A9C60bbF1E285BF61744b17039c69BcD6287d);

    function run() external {
        vm.startBroadcast();

        FeedClient feedClient = new FeedClient(sValueFeedAddress);

        console.log("FeedClient deployed at:", address(feedClient));

        vm.stopBroadcast();
    }
}
