// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPoolManager {
    function registerFairPool(address pool, address token, address owner, uint8 version) external;
    function registerBondingPool(address pool, address token, address owner, uint8 version) external;

    function addPoolFactory(address factory) external;
    function addAllowedPools(address pool) external;

    // function payAmaPartner(address[] memory _partnerAddress, address _poolAddress) external payable;

    function fairPoolForToken(address token) external view returns (address);

    function isFairPoolGenerated(address pool) external view returns (bool);
    function increaseTotalValueLocked(address currency, uint256 value) external;

    function decreaseTotalValueLocked(address currency, uint256 value) external;

    function removeFairPoolForToken(address token, address pool) external;

    function recordContribution(address user, address pool) external;

    // function addTopPool(address poolAddress, address currency, uint256 raisedAmount) external;

    // function removeTopPool(address poolAddress) external;
}
