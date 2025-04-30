// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFeeManager {
    function getPrice(bytes32 deploymentKey) external view returns (uint256);
}
