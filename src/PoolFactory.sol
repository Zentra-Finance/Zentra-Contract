// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IPool} from "./interfaces/IPool.sol";
import {IPrivatePool} from "./interfaces/IPrivatePool.sol";
import {IFairPool} from "./interfaces/IFairPool.sol";
import {IBondingPool} from "./interfaces/IBondingPool.sol";
import {IBondingToken} from "./interfaces/IBondingToken.sol";
import {IPoolManager} from "./interfaces/IPoolManager.sol";
import {IFeeManager} from "./interfaces/IFeeManager.sol";

contract PoolFactory is OwnableUpgradeable {
    address private master;
    address public privatemaster;
    address public fairmaster;
    address public bondingmaster;

    using SafeERC20 for IERC20;

    address private poolOwner;
    address public poolManager;
    uint8 public version;
    uint256 public kycPrice;
    uint256 public auditPrice;
    uint256 public masterPrice;
    uint256 public privatemasterPrice;
    uint256 public fairmasterPrice;
    bool public IsEnabled;
    uint256 public contributeWithdrawFee; //1% ~ 100 but 10000 is 100%
    uint256 public bondingTokenCreationFee;
    uint256 public ethToBonding;
    uint256[4] public buySellFeeSettings; // = [1, 1, 6900, 1e18] // [2] = market cap settings [3] = initialEthAmount(1eth * 10**18) for ethereum
    uint256[2] public feeSettings; //  = [0, 5] // tokenFeePercent (after finalize) //ETHFeePercent (after finalize) 5%

    using Clones for address;

    address payable public adminWallet;
    uint256 public partnerFee;
    address public supraFeedClient;

    address public nonfungiblePositionManager;
    address public bondingToken;
    IFeeManager private feeManager;
    address supraOraclePull;

    function initialize(
        address initialOwner,
        address _master,
        address _bondingmaster,
        address _poolmanager,
        address _fairmaster,
        uint8 _version,
        uint256 _kycPrice,
        uint256 _auditPrice,
        // uint256 _masterPrice,
        uint256 _fairmasterPrice,
        uint256 _contributeWithdrawFee,
        bool _IsEnabled,
        uint256 _bondingTokenCreationFee,
        uint256 _ethToBonding,
        address _supraFeedClient,
        address _nonfungiblePositionManager,
        address _feeManager,
        address _supraOraclePull
    ) external initializer {
        __Ownable_init(initialOwner);

        master = _master;
        bondingmaster = _bondingmaster;
        poolManager = _poolmanager;
        fairmaster = _fairmaster;
        kycPrice = _kycPrice;
        auditPrice = _auditPrice;
        // masterPrice = _masterPrice;
        fairmasterPrice = _fairmasterPrice;
        contributeWithdrawFee = _contributeWithdrawFee;
        version = _version;
        IsEnabled = _IsEnabled;
        bondingTokenCreationFee = _bondingTokenCreationFee;
        ethToBonding = _ethToBonding;
        supraFeedClient = _supraFeedClient;

        nonfungiblePositionManager = _nonfungiblePositionManager;
        feeManager = IFeeManager(_feeManager);
        supraOraclePull = _supraOraclePull;
    }

    receive() external payable {}

    event FairSaleCreated(address indexed creator, address indexed pool, address indexed token);
    event BondingTokenCreated(address indexed creator, address indexed pool, address indexed token);

    function setMasterAddress(address payable _address) public onlyOwner {
        require(_address != address(0), "zero address");
        master = _address;
    }

    function setFairAddress(address _address) public onlyOwner {
        require(_address != address(0), "zero address");
        fairmaster = _address;
    }

    function setPrivateAddress(address _address) public onlyOwner {
        require(_address != address(0), "zero address");
        privatemaster = _address;
    }

    function setAdminWallet(address payable _address) public onlyOwner {
        require(_address != address(0), "zero address");
        adminWallet = _address;
    }

    function setPartnerFee(uint256 _partnerFees) public onlyOwner {
        partnerFee = _partnerFees;
    }

    function setVersion(uint8 _version) public onlyOwner {
        version = _version;
    }

    function setcontributeWithdrawFee(uint256 _fees) public onlyOwner {
        contributeWithdrawFee = _fees;
    }

    function initalizeBondingClone(
        // uint8 _routerVersion,
        address _pair,
        address[4] memory _addrs, //[0] = new token addr, [1] = router (NonfungiblePositionManager), [2] = governance , [3] = supraFeedClient
        string memory _poolDetails,
        address _supraOraclePull
    ) internal {
        IBondingPool(_pair).initialize(
            _addrs, //[0] = template token addr, [1] = router (NonfungiblePositionManager), [2] = governance , [3] = supraFeedClient
            feeSettings, // [0] = is for token fee when finish time, [1] = eth fee when finish time
            buySellFeeSettings, //  [0] = buy Fee, [1] = sell fee, [2] = market cap settings [3] =  initialEthAmount(1eth * 10**18) for ethereum
            _poolDetails,
            [master, poolManager, adminWallet],
            version,
            _supraOraclePull
        );
    }

    function createBondingToken(
        address creator,
        string memory _poolDetails,
        string[2] memory tokenInfo //[0] = name, [1] = symbol
    ) external payable {
        require(IsEnabled, "Create sale currently on hold , try again after sometime!!");
        require(bondingToken != address(0), "Bonding Token address is not set!!");
        require(msg.value >= bondingTokenCreationFee + ethToBonding, "Insufficient fee for creating bonding");
        (bool success,) = payable(address(feeManager)).call{value: bondingTokenCreationFee}("");
        require(success, "Address: unable to send value, recipient may have reverted");
        bytes32 salt = keccak256(abi.encodePacked(_poolDetails, block.timestamp));
        address pair = Clones.cloneDeterministic(bondingmaster, salt); //@note new cloned bonding pool
        salt = keccak256(abi.encodePacked(tokenInfo[0], block.timestamp));
        address[4] memory _addrs;
        _addrs[0] = Clones.cloneDeterministic(bondingToken, salt); //token address
        _addrs[1] = nonfungiblePositionManager;
        _addrs[2] = creator;
        _addrs[3] = supraFeedClient;

        IBondingToken(_addrs[0]).initialize(pair, tokenInfo[0], tokenInfo[1]);
        (bool success2,) = payable(pair).call{value: ethToBonding}("");
        require(success2, "Unable to send eth to pool!");

        // address governance = _addrs[2];
        // _addrs[0] = token;
        initalizeBondingClone(pair, _addrs, _poolDetails, supraOraclePull);

        IPoolManager(poolManager).addAllowedPools(pair);
        IPoolManager(poolManager).registerBondingPool(pair, _addrs[0], _addrs[2], version);
        emit BondingTokenCreated(_addrs[2], pair, _addrs[0]);
    }

    function initalizeFairClone(
        // uint8 _routerVersion,
        address _pair,
        address[4] memory _addrs,
        uint256[2] memory _capSettings,
        uint256[3] memory _timeSettings,
        // uint256[2] memory _feeSettings,
        uint256[3] memory _auditKRVTokenId,
        // uint256 _audit,
        // uint256 _kyc,
        uint256[2] memory _liquidityPercent,
        string memory _poolDetails,
        string[3] memory _otherInfo
    ) internal {
        IFairPool(_pair).initialize(
            _addrs,
            _capSettings,
            _timeSettings,
            feeSettings,
            _auditKRVTokenId,
            _liquidityPercent,
            _poolDetails,
            [master, poolManager, adminWallet],
            version,
            contributeWithdrawFee,
            _otherInfo
        );
        if (_auditKRVTokenId[2] == 2) {
            address ethAddress = IUniswapV2Router02(_addrs[1]).WETH();
            address factoryAddress = IUniswapV2Router02(_addrs[1]).factory();
            address getPair =
                IUniswapV2Factory(factoryAddress).getPair(_addrs[3] == address(0) ? ethAddress : _addrs[3], _addrs[0]);
            if (getPair != address(0)) {
                uint256 Lpsupply = IERC20(getPair).totalSupply();
                require(Lpsupply == 0, "Already Pair Exist in router, token not eligible for sale");
            }
        }
    }

    function createFairSale(
        // uint8 _routerVersion,
        address[4] memory _addrs, // [0] = token, [1] = router, [2] = governance , [3] = currency
        uint256[2] memory _capSettings, //[0] = softCap, [1] = totalToken
        uint256[3] memory _timeSettings, // [0] =startTime, [1] =endTime, [2]=liquidityLockDays
        uint256[3] memory _auditKRVTokenId, //[0] = audit (if 1, it means collect fees), [1] = kyc (if 1, it means collect fees), [2] = routerVersion (2 ==v2 or 3 ==v3)
        uint256[2] memory _liquidityPercent, // [0] = liquidityPercent, [1]= refundType
        string memory _poolDetails,
        string[3] memory _otherInfo
    ) external payable {
        require(IsEnabled, "Create sale currently on hold , try again after sometime!!");
        require(fairmaster != address(0), "pool address is not set!!");
        require(_auditKRVTokenId[2] == 2 || _auditKRVTokenId[2] == 3, "Invalid router version");
        address token = _addrs[0];
        require(IPoolManager(poolManager).fairPoolForToken(token) == address(0), "Fair pool already created for token");
        fairFees(_auditKRVTokenId[1], _auditKRVTokenId[0]);

        (bool success,) = payable(address(feeManager)).call{value: msg.value}("");
        require(success, "Address: unable to send value, recipient may have reverted");

        bytes32 salt = keccak256(abi.encodePacked(_poolDetails, block.timestamp));
        address pair = Clones.cloneDeterministic(fairmaster, salt);
        initalizeFairClone(
            // _routerVersion,
            pair,
            _addrs,
            _capSettings,
            _timeSettings,
            // _feeSettings,
            _auditKRVTokenId,
            // _audit,
            // _kyc,
            _liquidityPercent,
            _poolDetails,
            _otherInfo
        );

        uint256 totalToken = _feesFairCount(_capSettings[1], feeSettings[0], _liquidityPercent[0]);

        address governance = _addrs[2];

        _safeTransferFromEnsureExactAmount(token, address(msg.sender), address(this), totalToken);
        _transferFromEnsureExactAmount(token, pair, totalToken);

        IPoolManager(poolManager).addAllowedPools(pair);
        IPoolManager(poolManager).registerFairPool(pair, token, governance, version);
        emit FairSaleCreated(governance, pair, token);
    }

    function _safeTransferFromEnsureExactAmount(address token, address sender, address recipient, uint256 amount)
        internal
    {
        uint256 oldRecipientBalance = IERC20(token).balanceOf(recipient);

        IERC20(token).safeTransferFrom(sender, recipient, amount);
        uint256 newRecipientBalance = IERC20(token).balanceOf(recipient);
        require(
            newRecipientBalance - oldRecipientBalance == amount,
            "Not enough token was transfered If tax set Remove Our Address!!"
        );
    }

    function _transferFromEnsureExactAmount(address token, address recipient, uint256 amount) internal {
        uint256 oldRecipientBalance = IERC20(token).balanceOf(recipient);
        IERC20(token).transfer(recipient, amount);
        uint256 newRecipientBalance = IERC20(token).balanceOf(recipient);
        require(
            newRecipientBalance - oldRecipientBalance == amount,
            "Not enough token was transfered If tax set Remove Our Address!!"
        );
    }

    // function checkfees(uint256 _audit, uint256 _kyc) internal {
    //     uint256 totalFees = 0;
    //     totalFees += masterPrice;

    //     if (_audit == 1) {
    //         totalFees += auditPrice;
    //     }

    //     if (_kyc == 1) {
    //         totalFees += kycPrice;
    //     }

    //     require(msg.value >= totalFees, "Payble Amount is less than required !!");
    // }

    function fairFees(uint256 _kyc, uint256 _audit) internal {
        uint256 totalFees = 0;
        totalFees += fairmasterPrice;

        if (_audit == 1) {
            totalFees += auditPrice;
        }

        if (_kyc == 1) {
            totalFees += kycPrice;
        }

        require(msg.value >= totalFees, "Payble Amount is less than required !!");
    }

    function _feesCount(uint256 _rate, uint256 _Lrate, uint256 _hardcap, uint256 _liquidityPercent, uint256 _fees)
        internal
        pure
        returns (uint256)
    {
        uint256 totalToken =
            (((_rate * _hardcap) / 10 ** 18)) + ((((_hardcap * _Lrate) / 10 ** 18) * _liquidityPercent) / 100);
        uint256 totalFees = (((((_rate * _hardcap) / 10 ** 18)) * _fees) / 100);
        uint256 total = totalToken + totalFees;
        return total;
    }

    function _feesPrivateCount(uint256 _rate, uint256 _hardcap, uint256 _fees) internal pure returns (uint256) {
        uint256 totalToken = (((_rate * _hardcap) / 10 ** 18));
        uint256 totalFees = (((((_rate * _hardcap) / 10 ** 18)) * _fees) / 100);
        uint256 total = totalToken + totalFees;
        return total;
    }

    function _feesFairCount(uint256 _totaltoken, uint256 _tokenFees, uint256 _liquidityper)
        internal
        pure
        returns (uint256)
    {
        uint256 totalToken = _totaltoken + ((_totaltoken * _liquidityper) / 100);
        uint256 totalFees = (_totaltoken * _tokenFees) / 100;
        uint256 total = totalToken + totalFees;
        return total;
    }

    function setPoolOwner(address _address) public onlyOwner {
        require(_address != address(0), "Invalid Address found");
        poolOwner = _address;
    }

    function setKycPrice(uint256 _price) public onlyOwner {
        kycPrice = _price;
    }

    function setAuditPrice(uint256 _price) public onlyOwner {
        auditPrice = _price;
    }

    // function setPresalePoolPrice(uint256 _price) public onlyOwner {
    //     masterPrice = _price;
    // }

    function setBondingTokenCreationFee(uint256 _price) public onlyOwner {
        bondingTokenCreationFee = _price;
    }

    function setEthToBonding(uint256 _price) public onlyOwner {
        ethToBonding = _price;
    }

    function setPrivatePoolPrice(uint256 _price) public onlyOwner {
        privatemasterPrice = _price;
    }

    function setFairPoolPrice(uint256 _price) public onlyOwner {
        fairmasterPrice = _price;
    }

    function setPoolManager(address _address) public onlyOwner {
        require(_address != address(0), "Invalid Address found");
        poolManager = _address;
    }

    function ethLiquidity(address payable _reciever, uint256 _amount) public onlyOwner {
        _reciever.transfer(_amount);
    }

    function transferAnyERC20Token(address payaddress, address tokenAddress, uint256 tokens) public onlyOwner {
        IERC20(tokenAddress).transfer(payaddress, tokens);
    }

    // function updateKycAuditStatus(
    //     address _poolAddress,
    //     bool _kyc,
    //     bool _audit,
    //     string memory _kyclink,
    //     string memory _auditlink
    // ) public onlyOwner {
    //     require(IPoolManager(poolManager).isFairPoolGenerated(_poolAddress), "Pool Not exist !!");
    //     IPool(_poolAddress).setKycAudit(_kyc, _audit, _kyclink, _auditlink);
    // }

    function setBondingToken(address _bondingToken) public onlyOwner {
        require(_bondingToken != address(0), "Bonding Token address must be set!!");
        bondingToken = _bondingToken;
    }

    function setBuySellFeeSettings(uint256[4] memory _buySellFeeSettings) public onlyOwner {
        // require(_bondingToken != address(0), "Bonding Token address must be set!!");
        require(
            _buySellFeeSettings[0] >= 0 && _buySellFeeSettings[0] <= 100 && _buySellFeeSettings[1] >= 0
                && _buySellFeeSettings[1] <= 100,
            "Invalid buy sell fee settings. Must be percentage (0 -> 100)"
        );
        buySellFeeSettings = _buySellFeeSettings;
    }

    function setFinalizeFeeSettings(uint256[2] memory _feeSettings) public onlyOwner {
        // require(_bondingToken != address(0), "Bonding Token address must be set!!");
        require(
            _feeSettings[0] >= 0 && _feeSettings[0] <= 100 && _feeSettings[1] >= 0 && _feeSettings[1] <= 100,
            "Invalid buy sell fee settings. Must be percentage (0 -> 100)"
        );
        feeSettings = _feeSettings;
    }

    function setBondingPool(address _bondingPool) public onlyOwner {
        require(_bondingPool != address(0), "Bonding Pool address must be set!");
        bondingmaster = _bondingPool;
    }

    function setsupraFeedClient(address _supraFeedClient) public onlyOwner {
        require(_supraFeedClient != address(0), "Bonding Pool address must be set!");
        supraFeedClient = _supraFeedClient;
    }

    function setFeeManager(address _feeManager) public onlyOwner {
        require(_feeManager != address(0), "Bonding Pool address must be set!");
        feeManager = IFeeManager(_feeManager);
    }

    function poolEmergencyWithdrawLiquidity(address poolAddress, address token_, address to_, uint256 amount_)
        public
        onlyOwner
    {
        IPool(poolAddress).emergencyWithdrawLiquidity(token_, to_, amount_);
    }

    function poolEmergencyWithdrawToken(address poolAddress, address payaddress, address tokenAddress, uint256 tokens)
        public
        onlyOwner
    {
        IPool(poolAddress).emergencyWithdrawToken(payaddress, tokenAddress, tokens);
    }

    function poolEmergencyWithdraw(address poolAddress, address payable to_, uint256 amount_) public onlyOwner {
        IPool(poolAddress).emergencyWithdraw(to_, amount_);
    }

    function poolSetGovernance(address poolAddress, address _governance) public onlyOwner {
        IPool(poolAddress).setGovernance(_governance);
    }

    function setIsEnabled(bool _isEnabled) public onlyOwner {
        IsEnabled = _isEnabled;
    }
}
