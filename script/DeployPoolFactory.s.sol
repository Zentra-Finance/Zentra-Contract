// script/DeployTransparentProxy.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {PoolFactory} from "src/PoolFactory.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract DeployPoolFactory is Script {
    address _master;
    address _privatemaster;
    address _poolmanager;
    address _fairmaster;
    uint8 _version;
    uint256 _kycPrice;
    uint256 _auditPrice;
    uint256 _masterPrice;
    uint256 _privatemasterPrice;
    uint256 _fairmasterPrice;
    uint256 _contributeWithdrawFee;
    bool _IsEnabled;

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