// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {PoolFactory} from "src/PoolFactory.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PoolFactoryTest is Test {
    address initialOwner = address(0x6c8fcDeb117a1d40Cd2c2eB6ECDa58793FD636b1);
    // address _master = address(0x6c8fcDeb117a1d40Cd2c2eB6ECDa58793FD636b1);
    address _bondingmaster = address(0xf61772faB2c2A32480CC29765EE5be153E5Cf2d3);
    address _poolmanager = address(0xEDBe3C2004C9f3C84597ECBbC65ded1808987DEa);
    address _fairmaster = address(0x3693BE8617DD7fFbB031A6536030aEBFAd361fa8);
    uint8 _version = 1;
    uint256 _kycPrice = 0.2 ether;
    uint256 _auditPrice = 0.15 ether;
    uint256 _fairmasterPrice = 0.002 ether;
    uint256 _contributeWithdrawFee = 50;
    bool _IsEnabled = true;
    // uint256 _bondingTokenCreationFee = 0.05 ether;
    // uint256 _ethToBonding = 0.1 ether;
    // address _nonfungiblePositionManager = address(0xD0AAe88AF22dAE89CCF46D9033C2dB6eBf4B87F0);
    // address _feeManager = address(0x9a76954a5b317aFCC9ec85070515B2273a8c3395);
    // address _supraOraclePull = address(0xF439Cea7B2ec0338Ee7EC16ceAd78C9e1f47bc4c);
    // address _supraFeedClient = address(0xb6de33597E190A885C999B172eA4E660e1Ff9ba2);
    PoolFactory proxiedFactory;
    address RockyToken = address(0x666359D0De5E1F1290a89310624ADE428F91E127);
    address uniswapV2Router02 = address(0xe1CB270f0C7C82dA9E819A4cC2bd43861F550C4F);

    function setUp() public {
        vm.createSelectFork("https://devnet.dplabs-internal.com");
        // Deploy implementation
        // PoolFactory impl = new PoolFactory();

        // // Deploy ProxyAdmin
        // ProxyAdmin proxyAdmin = new ProxyAdmin(initialOwner);

        // // Encode initializer
        // bytes memory initData = abi.encodeWithSelector(
        //     impl.initialize.selector,
        //     initialOwner,
        //     _master,
        //     _bondingmaster,
        //     _poolmanager,
        //     _fairmaster,
        //     _version,
        //     _kycPrice,
        //     _auditPrice,
        //     _fairmasterPrice,
        //     _contributeWithdrawFee,
        //     _IsEnabled,
        //     _bondingTokenCreationFee,
        //     _ethToBonding,
        //     _supraFeedClient,
        //     _nonfungiblePositionManager,
        //     _feeManager,
        //     _supraOraclePull
        // );

        // // Deploy proxy with initializer
        // TransparentUpgradeableProxy proxy =
        //     new TransparentUpgradeableProxy(address(impl), address(proxyAdmin), initData);

        // Cast the proxy to the PoolFactory interface
        proxiedFactory = PoolFactory(payable(address(0x8901Dc6232C767ae7e974aeEA97284722905704A)));
    }

    //     function createFairSale(
    //     // uint8 _routerVersion,
    //     address[4] memory _addrs, // [0] = token, [1] = router, [2] = governance , [3] = currency
    //     uint256[2] memory _capSettings, //[0] = softCap, [1] = totalToken
    //     uint256[3] memory _timeSettings, // [0] =startTime, [1] =endTime, [2]=liquidityLockDays
    //     uint256[3] memory _auditKRVTokenId, //[0] = audit (if 1, it means collect fees), [1] = kyc (if 1, it means collect fees), [2] = routerVersion (2 ==v2 or 3 ==v3)
    //     uint256[2] memory _liquidityPercent, // [0] = liquidityPercent, [1]= refundType
    //     string memory _poolDetails,
    //     string[3] memory _otherInfo
    // ) external payable {

    function testDeployPoolFactory() public view {
        // Now test that values are correctly initialized (you may need getters or public variables)
        // assertEq(proxiedFactory.master(), _master);
        assertEq(proxiedFactory.bondingmaster(), _bondingmaster);
        assertEq(proxiedFactory.poolManager(), _poolmanager);
        assertEq(proxiedFactory.version(), _version);
        assertEq(proxiedFactory.kycPrice(), _kycPrice);
        assertEq(proxiedFactory.auditPrice(), _auditPrice);
        assertEq(proxiedFactory.fairmasterPrice(), _fairmasterPrice);
        assertEq(proxiedFactory.contributeWithdrawFee(), _contributeWithdrawFee);
        assertEq(proxiedFactory.IsEnabled(), _IsEnabled);
    }

    function testCreateFairPool() public {
        address[4] memory addrs = [RockyToken, uniswapV2Router02, initialOwner, address(0)];
        uint256[2] memory _capSettings = [uint256(1e18), 50_000e18];
        uint256[3] memory _timeSettings = [block.timestamp + 50, block.timestamp + 1000, 5 days];
        uint256[3] memory _auditKRVTokenId = [uint256(2), 2, 2];
        uint256[2] memory _liquidityPercent = [uint256(60), 0];
        string memory _poolDetails = "First details";
        string[3] memory _otherInfo = ["auditLink", "kycLink", "ownerMail"];
        uint256 feeToPay = proxiedFactory.fairmasterPrice();
        uint256 tokenToSend = _capSettings[1] + _capSettings[1] * _liquidityPercent[0] / 100;
        vm.startPrank(initialOwner);
        IERC20(RockyToken).approve(address(proxiedFactory), tokenToSend);

        proxiedFactory.createFairSale{value: feeToPay}(
            addrs, _capSettings, _timeSettings, _auditKRVTokenId, _liquidityPercent, _poolDetails, _otherInfo
        );
        // uint256 bondingFee = 0.15e18;
        // proxiedFactory.createBondingToken{value: bondingFee}(initialOwner, "", ["Degen", "DGN"]);
        vm.stopPrank();
    }
}
