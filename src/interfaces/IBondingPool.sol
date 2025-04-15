// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBondingPool {
    function initialize(
        address[4] memory _addrs,
        uint256[2] memory _feeSettings,
        uint256[4] memory _buySellFeeSettings, //[2] = marketcap settings [3] = target eth to collect on pool ()
        string memory _poolDetails,
        address[3] memory _linkAddress,
        uint8 _version
    ) external;
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
            uint256 tokenPrice,
            uint256 tokenTotalSupply
        );
}
