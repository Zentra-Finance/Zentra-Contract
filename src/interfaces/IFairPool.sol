// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
