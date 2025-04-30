// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IWETH} from "@uniswap/v2-periphery/interfaces/IWETH.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/interfaces/INonfungiblePositionManager.sol";
import {IPoolManager} from "./interfaces/IPoolManager.sol";
import {IFeedClient} from "./interfaces/IFeedClient.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISupraOraclePull} from "./interfaces/ISupraOraclePull.sol";

contract BondingPool is OwnableUpgradeable, ReentrancyGuardUpgradeable, IERC721Receiver {
    using SafeERC20 for IERC20;
    using Address for address payable;
    using EnumerableSet for EnumerableSet.AddressSet;

    enum PoolState {
        inUse,
        completed,
        cancelled
    }

    enum PoolType {
        presale,
        privatesale,
        fairsale,
        bonding
    }

    uint8 public VERSION;
    uint256 public tokenId;
    address public v3Pair;
    address public poolManager;
    address public nonfungiblePositionManager;
    address public governance;
    uint256 private buyFee; //percent
    uint256 private sellFee; //percent
    uint256 public marketCap; //amount here 69k
    address payable private adminWallet;
    address public supraFeedClient;

    // address public currency;
    address public token;
    // uint256 public rate;
    // uint256 public minContribution;
    // uint256 public maxContribution;
    // uint256 public softCap;
    // uint256 public hardCap;

    bool public auditStatus;
    bool public kycStatus;
    string public auditLink;
    string public kycLink;
    // string public ownerMail;

    uint256 private tokenFeePercent;
    uint256 private ethFeePercent;

    // uint256 public liquidityListingRate;

    string public poolDetails;

    PoolState public poolState;
    PoolType public poolType;

    uint256 public ethAmount;
    uint256 public totalVolumePurchased;

    uint256 public tokenAAmount;
    uint256 public tokenTotalSupply;

    uint256 public circulatingSupply; //near 4 Million * 10**18

    uint256 private k; // x*y = k
    uint256 public staleTimeThreshold = 30; // For Pricefeed  (default 30 sec)
    /// Conversion factor between millisecond and second
    uint256 public constant MILLISECOND_CONVERSION_FACTOR = 1000;
    ISupraOraclePull supraOraclePull;
    // bool public completedKyc;

    EnumerableSet.AddressSet private holders;

    event Buy(address indexed user, address indexed token, uint256 amount, uint256 timestamp);
    event Sell(address indexed user, address indexed token, uint256 amount, uint256 timestamp);

    event Finalized(uint256 liquidity, uint256 timestamp);

    event PoolUpdated(uint256 timestamp);

    modifier inProgress() {
        require(poolState == PoolState.inUse, "Pool is either completed or cancelled");
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == owner() || msg.sender == governance, "Only operator");
        _;
    }

    modifier onlyGovernance() {
        require(msg.sender == governance, "Only governance");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == adminWallet, "Only admin");
        _;
    }

    receive() external payable {
        // if (msg.value > 0) contribute(0);
    }

    function initialize(
        // uint8 _routerVersion,
        address[4] memory _addrs, //[0] = token addr, [1] = nonfungiblePositionManager, [2] = governance , [3] = supraFeedClient
        uint256[2] memory _feeSettings,
        uint256[4] memory _buySellFeeSettings, //[0] = buy Fee, [1] = sell fee, [2] = market cap settings, [3] = initialEthAmount(1eth * 10**18)
        string memory _poolDetails,
        address[3] memory _linkAddress, // [0] = master, [1] = pool manager, [2] = admin wallet
        uint8 _version,
        address _supraOraclePull
    ) external initializer {
        __ReentrancyGuard_init();
        require(poolManager == address(0), "Pool: Forbidden");
        require(_addrs[0] != address(0), "Invalid Token address");
        require(
            _feeSettings[0] >= 0 && _feeSettings[0] <= 100 && _feeSettings[1] >= 0 && _feeSettings[1] <= 100,
            "Invalid fee settings. Must be percentage (0 -> 100)"
        );
        require(
            _buySellFeeSettings[0] >= 0 && _buySellFeeSettings[0] <= 100 && _buySellFeeSettings[1] >= 0
                && _buySellFeeSettings[1] <= 100,
            "Invalid buy sell fee settings. Must be percentage (0 -> 100)"
        );
        require(_buySellFeeSettings[2] > 0, "Market Cap should be greater than 0!");
        require(_buySellFeeSettings[3] > 0, "Target Eth amount should be greater than 0!");
        __Ownable_init(_linkAddress[0]);
        // transferOwnership(_linkAddress[0]);
        poolManager = _linkAddress[1];
        adminWallet = payable(_linkAddress[2]);

        buyFee = _buySellFeeSettings[0];
        sellFee = _buySellFeeSettings[1];
        marketCap = _buySellFeeSettings[2];

        token = _addrs[0];
        nonfungiblePositionManager = _addrs[1];
        governance = _addrs[2];
        supraFeedClient = _addrs[3];
        //transfer 1% to dev wallet
        IERC20(token).safeTransfer(governance, IERC20(token).balanceOf(address(this)) / 100);
        tokenAAmount = IERC20(token).balanceOf(address(this));
        tokenTotalSupply = tokenAAmount;

        IERC20(token).forceApprove(address(this), tokenAAmount);
        ethAmount = address(this).balance + _buySellFeeSettings[3]; // As if 1 eth collected already -- to prevent first user sweep
        k = tokenAAmount * ethAmount;
        tokenFeePercent = _feeSettings[0];
        ethFeePercent = _feeSettings[1];
        poolDetails = _poolDetails;
        poolState = PoolState.inUse;
        VERSION = _version;
        poolType = PoolType.bonding;
        supraOraclePull = ISupraOraclePull(_supraOraclePull);

        //marketCap/ethPrice = circulatingSupply*collectingEth**2/k; let's say marketCap= circulatingSupply * ethAmount/tokenAamount;
        // circulatingSupply = 10 ** getDecimal() * (marketCap * 10 ** 18 / getLatestPrice()) * (k / _buySellFeeSettings[3] ** 2); //setting decimal;
        circulatingSupply = tokenAAmount;
    }

    // function getLatestPrice() public view returns (uint256) {
    //     (uint80 roundID, int256 price,, uint256 timeStamp, uint80 answeredInRound) =
    //         AggregatorV3Interface(supraFeedClient).latestRoundData();

    //     uint256 decimalsFeed = AggregatorV3Interface(supraFeedClient).decimals();
    //     // Validate price feed data
    //     require(price > 0 && answeredInRound >= roundID && timeStamp != 0);

    //     return uint256(price) * 10 ** (18 - decimalsFeed); // Price comes with variable decimals but we need 18
    // }
    function getLatestPrice() public view returns (uint256, uint256) {
        uint256[4] memory response = IFeedClient(supraFeedClient).getPrice(uint64(1)); // 1 is feedIndex of ETH_USDT

        uint256 decimalsFeed = response[1];
        uint256 updateTimestamp = response[2] / MILLISECOND_CONVERSION_FACTOR;
        uint256 price = response[3];
        // Validate price feed data
        // require(price > 0, "zero price");
        // require(block.timestamp - updateTimestamp <= staleTimeThreshold, "Stale price data");

        return (uint256(price) * 10 ** (18 - decimalsFeed), updateTimestamp); // Price comes with variable decimals but we need 18
    }

    function getDecimal() public view returns (uint8) {
        uint8 decimals = IERC20Metadata(token).decimals();
        return decimals;
    }

    function getHolders() external view returns (uint256, address[] memory) {
        address[] memory _holders = new address[](holders.length());
        for (uint256 i = 0; i < holders.length(); i++) {
            _holders[i] = holders.at(i);
        }
        return (holders.length(), _holders);
    }

    function getPoolInfo()
        external
        view
        returns (
            address,
            uint8[] memory,
            uint256[] memory,
            string memory,
            string memory,
            string memory,
            uint256,
            address,
            address[] memory,
            uint256
        )
    {
        // uint256 tokenPrice = getTokenPrice();
        uint8[] memory state = new uint8[](3);
        uint256[] memory info = new uint256[](6);
        address[] memory _holders = new address[](holders.length());
        for (uint256 i = 0; i < holders.length(); i++) {
            _holders[i] = holders.at(i);
        }
        state[0] = uint8(poolState);
        state[1] = uint8(poolType);
        state[2] = IERC20Metadata(token).decimals();
        info[0] = ethAmount;
        info[1] = tokenAAmount;
        info[2] = kycStatus == true ? 1 : 0;
        info[3] = auditStatus == true ? 1 : 0;
        info[4] = marketCap;
        info[5] = circulatingSupply;

        return (
            token,
            state,
            info,
            IERC20Metadata(token).name(),
            IERC20Metadata(token).symbol(),
            poolDetails,
            tokenId,
            v3Pair,
            _holders,
            // tokenPrice,
            tokenTotalSupply
        );
    }

    function swap(uint256 _amount, uint256 _type, bytes calldata _bytesProof) public payable inProgress {
        // type==1 ? buy: type==2? sell
        uint256 amount = _type == 1 ? msg.value : _amount;
        require(amount > 0, "Cant buy or sell 0");
        // xy = k => Constant product formula
        // (x + dx)(y - dy) = k
        // y - dy = k / (x + dx)
        // y - dy = xy / (x + dx)
        // dy = y - (xy / (x + dx))
        // dy = yx + ydx - xy / (x + dx)
        // formula => dy = ydx / (x + dx)

        uint256 dy;
        // uint256 dy = getReserves(amount, _type);
        uint256 _tokenPrice;
        uint256 updateTimestamp;
        uint256 currentMK;
        if (_type == 2) {
            //sell
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            dy = ethAmount - (k / (tokenAAmount + amount)); // eth amount to pop
            uint256 sellFeeAmount = dy * sellFee / 100;
            payable(adminWallet).sendValue(sellFeeAmount);
            payable(msg.sender).sendValue(dy - sellFeeAmount);
            tokenAAmount = tokenAAmount + amount;
            ethAmount = ethAmount - dy;
            uint256 senderTokenAmount = IERC20(token).balanceOf(msg.sender);
            if (senderTokenAmount == 0 && holders.contains(msg.sender)) {
                holders.remove(msg.sender);
            }
            emit Sell(msg.sender, token, amount, block.timestamp);
        } else if (_type == 1) {
            // buy
            uint256 buyFeeAmount = amount * buyFee / 100;
            payable(adminWallet).sendValue(buyFeeAmount);
            dy = tokenAAmount - (k / (ethAmount + amount - buyFeeAmount));
            IERC20(token).safeTransferFrom(address(this), msg.sender, dy);
            holders.add(msg.sender);
            tokenAAmount = tokenAAmount - dy;
            ethAmount = ethAmount + amount - buyFeeAmount;
            (_tokenPrice, updateTimestamp) = getTokenPrice();
            if (block.timestamp - updateTimestamp > staleTimeThreshold) {
                supraOraclePull.verifyOracleProof(_bytesProof); //If it fails, txn reverts
                (_tokenPrice, updateTimestamp) = getTokenPrice();
            }

            require(block.timestamp - updateTimestamp <= staleTimeThreshold, "Stale price data"); //@note This might be removed later
            currentMK = _tokenPrice * circulatingSupply;
            if (currentMK >= marketCap * (10 ** (18 + getDecimal()))) {
                // to make same 18 decimal and totalSupply has token decimal so did it
                finalize();
            }
            emit Buy(msg.sender, token, amount, block.timestamp);
        }
    }

    function forceFinalize() external onlyAdmin {
        finalize();
    }

    function getReserves(uint256 _amount, uint256 _type) public view returns (uint256) {
        // type == 1? buy: type == 2? sell
        uint256 dy;
        if (_type == 1) {
            // get tokenA amount corresponding eth _amount
            dy = tokenAAmount - (k / (ethAmount + _amount));
        } else if (_type == 2) {
            // get ETH amount corresponding tokenA _amount
            dy = dy = ethAmount - (k / (tokenAAmount + _amount)); // eth amount to pop
        }
        return dy;
    }

    function finalize() internal nonReentrant {
        require(poolState == PoolState.inUse, "Pool was finialized or cancelled");

        poolState = PoolState.completed;

        // Pay platform fees
        uint256 ethFee = (ethAmount * ethFeePercent) / 100;
        payable(adminWallet).sendValue(ethFee);
        ethAmount = ethAmount - ethFee;
        uint256 tokenFee;
        if (tokenFeePercent > 0) {
            tokenFee = (tokenAAmount * tokenFeePercent) / 100;
            IERC20(token).safeTransfer(adminWallet, tokenFee);
        }
        uint256 currencyAmount = address(this).balance;
        uint256 tokenAmount = IERC20(token).balanceOf(address(this));
        // IERC20(token).safeTransfer(address(0xdead), remainingToken);
        uint24 fee;
        //pancakeswap V3
        fee = 2500;
        //uniswap V3
        // fee = 3000;
        address currency = INonfungiblePositionManager(nonfungiblePositionManager).WETH9();
        if (currencyAmount > 0) {
            IWETH(currency).deposit{value: currencyAmount}();
        }
        address token0;
        address token1;
        uint256 amount0ToAdd;
        uint256 amount1ToAdd;
        int24 tickSpacing;
        if (currency > token) {
            token0 = token;
            token1 = currency;
            amount0ToAdd = tokenAmount;
            amount1ToAdd = currencyAmount;
        } else {
            token0 = currency;
            token1 = token;
            amount0ToAdd = currencyAmount;
            amount1ToAdd = tokenAmount;
        }
        {
            v3Pair = INonfungiblePositionManager(nonfungiblePositionManager).createAndInitializePoolIfNecessary(
                token0, token1, fee, uint160(Math.sqrt(Math.mulDiv(amount1ToAdd, 2 ** 192, amount0ToAdd)))
            );
            tickSpacing = IUniswapV3Pool(v3Pair).tickSpacing();
        }
        IERC20(token0).forceApprove(nonfungiblePositionManager, amount0ToAdd);
        IERC20(token1).forceApprove(nonfungiblePositionManager, amount1ToAdd);
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: fee,
            tickLower: (-887272 / tickSpacing) * tickSpacing,
            tickUpper: (887272 / tickSpacing) * tickSpacing,
            amount0Desired: amount0ToAdd,
            amount1Desired: amount1ToAdd,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp
        });

        (uint256 _tokenId, uint128 _liquidity, uint256 amount0, uint256 amount1) =
            INonfungiblePositionManager(nonfungiblePositionManager).mint(params);

        uint256 liquidity = uint256(_liquidity);
        tokenId = _tokenId;

        // IPoolManager(poolManager).removeTopPool(address(this));
        emit Finalized(liquidity, block.timestamp);
    }

    function getTokenPrice() public view returns (uint256, uint256) {
        (uint256 ethPrice, uint256 updateTime) = getLatestPrice(); // eth price in usd comes with 18 decimal;
        if (tokenAAmount > 0) {
            uint256 currentRate = (ethAmount * ethPrice) / (tokenAAmount * (10 ** (18 - getDecimal())));
            return (currentRate, updateTime);
        } else {
            return (0, 0);
        }
    }

    function withdrawLeftovers() external onlyOperator nonReentrant {
        IERC20(token).safeTransfer(governance, IERC20(token).balanceOf(address(this)));
    }

    function emergencyWithdrawLiquidity() external onlyOwner {
        INonfungiblePositionManager(nonfungiblePositionManager).safeTransferFrom(address(this), msg.sender, tokenId);
    }

    function emergencyWithdrawToken(address payaddress, address tokenAddress, uint256 tokens) external onlyOwner {
        IERC20(tokenAddress).safeTransfer(payaddress, tokens);
    }

    function emergencyWithdraw(address payable to_, uint256 amount_) external onlyOwner {
        to_.sendValue(amount_);
    }

    function updatePoolDetails(string memory details_) external onlyOperator {
        poolDetails = details_;
        emit PoolUpdated(block.timestamp);
    }

    function setGovernance(address governance_) external onlyOwner {
        governance = governance_;
    }

    function setKycAudit(bool _kyc, bool _audit, string memory _kyclink, string memory _auditlink) external onlyAdmin {
        kycStatus = _kyc;
        auditStatus = _audit;
        kycLink = _kyclink;
        auditLink = _auditlink;
    }

    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
