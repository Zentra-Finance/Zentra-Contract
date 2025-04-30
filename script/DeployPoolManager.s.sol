// script/DeployTransparentProxy.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {PoolManager} from "src/PoolManager.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract DeployPoolManager is Script {
  
    address initialOwner = address(0x6c8fcDeb117a1d40Cd2c2eB6ECDa58793FD636b1);

    function run() external {
        vm.startBroadcast();

        PoolManager logic = new PoolManager();

        ProxyAdmin proxyAdmin = new ProxyAdmin(msg.sender);

        bytes memory data = abi.encodeWithSelector(PoolManager.initialize.selector, initialOwner);

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(logic), address(proxyAdmin), data);

        console.log("Logic contract deployed at:", address(logic));
        console.log("ProxyAdmin deployed at:", address(proxyAdmin));
        console.log("Proxy deployed at:", address(proxy));

        vm.stopBroadcast();
    }
}
