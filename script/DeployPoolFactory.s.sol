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
        address _master = address(0x6c8fcDeb117a1d40Cd2c2eB6ECDa58793FD636b1);
        address _bondingmaster = address(0xf61772faB2c2A32480CC29765EE5be153E5Cf2d3);
        address _poolmanager = address(0xEDBe3C2004C9f3C84597ECBbC65ded1808987DEa);
        address _fairmaster = address(0xFE05805041709a32E8Db9876a3276b0429082E96);
        uint8 _version = 1;
        uint256 _kycPrice = 0.2 ether;
        uint256 _auditPrice = 0.15 ether;
        uint256 _fairmasterPrice = 0.002 ether;
        uint256 _contributeWithdrawFee = 50;
        bool _IsEnabled = true;
        uint256 _bondingTokenCreationFee = 0.05 ether;
        uint256 _ethToBonding = 0.1 ether;
        address _nonfungiblePositionManager = address(0xD0AAe88AF22dAE89CCF46D9033C2dB6eBf4B87F0);
        address _feeManager = address(0x9a76954a5b317aFCC9ec85070515B2273a8c3395);
        address _supraOraclePull = address(0xF439Cea7B2ec0338Ee7EC16ceAd78C9e1f47bc4c);
        address _supraFeedClient = address(0xb6de33597E190A885C999B172eA4E660e1Ff9ba2);

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
// forge script script/DeployPoolFactory.s.sol --rpc-url $ETH_RPC_URL --account defaultKey --broadcast --verify --verifier blockscout --verifier-url $VERIFIER_URL
// forge verify-contract 0x9273e414Aaa9EEDbDA47B3F7F96632B4AD7C212e PoolFactory --verifier blockscout --verifier-url $VERIFIER_URL
