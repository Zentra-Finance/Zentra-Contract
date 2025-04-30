// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPoolManager} from "./interfaces/IPoolManager.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {PoolLibrary} from "./libraries/PoolLibrary.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/interfaces/INonfungiblePositionManager.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/interfaces/IUniswapV2Router02.sol";
import {IWETH} from "@uniswap/v2-periphery/interfaces/IWETH.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract FairPool is OwnableUpgradeable, ReentrancyGuardUpgradeable, IERC721Receiver {
    // using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address payable;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint8 public VERSION;
    uint256 public MINIMUM_LOCK_DAYS;
    uint256 public feesWithdraw;

    struct poolInfo {
        address currency;
        address token;
        uint256 startTime;
        uint256 endTime;
        uint256 totalRaised;
        uint256 softCap;
        uint8 poolState;
        uint8 poolType;
        uint256 rate;
        uint256 liquidityPercent;
        uint256 liquidityUnlockTime;
    }

    enum PoolState {
        inUse,
        completed,
        cancelled
    }

    enum PoolType {
        presale,
        privatesale,
        fairsale
    }

    uint256 public routerVersion;
    uint256 public tokenId;
    address public v3Pair;
    address public poolManager;
    address public router;
    address public governance;
    address payable private adminWallet;

    address public currency;
    address public token;
    uint256 public rate;
    // uint256 public minContribution;
    // uint256 public maxContribution;
    uint256 public softCap;
    // uint256 public hardCap;

    bool public audit;
    bool public kyc;
    bool public auditStatus;
    bool public kycStatus;
    string public auditLink;
    string public kycLink;
    string public ownerMail;

    uint256 public startTime;
    uint256 public endTime;

    uint256 private tokenFeePercent;
    uint256 private ethFeePercent;

    // uint256 public liquidityListingRate;
    uint256 public liquidityUnlockTime;
    uint256 public liquidityLockDays;
    uint256 public liquidityPercent;
    uint256 public refundType;

    string public poolDetails;

    PoolState public poolState;
    PoolType public poolType;

    uint256 public totalRaised;
    uint256 public totalVolumePurchased;
    uint256 public totalClaimed;
    uint256 public totalRefunded;

    uint256 public totalToken;

    uint256 private tvl;

    bool public completedKyc;

    mapping(address => uint256) public contributionOf;
    mapping(address => uint256) public purchasedOf;
    mapping(address => uint256) public claimedOf;
    mapping(address => uint256) public refundedOf;

    event Contributed(address indexed user, uint256 amount, uint256 timestamp);

    event WithdrawnContribution(address indexed user, uint256 amount);

    event Claimed(address indexed user, uint256 volume, uint256 total);

    event Finalized(uint256 liquidity, uint256 timestamp);

    event Cancelled(uint256 timestamp);

    event PoolUpdated(uint256 timestamp);

    event KycUpdated(bool completed, uint256 timestamp);

    event LiquidityWithdrawn(uint256 amount, uint256 timestamp);

    modifier inProgress() {
        require(poolState == PoolState.inUse, "Pool is either completed or cancelled");
        require(block.timestamp >= startTime && block.timestamp < endTime, "It's not time to buy");
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
        if (msg.value > 0) contribute(0);
    }

    function initialize(
        address[4] memory _addrs, // [0] = token, [1] = router, [2] = governance , [3] = currency
        uint256[2] memory _capSettings,
        uint256[3] memory _timeSettings,
        uint256[2] memory _feeSettings,
        uint256[3] memory _auditKRVTokenId, //[0] = audit, [1] = kyc, [2] = routerVersion (2 ==v2 or 3 ==v3)
        uint256[2] memory _liquidityPercent,
        string memory _poolDetails,
        address[3] memory _linkAddress, // [0] = master, [1] = pool manager, [2] = admin wallet
        uint8 _version,
        uint256 _feesWithdraw,
        string[3] memory _otherInfo
    ) external initializer {
        __ReentrancyGuard_init();

        require(poolManager == address(0), "Pool: Forbidden");
        _validateInputs(_addrs, _capSettings, _timeSettings, _feeSettings, _liquidityPercent);

        __Ownable_init(_linkAddress[0]);
        _initializeAddresses(_addrs, _linkAddress);
        _initializeSettings(_capSettings, _timeSettings, _feeSettings, _auditKRVTokenId, _liquidityPercent);

        poolDetails = _poolDetails;
        VERSION = _version;
        feesWithdraw = _feesWithdraw;
        auditLink = _otherInfo[0];
        kycLink = _otherInfo[1];
        ownerMail = _otherInfo[2];
        poolType = PoolType.fairsale;
        poolState = PoolState.inUse;
        MINIMUM_LOCK_DAYS = 5 minutes;
    }

    function _validateInputs(
        address[4] memory _addrs,
        uint256[2] memory _capSettings,
        uint256[3] memory _timeSettings,
        uint256[2] memory _feeSettings,
        uint256[2] memory _liquidityPercent
    ) internal view {
        require(_addrs[0] != address(0), "Invalid Token address");
        require(_capSettings[0] > 0, "Softcap must be >= 0");
        require(_timeSettings[0] < _timeSettings[1], "End time must be after start time");
        require(
            _timeSettings[2] >= MINIMUM_LOCK_DAYS,
            "Liquidity unlock time must be at least 1 Mintues after pool is finalized"
        );
        require(_feeSettings[0] <= 100 && _feeSettings[1] <= 100, "Invalid fee settings. Must be percentage (0 -> 100)");
        require(_liquidityPercent[0] >= 51 && _liquidityPercent[0] <= 100, "Invalid liquidity percentage");
        require(_liquidityPercent[1] == 0 || _liquidityPercent[1] == 1, "Refund type must be 0 (refund) or 1 (burn)");
    }

    function _initializeAddresses(address[4] memory _addrs, address[3] memory _linkAddress) internal {
        transferOwnership(_linkAddress[0]);
        poolManager = _linkAddress[1];
        adminWallet = payable(_linkAddress[2]);
        token = _addrs[0];
        router = _addrs[1];
        governance = _addrs[2];
        currency = _addrs[3];
    }

    function _initializeSettings(
        uint256[2] memory _capSettings,
        uint256[3] memory _timeSettings,
        uint256[2] memory _feeSettings,
        uint256[3] memory _auditKRVTokenId,
        uint256[2] memory _liquidityPercent
    ) internal {
        softCap = _capSettings[0];
        totalToken = _capSettings[1];
        startTime = _timeSettings[0];
        endTime = _timeSettings[1];
        liquidityLockDays = _timeSettings[2];
        tokenFeePercent = _feeSettings[0];
        ethFeePercent = _feeSettings[1];
        audit = _auditKRVTokenId[0] == 1;
        kyc = _auditKRVTokenId[1] == 1;
        routerVersion = _auditKRVTokenId[2];
        liquidityPercent = _liquidityPercent[0];
        refundType = _liquidityPercent[1];
    }

    function getDecimal() public view returns (uint8) {
        uint8 decimals = IERC20Metadata(token).decimals();
        return decimals;
    }

    // last 3 is routerVersion, tokenId, pair addr
    function getPoolInfo()
        external
        view
        returns (
            address,
            address,
            uint8[] memory,
            uint256[] memory,
            string memory,
            string memory,
            string memory,
            uint256,
            uint256,
            address
        )
    {
        uint8[] memory state = new uint8[](3);
        uint256[] memory info = new uint256[](11);

        state[0] = uint8(poolState);
        state[1] = uint8(poolType);
        state[2] = IERC20Metadata(token).decimals();
        info[0] = startTime;
        info[1] = endTime;
        info[2] = totalRaised;
        info[3] = kycStatus == true ? 1 : 0;
        info[4] = softCap;
        info[5] = kyc == true ? 1 : 0;
        info[6] = audit == true ? 1 : 0;
        info[7] = rate;
        info[8] = auditStatus == true ? 1 : 0;
        info[9] = liquidityPercent;
        info[10] = liquidityUnlockTime;

        return (
            token,
            currency,
            state,
            info,
            IERC20Metadata(token).name(),
            IERC20Metadata(token).symbol(),
            poolDetails,
            routerVersion,
            tokenId,
            v3Pair
        );
    }

    function contribute(uint256 _amount) public payable inProgress {
        uint256 amount = currency == address(0) ? msg.value : _amount;
        require(amount > 0, "Cant contribute 0");

        if (currency != address(0)) {
            IERC20(currency).safeTransferFrom(msg.sender, address(this), amount);
        }

        uint256 userTotalContribution = contributionOf[msg.sender] + amount;

        if (contributionOf[msg.sender] == 0) {
            IPoolManager(poolManager).recordContribution(msg.sender, address(this));
        }

        contributionOf[msg.sender] = userTotalContribution;
        totalRaised = totalRaised + amount;

        // IPoolManager(poolManager).addTopPool(address(this), currency, totalRaised);
        emit Contributed(msg.sender, amount, block.timestamp);
    }

    function claim() public nonReentrant {
        require(poolState == PoolState.completed, "Owner has not closed the pool yet");
        require(contributionOf[msg.sender] > 0, "you don't have enough contribution!!");

        uint256 volume = contributionOf[msg.sender];
        uint256 totalClaim = claimedOf[msg.sender];
        uint256 claimble = PoolLibrary.convertCurrencyToToken(volume, rate);
        uint256 avalible = claimble - totalClaim;
        require(avalible > 0, "NO Reward Avalible For Claim");

        claimedOf[msg.sender] += avalible;
        totalClaimed = totalClaimed + avalible;
        IERC20(token).safeTransfer(msg.sender, avalible);
        emit Claimed(msg.sender, avalible, totalClaimed);
    }

    function withdrawContribution() external nonReentrant {
        if (poolState == PoolState.inUse) {
            require(block.timestamp >= endTime, "Pool is still in progress");
            require(totalRaised < softCap, "Soft cap reached");
        } else {
            require(poolState == PoolState.cancelled, "Cannot withdraw contribution because pool is completed");
        }
        require(contributionOf[msg.sender] > 0, "You Don't Have Enough contribution");
        uint256 fees = 0;
        if (poolState == PoolState.inUse) {
            fees = feesWithdraw;
        }
        uint256 refundAmount = contributionOf[msg.sender];
        totalVolumePurchased = totalVolumePurchased - purchasedOf[msg.sender];

        refundedOf[msg.sender] = refundAmount;
        totalRefunded = totalRefunded + refundAmount;
        contributionOf[msg.sender] = 0;
        purchasedOf[msg.sender] = 0;
        totalRaised = totalRaised - refundAmount;
        uint256 Countfees = (refundAmount * fees) / 10000;
        refundAmount = refundAmount - Countfees;

        if (currency == address(0)) {
            payable(msg.sender).sendValue(refundAmount);
            payable(adminWallet).sendValue(Countfees);
        } else {
            IERC20(currency).safeTransfer(msg.sender, refundAmount);
            IERC20(currency).safeTransfer(adminWallet, Countfees);
        }

        emit WithdrawnContribution(msg.sender, refundAmount);
    }

    function finalize() external onlyOperator nonReentrant {
        require(poolState == PoolState.inUse, "Pool was finialized or cancelled");
        // require(totalRaised >= softCap && block.timestamp >= endTime,
        //     "It is not time to finish"
        // );
        require(totalRaised >= softCap, "Softcap didn't reached!");

        uint256 currentRate = (totalToken * (10 ** 18)) / totalRaised;

        poolState = PoolState.completed;
        totalVolumePurchased = totalToken;
        rate = currentRate;
        liquidityUnlockTime = block.timestamp + liquidityLockDays;
        (uint256 ethFee, uint256 tokenFee, uint256 liquidityEth, uint256 liquidityToken) = PoolLibrary
            .calculateFeeAndLiquidity(
            totalRaised, ethFeePercent, tokenFeePercent, totalToken, liquidityPercent, currentRate
        );

        uint256 currencyAmount =
            currency == address(0) ? address(this).balance : IERC20(currency).balanceOf(address(this));
        uint256 remainingEth = currencyAmount - liquidityEth - ethFee;
        uint256 remainingToken = 0;

        uint256 totalTokenSpent = liquidityToken + tokenFee + totalToken;
        remainingToken += IERC20(token).balanceOf(address(this)) - totalTokenSpent;

        // Pay platform fees
        if (ethFee > 0) {
            if (currency == address(0)) {
                payable(adminWallet).sendValue(ethFee);
            } else {
                IERC20(currency).safeTransfer(adminWallet, ethFee);
            }
        }
        if (tokenFee > 0) {
            IERC20(token).safeTransfer(adminWallet, tokenFee);
        }

        // Refund remaining
        if (remainingEth > 0) {
            if (currency == address(0)) {
                payable(governance).sendValue(remainingEth);
            } else {
                IERC20(currency).safeTransfer(governance, remainingEth);
            }
        }

        if (remainingToken > 0) {
            // 0: refund, 1: burn
            if (refundType == 0) {
                IERC20(token).safeTransfer(governance, remainingToken);
            } else {
                IERC20(token).safeTransfer(address(0xdead), remainingToken);
            }
        }

        tvl = liquidityEth * 2;
        IPoolManager(poolManager).increaseTotalValueLocked(currency, tvl);
        uint256 liquidity;
        if (routerVersion == 2) {
            //V@
            liquidity = PoolLibrary.addLiquidity(router, currency, token, liquidityEth, liquidityToken, address(this));
        } else {
            uint24 fee;
            if (routerVersion == 3) {
                // V3
                fee = 3000;
            }

            if (currency == address(0)) {
                currency = INonfungiblePositionManager(router).WETH9();
                if (liquidityEth > 0) {
                    IWETH(currency).deposit{value: liquidityEth}();
                }
            }
            address token0;
            address token1;
            uint256 amount0ToAdd;
            uint256 amount1ToAdd;
            int24 tickSpacing;
            if (currency > token) {
                token0 = token;
                token1 = currency;
                amount0ToAdd = liquidityToken;
                amount1ToAdd = liquidityEth;
            } else {
                token0 = currency;
                token1 = token;
                amount0ToAdd = liquidityEth;
                amount1ToAdd = liquidityToken;
            }
            {
                v3Pair = INonfungiblePositionManager(router).createAndInitializePoolIfNecessary(
                    token0, token1, fee, uint160(Math.sqrt(Math.mulDiv(amount1ToAdd, 2 ** 192, amount0ToAdd)))
                );
                tickSpacing = IUniswapV3Pool(v3Pair).tickSpacing();
            }
            IERC20(token0).forceApprove(router, amount0ToAdd);
            IERC20(token1).forceApprove(router, amount1ToAdd);
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
                INonfungiblePositionManager(router).mint(params);

            liquidity = uint256(_liquidity);
            tokenId = _tokenId;
            // send remaining eth
            if (token0 == currency) {
                IERC20(token0).safeTransfer(governance, amount0ToAdd - amount0);
                if (refundType == 0) {
                    IERC20(token1).safeTransfer(governance, amount1ToAdd - amount1);
                } else {
                    IERC20(token1).safeTransfer(address(0xdead), amount1ToAdd - amount1);
                }
            } else {
                IERC20(token1).safeTransfer(governance, amount1ToAdd - amount1);
                if (refundType == 0) {
                    IERC20(token0).safeTransfer(governance, amount0ToAdd - amount0);
                } else {
                    IERC20(token0).safeTransfer(address(0xdead), amount0ToAdd - amount0);
                }
            }
        }

        // IPoolManager(poolManager).removeTopPool(address(this));
        emit Finalized(liquidity, block.timestamp);
    }

    function getPrice() public view returns (uint256) {
        if (totalRaised > 0) {
            uint256 currentRate = (totalToken * (10 ** 18)) / totalRaised;
            return currentRate;
        } else {
            return 0;
        }
    }

    function cancel() external onlyOperator {
        require(poolState == PoolState.inUse, "Pool was either finished or cancelled");
        poolState = PoolState.cancelled;
        IPoolManager(poolManager).removeFairPoolForToken(token, address(this));
        IERC20(token).safeTransfer(governance, IERC20(token).balanceOf(address(this)));
        // IPoolManager(poolManager).removeTopPool(address(this));
        emit Cancelled(block.timestamp);
    }

    function withdrawLeftovers() external onlyOperator nonReentrant {
        require(block.timestamp >= endTime, "It is not time to withdraw leftovers");
        require(totalRaised < softCap, "Soft cap reached, call finalize() instead");
        IERC20(token).safeTransfer(governance, IERC20(token).balanceOf(address(this)));
    }

    function withdrawLiquidity() external onlyOperator {
        require(poolState == PoolState.completed, "Pool has not been finalized");
        require(block.timestamp >= liquidityUnlockTime, "It is not time to unlock liquidity");
        IPoolManager(poolManager).decreaseTotalValueLocked(currency, tvl);
        tvl = 0;
        if (routerVersion == 2) {
            address swapFactory = IUniswapV2Router02(router).factory();
            address pair = IUniswapV2Factory(swapFactory).getPair(
                currency == address(0) ? IUniswapV2Router02(router).WETH() : currency, token
            );
            uint256 balance = IERC20(pair).balanceOf(address(this));
            IERC20(pair).safeTransfer(governance, balance);
        } else {
            INonfungiblePositionManager(router).safeTransferFrom(address(this), msg.sender, tokenId);
        }

        // emit LiquidityWithdrawn(balance, block.timestamp);
    }

    function emergencyWithdrawLiquidity() external onlyOwner {
        if (routerVersion == 2) {
            address swapFactory = IUniswapV2Router02(router).factory();
            address pair = IUniswapV2Factory(swapFactory).getPair(
                currency == address(0) ? IUniswapV2Router02(router).WETH() : currency, token
            );
            uint256 balance = IERC20(pair).balanceOf(address(this));
            IERC20(pair).safeTransfer(msg.sender, balance);
        } else {
            INonfungiblePositionManager(router).safeTransferFrom(address(this), msg.sender, tokenId);
        }
    }

    function emergencyWithdrawToken(address payaddress, address tokenAddress, uint256 tokens) external onlyOwner {
        IERC20(tokenAddress).transfer(payaddress, tokens);
    }

    function emergencyWithdraw(address payable to_, uint256 amount_) external onlyOwner {
        to_.sendValue(amount_);
    }

    function updatePoolDetails(string memory details_) external onlyOperator {
        poolDetails = details_;
        emit PoolUpdated(block.timestamp);
    }

    function updateCompletedKyc(bool completed_) external onlyOwner {
        completedKyc = completed_;
        emit KycUpdated(completed_, block.timestamp);
    }

    function setGovernance(address governance_) external onlyOwner {
        governance = governance_;
    }

    function liquidityBalance() public view returns (uint256) {
        address swapFactory = IUniswapV2Router02(router).factory();
        address pair = IUniswapV2Factory(swapFactory).getPair(
            currency == address(0) ? IUniswapV2Router02(router).WETH() : currency, token
        );
        if (pair == address(0)) return 0;
        return IERC20(pair).balanceOf(address(this));
    }

    function convert(uint256 amountInWei) public view returns (uint256) {
        return PoolLibrary.convertCurrencyToToken(amountInWei, rate);
    }

    function getUpdatedState() public view returns (uint256, uint8, bool, uint256, string memory) {
        return (totalRaised, uint8(poolState), completedKyc, liquidityUnlockTime, poolDetails);
    }

    function userAvalibleClaim(address _userAddress) public view returns (uint256) {
        uint256 volume = contributionOf[_userAddress];
        if (volume > 0 && poolState == PoolState.completed) {
            uint256 totalClaim = claimedOf[_userAddress];
            uint256 claimble = PoolLibrary.convertCurrencyToToken(volume, rate);
            uint256 avalible = claimble - totalClaim;
            return avalible;
        } else {
            return 0;
        }
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
