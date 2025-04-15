// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPool {
    function initialize(
        address[4] memory _addrs, // [0] = token, [1] = router, [2] = governance , [3] = Authority
        uint256[16] memory _saleInfo,
        string memory _poolDetails,
        address[3] memory _linkAddress, // [0] factory ,[1] = manager
        uint8 _version,
        uint256 _contributeWithdrawFee,
        string[3] memory _otherInfo
    ) external;

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
        );
    function initializeVesting(uint256[3] memory _vestingInit) external;

    function setKycAudit(bool _kyc, bool _audit, string memory _kyclink, string memory _auditlink) external;

    function emergencyWithdrawLiquidity(address token_, address to_, uint256 amount_) external;

    function emergencyWithdraw(address payable to_, uint256 amount_) external;

    function setGovernance(address governance_) external;

    function emergencyWithdrawToken(address payaddress, address tokenAddress, uint256 tokens) external;
}
