// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {BondingPool} from "src/BondingPool.sol";

contract DeployBondingPool is Script {

    function run() external {
        vm.startBroadcast();

        BondingPool bondingPool = new BondingPool();

        console.log("BondingPool deployed at:", address(bondingPool));

        vm.stopBroadcast();
    }
}

//forge script script/DeployBondingPool.s.sol:DeployBondingPool --rpc-url $ETH_RPC_URL --account defaultKey --broadcast  --verify --verifier blockscout --verifier-url $VERIFIER_URL