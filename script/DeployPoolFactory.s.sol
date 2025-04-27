// script/DeployTransparentProxy.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {PoolFactory} from "src/PoolFactory.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract DeployPoolFactory is Script {
    address _master = 0xc58dC09c987865583E1C42C96BE76D2AD4a9A336;//EOA
    address _privatemaster = 0xc58dC09c987865583E1C42C96BE76D2AD4a9A336; //EOA
    address _poolmanager; //Pool Manager
    address _fairmaster; // FAir Pool
    uint8 _version = 1;
    uint256 _kycPrice = 2e17;
    uint256 _auditPrice = 1.5e17;
    uint256 _masterPrice = 2e15;
    uint256 _privatemasterPrice = 2e14;
    uint256 _fairmasterPrice = 2e15;
    uint256 _contributeWithdrawFee = 50;
    bool _IsEnabled = true;

    function run() external {
        vm.startBroadcast();

        PoolFactory logic = new PoolFactory();

        ProxyAdmin proxyAdmin = new ProxyAdmin(msg.sender);

        bytes memory data = abi.encodeWithSelector(
            PoolFactory.initialize.selector,
            _master,
            _privatemaster,
            _poolmanager,
            _fairmaster,
            _version,
            _kycPrice,
            _auditPrice,
            _masterPrice,
            _privatemasterPrice,
            _fairmasterPrice,
            _contributeWithdrawFee,
            _IsEnabled
        );

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(logic), address(proxyAdmin), data);

        console.log("Logic contract deployed at:", address(logic));
        console.log("ProxyAdmin deployed at:", address(proxyAdmin));
        console.log("Proxy deployed at:", address(proxy));

        vm.stopBroadcast();
    }
}

// forge script script/DeployPoolFactory.s.sol --
// forge script script/DeployFlexiscrowFactory.s.sol --rpc-url $ETH_RPC_URL --account defaultKey --broadcast --verify --verifier blockscout --verifier-url $VERIFIER_URL
// forge verify-contract 0x9273e414Aaa9EEDbDA47B3F7F96632B4AD7C212e PoolFactory --verifier blockscout --verifier-url $VERIFIER_URL 