// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IFeedClient {
    function getPrice(uint64 _priceIndex) external view returns (uint256[4] memory);
}
