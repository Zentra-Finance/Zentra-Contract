// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
