// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface ISupraOraclePull {
    // Verified price data
    struct PriceData {
        // List of pairs
        uint256[] pairs;
        // List of prices
        // prices[i] is the price of pairs[i]
        uint256[] prices;
        // List of decimals
        // decimals[i] is the decimals of pairs[i]
        uint256[] decimals;
    }

    /// @notice Verified price data
    struct PriceInfo {
        // List of pairs
        uint256[] pairs;
        // List of prices
        // prices[i] is the price of pairs[i]
        uint256[] prices;
        // List of timestamp
        // timestamp[i] is the timestamp of pairs[i]
        uint256[] timestamp;
        // List of decimals
        // decimals[i] is the decimals of pairs[i]
        uint256[] decimal;
        // List of round
        // round[i] is the round of pairs[i]
        uint256[] round;
    }

    function verifyOracleProof(bytes calldata _bytesProof) external returns (PriceData memory);
    function verifyOracleProofV2(bytes calldata _bytesProof) external returns (PriceInfo memory);
}
