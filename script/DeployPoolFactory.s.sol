// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {PoolFactory} from "src/PoolFactory.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract DeployPoolFactory is Script {
    function run() external {
        // Replace with your actual initializer args
        address initialOwner = address(0x6c8fcDeb117a1d40Cd2c2eB6ECDa58793FD636b1);
        address _master = address(0x2);
        address _bondingmaster = address(0x3);
        address _poolmanager = address(0x4);
        address _fairmaster = address(0x5);
        uint8 _version = 1;
        uint256 _kycPrice = 1 ether;
        uint256 _auditPrice = 2 ether;
        uint256 _masterPrice = 3 ether;
        // uint256 _privatemasterPrice = 4 ether;
        uint256 _fairmasterPrice = 5 ether;
        uint256 _contributeWithdrawFee = 100;
        bool _IsEnabled = true;
        uint256 _bondingTokenCreationFee = 0.1 ether;
        uint256 _ethToBonding = 0.05 ether;
        address _nonfungiblePositionManager = address(0x7);
        address _feeManager = address(0x8);
        address _supraOraclePull = address(0x9);
        address _supraFeedClient = address(0x6);

        vm.startBroadcast();

        // Deploy implementation
        PoolFactory impl = new PoolFactory();

        // Deploy ProxyAdmin
        ProxyAdmin proxyAdmin = new ProxyAdmin(initialOwner);

        // Encode initializer
        bytes memory initData = abi.encodeWithSelector(
            impl.initialize.selector,
            initialOwner,
            _master,
            _bondingmaster,
            _poolmanager,
            _fairmaster,
            _version,
            _kycPrice,
            _auditPrice,
            _masterPrice,
            _fairmasterPrice,
            _contributeWithdrawFee,
            _IsEnabled,
            _bondingTokenCreationFee,
            _ethToBonding,
            _supraFeedClient,
            _nonfungiblePositionManager,
            _feeManager,
            _supraOraclePull
        );

        // Deploy proxy with initializer
        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(impl), address(proxyAdmin), initData);

        vm.stopBroadcast();

        console2.log("Implementation deployed at:", address(impl));
        console2.log("Proxy deployed at:", address(proxy));
        console2.log("ProxyAdmin deployed at:", address(proxyAdmin));
    }
}


// forge script script/DeployPoolFactory.s.sol --
// forge script script/DeployFlexiscrowFactory.s.sol --rpc-url $ETH_RPC_URL --account defaultKey --broadcast --verify --verifier blockscout --verifier-url $VERIFIER_URL
// forge verify-contract 0x9273e414Aaa9EEDbDA47B3F7F96632B4AD7C212e PoolFactory --verifier blockscout --verifier-url $VERIFIER_URL
