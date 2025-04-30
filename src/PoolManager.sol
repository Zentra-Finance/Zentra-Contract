// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IPool} from "./interfaces/IPool.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IBondingPool} from "./interfaces/IBondingPool.sol";
import {IPoolManager} from "./interfaces/IPoolManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

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
    EnumerableSet.AddressSet private allowedPools;
    EnumerableSet.AddressSet private _fairPools;

    mapping(uint8 => EnumerableSet.AddressSet) private _poolsForVersion;
    mapping(address => EnumerableSet.AddressSet) private _fairPoolsOf;
    mapping(address => EnumerableSet.AddressSet) private _bondingPoolsOf;
    mapping(address => EnumerableSet.AddressSet) private _contributedPoolsOf;
    mapping(address => address) private _fairPoolForToken;
    // TopPoolInfo[] private _topPools;

    // address public WETH;
    IUniswapV2Pair public ethUSDTPool;
    mapping(address => uint256) public totalValueLocked;
    mapping(address => uint256) public totalLiquidityRaised;
    uint256 public totalParticipants;

    EnumerableSet.AddressSet private _bondingPools; // pools for bonding

    event sender(address sender);

    receive() external payable {}

    function initialize(address initialOwner) external initializer {
       
        __Ownable_init(initialOwner);
    }

    modifier onlyAllowedFactory() {
        // emit sender(msg.sender);
        require(poolFactories.contains(msg.sender), "Not a whitelisted factory");
        _;
    }

    modifier onlyAllowedPools() {
        // emit sender(msg.sender);
        require(allowedPools.contains(msg.sender), "Not a whitelisted factory");
        _;
    }


    function updateETHUSDtPool(address pool) public onlyOwner {
        ethUSDTPool = IUniswapV2Pair(pool);
    }


    function addAllowedPools(address _pool) public onlyAllowedFactory {
        allowedPools.add(_pool);
    }

    function addPoolFactory(address factory) public onlyOwner {
        poolFactories.add(factory);
    }


    function removePoolFactory(address factory) external onlyOwner {
        poolFactories.remove(factory);
    }

    function isFairPoolGenerated(address pool) public view returns (bool) {
        return _fairPools.contains(pool);
    }

    function fairPoolForToken(address token) external view returns (address) {
        return _fairPoolForToken[token];
    }

    function registerFairPool(address pool, address token, address owner, uint8 version) external onlyAllowedFactory {
        _fairPools.add(pool);
        _poolsForVersion[version].add(pool);
        _fairPoolsOf[owner].add(pool);
        _fairPoolForToken[token] = pool;
    }

    function registerBondingPool(address pool, address token, address owner, uint8 version)
        external
        onlyAllowedFactory
    {
        _bondingPools.add(pool);
        _poolsForVersion[version].add(pool);
        _bondingPoolsOf[owner].add(pool);
        // _fairPoolForToken[token] = pool;
    }

    function increaseTotalValueLocked(address currency, uint256 value) external onlyAllowedPools {
        totalValueLocked[currency] = totalValueLocked[currency] + value;
        totalLiquidityRaised[currency] = totalLiquidityRaised[currency] + value;

        emit TvlChanged(currency, totalValueLocked[currency], totalLiquidityRaised[currency]);
    }

    function decreaseTotalValueLocked(address currency, uint256 value) external onlyAllowedPools {
        if (totalValueLocked[currency] < value) {
            totalValueLocked[currency] = 0;
        } else {
            totalValueLocked[currency] = totalValueLocked[currency] - value;
        }
        emit TvlChanged(currency, totalValueLocked[currency], totalLiquidityRaised[currency]);
    }

    function recordContribution(address user, address pool) external onlyAllowedPools {
        totalParticipants = totalParticipants + 1;
        _contributedPoolsOf[user].add(pool);
        emit ContributionUpdated(totalParticipants);
    }

    function removeFairPoolForToken(address token, address pool) external onlyAllowedPools {
        _fairPoolForToken[token] = address(0);
        emit PoolForTokenRemoved(token, pool);
    }

    function emergencyRemoveFairPoolForToken(address token, address pool) public onlyOwner {
        _fairPoolForToken[token] = address(0);
        _fairPools.remove(pool);
        emit PoolForTokenRemoved(token, pool);
    }

    function getFairPoolsOf(address owner) public view returns (address[] memory) {
        uint256 length = _fairPoolsOf[owner].length();
        address[] memory allPools = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            allPools[i] = _fairPoolsOf[owner].at(i);
        }
        return allPools;
    }
    function getBondingPoolsOf(address owner) public view returns (address[] memory) {
        uint256 length = _bondingPoolsOf[owner].length();
        address[] memory allPools = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            allPools[i] = _bondingPoolsOf[owner].at(i);
        }
        return allPools;
    }

    function getAllFairPools() public view returns (address[] memory) {
        uint256 length = _fairPools.length();
        address[] memory allPools = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            allPools[i] = _fairPools.at(i);
        }
        return allPools;
    }
    function getFairPoolsRange(uint256 from, uint56 to) public view returns (address[] memory) {
        uint256 length = _fairPools.length();
        require(from < to, "invalid range");
        require(to < length, "Out of bound");
        address[] memory allPools = new address[](to - from);
        for (uint256 i = from; i <= to; i++) {
            allPools[i] = _fairPools.at(i);
        }
        return allPools;
    }
    function getBondingPoolsRange(uint256 from, uint56 to) public view returns (address[] memory) {
        uint256 length = _bondingPools.length();
        require(from < to, "invalid range");
        require(to < length, "Out of bound");
        address[] memory allPools = new address[](to - from);
        for (uint256 i = from; i <= to; i++) {
            allPools[i] = _bondingPools.at(i);
        }
        return allPools;
    }

    function getAllBondingPools() public view returns (address[] memory) {
        uint256 length = _bondingPools.length();
        address[] memory allPools = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            allPools[i] = _bondingPools.at(i);
        }
        return allPools;
    }

    // function getFairPoolAt(uint256 index) public view returns (address) {
    //     return _fairPools.at(index);
    // }


    function getTotalNumberOfFairPools() public view returns (uint256) {
        return _fairPools.length();
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

    function getTotalNumberOfPoolsForVersion(uint8 version) public view returns (uint256) {
        return _poolsForVersion[version].length();
    }

    function getPoolAt(uint8 version, uint256 index) public view returns (address) {
        return _poolsForVersion[version].at(index);
    }

    // function getTopPool() public view returns (TopPoolInfo[] memory) {
    //     return _topPools;
    // }

    // function initializeTopPools() public onlyOwner {
    //     for (uint256 i = 0; i < 50; i++) {
    //         _topPools.push(TopPoolInfo(0, address(0)));
    //     }
    // }



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

    function getCumulativeFairPoolInfo(uint256 start, uint256 end) external view returns (CumulativeLockInfo[] memory) {
        if (end >= _fairPools.length()) {
            end = _fairPools.length() - 1;
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
            ) = IPool(_fairPools.at(i)).getPoolInfo();
            lockInfo[currentIndex] = CumulativeLockInfo(
                _fairPools.at(i),
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
