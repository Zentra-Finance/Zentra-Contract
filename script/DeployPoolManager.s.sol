// script/DeployTransparentProxy.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {PoolManager} from "src/PoolManager.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract DeployPoolManager is Script {
    address _WETH;
    address _ethUSDTPool;

    function run() external {
        vm.startBroadcast();

        PoolManager logic = new PoolManager();

        ProxyAdmin proxyAdmin = new ProxyAdmin(msg.sender);

        bytes memory data = abi.encodeWithSelector(PoolManager.initialize.selector, _WETH, _ethUSDTPool);

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(logic), address(proxyAdmin), data);

        console.log("Logic contract deployed at:", address(logic));
        console.log("ProxyAdmin deployed at:", address(proxyAdmin));
        console.log("Proxy deployed at:", address(proxy));

        vm.stopBroadcast();
    }
}
