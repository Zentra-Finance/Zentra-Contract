// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "forge-std/Script.sol";
import "../src/BondingPool.sol";

contract DeployBondingPool is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the BondingPool contract
        BondingPool bondingPool = new BondingPool();
        
        // Log the deployed address
        console.log("BondingPool deployed at:", address(bondingPool));

        vm.stopBroadcast();
    }
} 