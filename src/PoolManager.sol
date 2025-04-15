// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
pragma experimental ABIEncoderV2;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IPool} from "./interfaces/IPool.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IBondingPool} from "./interfaces/IBondingPool.sol";
import {IPoolManager} from "./interfaces/IPoolManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IPancakePair {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);

    function burn(address to) external returns (uint256 amount0, uint256 amount1);

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;

    function skim(address to) external;

    function sync() external;

    function initialize(address, address) external;
}

contract PoolManager is OwnableUpgradeable, IPoolManager {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    event TvlChanged(address currency, uint256 totalLocked, uint256 totalRaised);
    event ContributionUpdated(uint256 totalParticipations);
    event PoolForTokenRemoved(address indexed token, address pool);

    struct CumulativeLockInfo {
        address poolAddress;
        address token;
        address currency;
        uint8 poolState;
        uint8 poolType;
        uint8 decimals;
        uint256 startTime;
        uint256 endTime;
        uint256 totalRaised;
        uint256 hardCap;
        uint256 softCap;
        uint256 minContribution;
        uint256 maxContribution;
        uint256 rate;
        uint256 liquidityListingRate;
        uint256 liquidityPercent;
        uint256 liquidityUnlockTime;
        string name;
        string symbol;
        string poolDetails;
        uint256 routerVersion;
        uint256 tokenId;
        address v3Pair;
    }

    struct CumulativeBondingInfo {
        address poolAddress;
        address token;
        uint8 poolState;
        uint8 poolType;
        uint8 decimals;
        uint256 ethAmount;
        uint256 tokenAAmount;
        uint256 kycStatus;
        uint256 auditStatus;
        uint256 markectCap;
        uint256 circulatingSupply;
        string name;
        string symbol;
        string poolDetails;
        uint256 tokenId;
        address v3Pair;
        address[] _holders;
        uint256 tokenPrice;
        uint256 tokenTotalSupply;
    }

    struct TopPoolInfo {
        uint256 totalRaised;
        address poolAddress;
    }

    EnumerableSet.AddressSet private poolFactories;
    EnumerableSet.AddressSet private _pools;

    mapping(uint8 => EnumerableSet.AddressSet) private _poolsForVersion;
    mapping(address => EnumerableSet.AddressSet) private _poolsOf;
    mapping(address => EnumerableSet.AddressSet) private _contributedPoolsOf;
    mapping(address => address) private _poolForToken;
    TopPoolInfo[] private _topPools;

    address public WETH;
    IPancakePair public ethUSDTPool;
    mapping(address => uint256) public totalValueLocked;
    mapping(address => uint256) public totalLiquidityRaised;
    uint256 public totalParticipants;

    EnumerableSet.AddressSet private _bondingPools; // pools for bonding

    event sender(address sender);

    receive() external payable {}

    function initialize(address _WETH, address _ethUSDTPool) external initializer {
        WETH = _WETH;
        ethUSDTPool = IPancakePair(_ethUSDTPool);
        __Ownable_init(msg.sender);
    }

    modifier onlyAllowedFactory() {
        emit sender(msg.sender);
        require(poolFactories.contains(msg.sender), "Not a whitelisted factory");
        _;
    }

    function getETHPrice() public view returns (uint256) {
        (uint256 _reserve0, uint256 _reserve1,) = ethUSDTPool.getReserves();
        if (ethUSDTPool.token0() == WETH) {
            return (_reserve1 * 1e18) / _reserve0;
        } else {
            return (_reserve0 * 1e18) / _reserve1;
        }
    }

    function updateETHUSDtPool(address pool) public onlyOwner {
        ethUSDTPool = IPancakePair(pool);
    }

    function addPoolFactory(address factory) public onlyAllowedFactory {
        poolFactories.add(factory);
    }

    function addAdminPoolFactory(address factory) public onlyOwner {
        poolFactories.add(factory);
    }

    function addPoolFactories(address[] memory factories) external onlyOwner {
        for (uint256 i = 0; i < factories.length; i++) {
            addPoolFactory(factories[i]);
        }
    }

    function removePoolFactory(address factory) external onlyOwner {
        poolFactories.remove(factory);
    }

    function isPoolGenerated(address pool) public view returns (bool) {
        return _pools.contains(pool);
    }

    function poolForToken(address token) external view returns (address) {
        return _poolForToken[token];
    }

    function registerPool(address pool, address token, address owner, uint8 version) external onlyAllowedFactory {
        _pools.add(pool);
        _poolsForVersion[version].add(pool);
        _poolsOf[owner].add(pool);
        _poolForToken[token] = pool;
    }

    function registerBondingPool(address pool, address token, address owner, uint8 version)
        external
        onlyAllowedFactory
    {
        _bondingPools.add(pool);
        _poolsForVersion[version].add(pool);
        _poolsOf[owner].add(pool);
        _poolForToken[token] = pool;
    }

    function increaseTotalValueLocked(address currency, uint256 value) external onlyAllowedFactory {
        totalValueLocked[currency] = totalValueLocked[currency] + value;
        totalLiquidityRaised[currency] = totalLiquidityRaised[currency] + value;

        emit TvlChanged(currency, totalValueLocked[currency], totalLiquidityRaised[currency]);
    }

    function decreaseTotalValueLocked(address currency, uint256 value) external onlyAllowedFactory {
        if (totalValueLocked[currency] < value) {
            totalValueLocked[currency] = 0;
        } else {
            totalValueLocked[currency] = totalValueLocked[currency] - value;
        }
        emit TvlChanged(currency, totalValueLocked[currency], totalLiquidityRaised[currency]);
    }

    function recordContribution(address user, address pool) external onlyAllowedFactory {
        totalParticipants = totalParticipants + 1;
        _contributedPoolsOf[user].add(pool);
        emit ContributionUpdated(totalParticipants);
    }

    function removePoolForToken(address token, address pool) external onlyAllowedFactory {
        _poolForToken[token] = address(0);
        emit PoolForTokenRemoved(token, pool);
    }

    function emergencyRemovePoolForToken(address token, address pool) public onlyOwner {
        _poolForToken[token] = address(0);
        _pools.remove(pool);
        emit PoolForTokenRemoved(token, pool);
    }

    function getPoolsOf(address owner) public view returns (address[] memory) {
        uint256 length = _poolsOf[owner].length();
        address[] memory allPools = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            allPools[i] = _poolsOf[owner].at(i);
        }
        return allPools;
    }

    function getAllPools() public view returns (address[] memory) {
        uint256 length = _pools.length();
        address[] memory allPools = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            allPools[i] = _pools.at(i);
        }
        return allPools;
    }

    function getPoolAt(uint256 index) public view returns (address) {
        return _pools.at(index);
    }

    function removePoolAt(uint256 index) public onlyOwner {
        address poolAddress = _pools.at(index);
        _pools.remove(poolAddress);
    }

    function removeBondingPoolAt(uint256 index) public onlyOwner {
        address poolAddress = _bondingPools.at(index);
        _bondingPools.remove(poolAddress);
    }

    function getTotalNumberOfPools() public view returns (uint256) {
        return _pools.length();
    }

    function getTotalNumberOfBondingPools() public view returns (uint256) {
        return _bondingPools.length();
    }

    function getTotalNumberOfContributedPools(address user) public view returns (uint256) {
        return _contributedPoolsOf[user].length();
    }

    function getAllContributedPools(address user) public view returns (address[] memory) {
        uint256 length = _contributedPoolsOf[user].length();
        address[] memory allPools = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            allPools[i] = _contributedPoolsOf[user].at(i);
        }
        return allPools;
    }

    function getContributedPoolAtIndex(address user, uint256 index) public view returns (address) {
        return _contributedPoolsOf[user].at(index);
    }

    function getTotalNumberOfPools(uint8 version) public view returns (uint256) {
        return _poolsForVersion[version].length();
    }

    function getPoolAt(uint8 version, uint256 index) public view returns (address) {
        return _poolsForVersion[version].at(index);
    }

    function getTopPool() public view returns (TopPoolInfo[] memory) {
        return _topPools;
    }

    function initializeTopPools() public onlyOwner {
        for (uint256 i = 0; i < 50; i++) {
            _topPools.push(TopPoolInfo(0, address(0)));
        }
    }

    function addTopPool(address poolAddress, address currency, uint256 raisedAmount) external onlyAllowedFactory {
        uint256 ETHPrice = currency == address(0) ? getETHPrice() : 1e18;
        raisedAmount = raisedAmount * ETHPrice;
        if (raisedAmount >= _topPools[49].totalRaised) {
            bool status = false;

            for (uint256 i = 0; i < 49; i++) {
                if (status || _topPools[i].poolAddress == poolAddress) {
                    _topPools[i] = _topPools[i + 1];
                    status = true;
                }
            }

            _topPools[49] = TopPoolInfo(0, address(0));

            status = false;
            TopPoolInfo memory tmp;
            for (uint256 i = 0; i < 50; i++) {
                if (!status && _topPools[i].totalRaised <= raisedAmount) {
                    tmp = _topPools[i];
                    _topPools[i] = TopPoolInfo(raisedAmount, poolAddress);
                    status = true;
                } else if (status) {
                    TopPoolInfo memory tmp1 = tmp;
                    tmp = _topPools[i];
                    _topPools[i] = tmp1;
                }
            }
        }
    }

    function removeTopPool(address poolAddress) external onlyAllowedFactory {
        bool status = false;

        for (uint256 i = 0; i < 49; i++) {
            if (status || _topPools[i].poolAddress == poolAddress) {
                _topPools[i] = _topPools[i + 1];
                status = true;
            }
        }

        _topPools[49] = TopPoolInfo(0, address(0));
    }

    function getCumulativeBondingInfo() external view returns (CumulativeBondingInfo[] memory) {
        uint256 length = _bondingPools.length();
        CumulativeBondingInfo[] memory bondingInfo = new CumulativeBondingInfo[](length);
        for (uint256 i = 0; i < length; i++) {
            (
                address token,
                uint8[] memory saleType,
                uint256[] memory info,
                string memory name,
                string memory symbol,
                string memory poolDetails,
                uint256 tokenId,
                address v3Pair,
                address[] memory _holders,
                uint256 tokenPrice,
                uint256 tokenTotalSupply
            ) = IBondingPool(_bondingPools.at(i)).getPoolInfo();
            bondingInfo[i] = CumulativeBondingInfo(
                _bondingPools.at(i),
                token,
                saleType[0], //poolState
                saleType[1], //poolType
                saleType[2], //decimal
                info[0], //ethAmount
                info[1], //kokenAMount
                info[2], //kycStatus
                info[3], //auditStatus
                info[4], //marketCap
                info[5], //circulatingSupply
                name,
                symbol,
                poolDetails,
                tokenId,
                v3Pair,
                _holders,
                tokenPrice,
                tokenTotalSupply
            );
        }
        return bondingInfo;
    }

    function getCumulativePoolInfo(uint256 start, uint256 end) external view returns (CumulativeLockInfo[] memory) {
        if (end >= _pools.length()) {
            end = _pools.length() - 1;
        }
        uint256 length = end - start + 1;
        CumulativeLockInfo[] memory lockInfo = new CumulativeLockInfo[](length);
        uint256 currentIndex = 0;

        for (uint256 i = start; i <= end; i++) {
            (
                address token,
                address currency,
                uint8[] memory saleType,
                uint256[] memory info,
                string memory name,
                string memory symbol,
                string memory poolDetails,
                uint256 routerVersion,
                uint256 tokenId,
                address v3Pair
            ) = IPool(_pools.at(i)).getPoolInfo();
            lockInfo[currentIndex] = CumulativeLockInfo(
                _pools.at(i),
                token,
                currency,
                saleType[0],
                saleType[1],
                saleType[2],
                info[0],
                info[1],
                info[2],
                info[3],
                info[4],
                info[5],
                info[6],
                info[7],
                info[8],
                info[9],
                info[10],
                name,
                symbol,
                poolDetails,
                routerVersion,
                tokenId,
                v3Pair
            );
            currentIndex++;
        }
        return lockInfo;
    }

    function getUserContributedPoolInfo(address userAddress, uint256 start, uint256 end)
        external
        view
        returns (CumulativeLockInfo[] memory)
    {
        if (end >= _contributedPoolsOf[userAddress].length()) {
            end = _contributedPoolsOf[userAddress].length() - 1;
        }
        uint256 length = end - start + 1;
        CumulativeLockInfo[] memory lockInfo = new CumulativeLockInfo[](length);
        uint256 currentIndex = 0;
        address user = userAddress;
        EnumerableSet.AddressSet storage poolAddrs = _contributedPoolsOf[user];
        for (uint256 i = start; i <= end; i++) {
            (
                address token,
                address currency,
                uint8[] memory saleType,
                uint256[] memory info,
                string memory name,
                string memory symbol,
                string memory poolDetails,
                uint256 routerVersion,
                uint256 tokenId,
                address v3Pair
            ) = IPool(poolAddrs.at(i)).getPoolInfo();
            lockInfo[currentIndex] = CumulativeLockInfo(
                poolAddrs.at(i),
                token,
                currency,
                saleType[0],
                saleType[1],
                saleType[2],
                info[0],
                info[1],
                info[2],
                info[3],
                info[4],
                info[5],
                info[6],
                info[7],
                info[8],
                info[9],
                info[10],
                name,
                symbol,
                poolDetails,
                routerVersion,
                tokenId,
                v3Pair
            );
            currentIndex++;
        }
        return lockInfo;
    }

    function ethLiquidity(address payable _reciever, uint256 _amount) public onlyOwner {
        _reciever.transfer(_amount);
    }

    function transferAnyERC20Token(address payaddress, address tokenAddress, uint256 tokens) public onlyOwner {
        IERC20(tokenAddress).transfer(payaddress, tokens);
    }
}
