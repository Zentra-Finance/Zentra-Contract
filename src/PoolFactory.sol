// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";



interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;

    function setFeeToSetter(address) external;
}

interface IPool {
    function initialize(
        address[4] memory _addrs, // [0] = token, [1] = router, [2] = governance , [3] = Authority
        uint256[16] memory _saleInfo,
        string memory _poolDetails,
        address[3] memory _linkAddress, // [0] factory ,[1] = manager
        uint8 _version,
        uint256 _contributeWithdrawFee,
        string[3] memory _otherInfo
    ) external;

    function initializeVesting(uint256[3] memory _vestingInit) external;

    function setKycAudit(bool _kyc, bool _audit, string memory _kyclink, string memory _auditlink) external;

    function emergencyWithdrawLiquidity(address token_, address to_, uint256 amount_) external;

    function emergencyWithdraw(address payable to_, uint256 amount_) external;

    function setGovernance(address governance_) external;

    function emergencyWithdrawToken(address payaddress, address tokenAddress, uint256 tokens) external;
}

interface IPrivatePool {
    function initialize(
        address[4] memory _addrs,
        uint256[13] memory _saleInfo,
        string memory _poolDetails,
        address[3] memory _linkAddress,
        uint8 _version,
        uint256 _contributeWithdrawFee,
        string[3] memory _otherInfo
    ) external;

    function initializeVesting(uint256[3] memory _vestingInit) external;
}

interface IFairPool {
    function initialize(
        // uint8 _routerVersion,
        address[4] memory _addrs,
        uint256[2] memory _capSettings,
        uint256[3] memory _timeSettings,
        uint256[2] memory _feeSettings,
        uint256[3] memory _auditKRVTokenId,
        // uint256 _audit,
        // uint256 _kyc,
        uint256[2] memory _liquidityPercent,
        string memory _poolDetails,
        address[3] memory _linkAddress,
        uint8 _version,
        uint256 _feesWithdraw,
        string[3] memory _otherInfo
    ) external;

    function initializeVesting(uint256[3] memory _vestingInit) external;
}

interface IBondingPool {
    function initialize(
        address[4] memory _addrs,
        uint256[2] memory _feeSettings,
        uint256[4] memory _buySellFeeSettings, //[2] = marketcap settings [3] = target eth to collect on pool ()
        string memory _poolDetails,
        address[3] memory _linkAddress,
        uint8 _version
    ) external;
}

interface IBondingToken {
    function initialize(
        // uint8 _routerVersion,
        address initialOwner,
        string memory name,
        string memory symbol
    ) external;
}

interface IPoolManager {
    function registerPool(address pool, address token, address owner, uint8 version) external;
    function registerBondingPool(address pool, address token, address owner, uint8 version) external;

    function addPoolFactory(address factory) external;

    function payAmaPartner(address[] memory _partnerAddress, address _poolAddress) external payable;

    function poolForToken(address token) external view returns (address);

    function isPoolGenerated(address pool) external view returns (bool);
}

library Clones {
    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create opcode, which should never revert.
     */
    function clone(address implementation) internal returns (address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            instance := create(0, ptr, 0x37)
        }
        require(instance != address(0), "ERC1167: create failed");
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create2 opcode and a `salt` to deterministically deploy
     * the clone. Using the same `implementation` and `salt` multiple time will revert, since
     * the clones cannot be deployed twice at the same address.
     */
    function cloneDeterministic(address implementation, bytes32 salt) internal returns (address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            instance := create2(0, ptr, 0x37, salt)
        }
        require(instance != address(0), "ERC1167: create2 failed");
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(address implementation, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf3ff00000000000000000000000000000000)
            mstore(add(ptr, 0x38), shl(0x60, deployer))
            mstore(add(ptr, 0x4c), salt)
            mstore(add(ptr, 0x6c), keccak256(ptr, 0x37))
            predicted := keccak256(add(ptr, 0x37), 0x55)
        }
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(address implementation, bytes32 salt)
        internal
        view
        returns (address predicted)
    {
        return predictDeterministicAddress(implementation, salt, address(this));
    }
}

contract PoolFactory is OwnableUpgradeable {
    address private master;
    address public privatemaster;
    address public fairmaster;

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

    using Clones for address;

    address payable public adminWallet;
    uint256 public partnerFee;

    address public bondingToken;
    address public bondingPool;

    function initialize(
        address _master,
        address _privatemaster,
        address _poolmanager,
        address _fairmaster,
        uint8 _version,
        uint256 _kycPrice,
        uint256 _auditPrice,
        uint256 _masterPrice,
        uint256 _privatemasterPrice,
        uint256 _fairmasterPrice,
        uint256 _contributeWithdrawFee,
        bool _IsEnabled
    ) external initializer {
        __Ownable_init(msg.sender);
        master = _master;
        privatemaster = _privatemaster;
        poolManager = _poolmanager;
        fairmaster = _fairmaster;
        kycPrice = _kycPrice;
        auditPrice = _auditPrice;
        masterPrice = _masterPrice;
        privatemasterPrice = _privatemasterPrice;
        fairmasterPrice = _fairmasterPrice;
        contributeWithdrawFee = _contributeWithdrawFee;
        version = _version;
        IsEnabled = _IsEnabled;
    }

    receive() external payable {}

    event FairSaleCreated(address indexed creator, address indexed pool, address indexed token);
    event BondingTokenCreated(address indexed creator, address indexed pool, address indexed token);

    function setMasterAddress(address payable _address) public onlyOwner {
        require(_address != address(0), "master must be set");
        master = _address;
    }

    function setFairAddress(address _address) public onlyOwner {
        require(_address != address(0), "master must be set");
        fairmaster = _address;
    }

    function setPrivateAddress(address _address) public onlyOwner {
        require(_address != address(0), "master must be set");
        privatemaster = _address;
    }

    function setAdminWallet(address payable _address) public onlyOwner {
        require(_address != address(0), "master must be set");
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

    modifier _checkTokeneEligible(address _currencyaddress, address _tokenaddress, address _router) {
        address ethAddress = IUniswapV2Router01(_router).WETH();
        address factoryAddress = IUniswapV2Router01(_router).factory();
        address getPair = IUniswapV2Factory(factoryAddress).getPair(
            _currencyaddress == address(0) ? ethAddress : _currencyaddress, _tokenaddress
        );
        if (getPair != address(0)) {
            uint256 Lpsupply = IERC20(getPair).totalSupply();
            require(Lpsupply == 0, "Already Pair Exist in router, token not eligible for sale");
        }
        _;
    }

    function initalizeClone(
        address _pair,
        address[4] memory _addrs,
        uint256[16] memory _saleInfo,
        string memory _poolDetails,
        uint256[3] memory _vestingInit,
        string[3] memory _otherInfo
    ) internal _checkTokeneEligible(_addrs[3], _addrs[0], _addrs[1]) {
        IPool(_pair).initialize(
            _addrs,
            _saleInfo,
            _poolDetails,
            [poolOwner, poolManager, adminWallet],
            version,
            contributeWithdrawFee,
            _otherInfo
        );

        IPool(_pair).initializeVesting(_vestingInit);

        address poolForToken = IPoolManager(poolManager).poolForToken(_addrs[0]);
        require(poolForToken == address(0), "Pool Already Exist!!");
    }

    function createSale(
        address[4] memory _addrs,
        uint256[16] memory _saleInfo,
        string memory _poolDetails,
        uint256[3] memory _vestingInit,
        string[3] memory _otherInfo
    ) external payable {
        require(IsEnabled, "Create sale currently on hold , try again after sometime!!");
        require(master != address(0), "pool address is not set!!");
        checkfees(_saleInfo[10], _saleInfo[11]);
        //fees transfer to Admin wallet
        (bool success,) = adminWallet.call{value: msg.value}("");
        require(success, "Address: unable to send value, recipient may have reverted");

        bytes32 salt = keccak256(abi.encodePacked(_poolDetails, block.timestamp));
        address pair = Clones.cloneDeterministic(master, salt);
        //Clone Contract
        initalizeClone(pair, _addrs, _saleInfo, _poolDetails, _vestingInit, _otherInfo);
        uint256 totalToken = _feesCount(_saleInfo[0], _saleInfo[1], _saleInfo[5], _saleInfo[14], _saleInfo[12]);
        _safeTransferFromEnsureExactAmount(_addrs[0], address(msg.sender), address(this), totalToken);
        _transferFromEnsureExactAmount(_addrs[0], pair, totalToken);
        IPoolManager(poolManager).addPoolFactory(pair);
        IPoolManager(poolManager).registerPool(pair, _addrs[0], _addrs[2], version);
    }

    function initalizePrivateClone(
        address _pair,
        address[4] memory _addrs,
        uint256[13] memory _saleInfo,
        string memory _poolDetails,
        uint256[3] memory _vestingInit,
        string[3] memory _otherInfo
    ) internal _checkTokeneEligible(_addrs[3], _addrs[0], _addrs[1]) {
        IPrivatePool(_pair).initialize(
            _addrs,
            _saleInfo,
            _poolDetails,
            [poolOwner, poolManager, adminWallet],
            version,
            contributeWithdrawFee,
            _otherInfo
        );

        IPool(_pair).initializeVesting(_vestingInit);
    }

    function createPrivateSale(
        address[4] memory _addrs,
        uint256[13] memory _saleInfo,
        string memory _poolDetails,
        uint256[3] memory _vestingInit,
        string[3] memory _otherInfo
    ) external payable {
        require(IsEnabled, "Create sale currently on hold , try again after sometime!!");
        require(privatemaster != address(0), "pool address is not set!!");
        checkPrivateSalefees(_saleInfo[10], _saleInfo[9]);

        (bool success,) = adminWallet.call{value: msg.value}("");
        require(success, "Address: unable to send value, recipient may have reverted");
        bytes32 salt = keccak256(abi.encodePacked(_poolDetails, block.timestamp));
        address pair = Clones.cloneDeterministic(privatemaster, salt);
        initalizePrivateClone(pair, _addrs, _saleInfo, _poolDetails, _vestingInit, _otherInfo);

        uint256 totalToken = _feesPrivateCount(_saleInfo[0], _saleInfo[4], _saleInfo[7]);

        _safeTransferFromEnsureExactAmount(_addrs[0], address(msg.sender), address(this), totalToken);
        _transferFromEnsureExactAmount(_addrs[0], pair, totalToken);

        IPoolManager(poolManager).addPoolFactory(pair);
        IPoolManager(poolManager).registerPool(pair, _addrs[0], _addrs[1], version);
    }

    function initalizeBondingClone(
        // uint8 _routerVersion,
        address _pair,
        address[4] memory _addrs, //[0] = template token addr, [1] = router, [2] = governance , [3] = ethPriceFeed
        uint256[2] memory _feeSettings,
        uint256[4] memory _buySellFeeSettings, //[0] = buy Fee, [1] = sell fee, [2] = market cap settings [3] = target eth to collect on pool
        string memory _poolDetails
    ) internal {
        IBondingPool(_pair).initialize(
            // _routerVersion,
            _addrs,
            _feeSettings,
            _buySellFeeSettings,
            _poolDetails,
            [master, poolManager, adminWallet],
            version
        );
    }

    function createBondingToken(
        address[4] memory _addrs, //[0] = template token addr, [1] = router, [2] = governance , [3] = ethPriceFeed
        uint256[2] memory _feeSettings, // [0] = is for token fee when finish time, [1] = eth fee when finish time
        uint256[4] memory _buySellFeeSettings, // [2] = market cap settings [3] = targetEth to collect
        uint256[2] memory _createFeeSettings, // [0] = creation fee, [1] = eth amount to bonding pool
        string memory _poolDetails,
        string[2] memory tokenInfo //[0] = name, [1] = symbol
    ) external payable {
        require(IsEnabled, "Create sale currently on hold , try again after sometime!!");
        require(bondingToken != address(0), "Bonding Token address is not set!!");
        require(msg.value >= _createFeeSettings[0] + _createFeeSettings[1], "Insufficient fee for creating bonding");
        (bool success,) = adminWallet.call{value: _createFeeSettings[0]}("");
        require(success, "Address: unable to send value, recipient may have reverted");
        bytes32 salt = keccak256(abi.encodePacked(_poolDetails, block.timestamp));
        address pair = Clones.cloneDeterministic(bondingPool, salt);
        salt = keccak256(abi.encodePacked(tokenInfo[0], block.timestamp));
        _addrs[0] = Clones.cloneDeterministic(bondingToken, salt); //token address
        IBondingToken(_addrs[0]).initialize(pair, tokenInfo[0], tokenInfo[1]);
        (bool success2,) = payable(pair).call{value: _createFeeSettings[1]}("");
        require(success2, "Unable to send eth to pool!");

        // address governance = _addrs[2];
        // _addrs[0] = token;
        initalizeBondingClone(
            // _routerVersion,
            pair,
            _addrs,
            _feeSettings,
            _buySellFeeSettings,
            _poolDetails
        );

        IPoolManager(poolManager).addPoolFactory(pair);
        IPoolManager(poolManager).registerBondingPool(pair, _addrs[0], _addrs[2], version);
        emit BondingTokenCreated(_addrs[2], pair, _addrs[0]);
    }

    function initalizeFairClone(
        // uint8 _routerVersion,
        address _pair,
        address[4] memory _addrs,
        uint256[2] memory _capSettings,
        uint256[3] memory _timeSettings,
        uint256[2] memory _feeSettings,
        uint256[3] memory _auditKRVTokenId,
        // uint256 _audit,
        // uint256 _kyc,
        uint256[2] memory _liquidityPercent,
        string memory _poolDetails,
        string[3] memory _otherInfo
    ) internal {
        IFairPool(_pair).initialize(
            // _routerVersion,
            _addrs,
            _capSettings,
            _timeSettings,
            _feeSettings,
            _auditKRVTokenId,
            // _audit,
            // _kyc,
            _liquidityPercent,
            _poolDetails,
            [master, poolManager, adminWallet],
            version,
            contributeWithdrawFee,
            _otherInfo
        );
        if (_auditKRVTokenId[2] == 2) {
            address ethAddress = IUniswapV2Router01(_addrs[1]).WETH();
            address factoryAddress = IUniswapV2Router01(_addrs[1]).factory();
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
        address[4] memory _addrs,
        uint256[2] memory _capSettings,
        uint256[3] memory _timeSettings,
        uint256[2] memory _feeSettings,
        uint256[3] memory _auditKRVTokenId,
        // uint256 _audit,
        // uint256 _kyc,
        uint256[2] memory _liquidityPercent,
        string memory _poolDetails,
        string[3] memory _otherInfo
    ) external payable {
        require(IsEnabled, "Create sale currently on hold , try again after sometime!!");
        require(fairmaster != address(0), "pool address is not set!!");
        fairFees(_auditKRVTokenId[1], _auditKRVTokenId[0]);

        (bool success,) = adminWallet.call{value: msg.value}("");
        require(success, "Address: unable to send value, recipient may have reverted");

        bytes32 salt = keccak256(abi.encodePacked(_poolDetails, block.timestamp));
        address pair = Clones.cloneDeterministic(fairmaster, salt);

        initalizeFairClone(
            // _routerVersion,
            pair,
            _addrs,
            _capSettings,
            _timeSettings,
            _feeSettings,
            _auditKRVTokenId,
            // _audit,
            // _kyc,
            _liquidityPercent,
            _poolDetails,
            _otherInfo
        );
        address token = _addrs[0];

        uint256 totalToken = _feesFairCount(_capSettings[1], _feeSettings[0], _liquidityPercent[0]);

        address governance = _addrs[2];

        _safeTransferFromEnsureExactAmount(token, address(msg.sender), address(this), totalToken);
        _transferFromEnsureExactAmount(token, pair, totalToken);

        IPoolManager(poolManager).addPoolFactory(pair);
        IPoolManager(poolManager).registerPool(pair, token, governance, version);
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

    function checkfees(uint256 _audit, uint256 _kyc) internal {
        uint256 totalFees = 0;
        totalFees += masterPrice;

        if (_audit == 1) {
            totalFees += auditPrice;
        }

        if (_kyc == 1) {
            totalFees += kycPrice;
        }

        require(msg.value >= totalFees, "Payble Amount is less than required !!");
    }

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

    function checkPrivateSalefees(uint256 _audit, uint256 _kyc) internal {
        uint256 totalFees = 0;
        totalFees += privatemasterPrice;
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

    function setPresalePoolPrice(uint256 _price) public onlyOwner {
        masterPrice = _price;
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

    function updateKycAuditStatus(
        address _poolAddress,
        bool _kyc,
        bool _audit,
        string memory _kyclink,
        string memory _auditlink
    ) public onlyOwner {
        require(IPoolManager(poolManager).isPoolGenerated(_poolAddress), "Pool Not exist !!");
        IPool(_poolAddress).setKycAudit(_kyc, _audit, _kyclink, _auditlink);
    }

    function setBondingToken(address _bondingToken) public onlyOwner {
        require(_bondingToken != address(0), "Bonding Token address must be set!!");
        bondingToken = _bondingToken;
    }

    function setBondingPool(address _bondingPool) public onlyOwner {
        require(_bondingPool != address(0), "Bonding Pool address must be set!");
        bondingPool = _bondingPool;
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
