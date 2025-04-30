// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ISupraOraclePull} from "../interfaces/ISupraOraclePull.sol";

// Contract which can consume oracle pull data
contract OracleClient {
    // The oracle contract
    ISupraOraclePull internal oracle;

    // Event emitted when a pair price is received
    event PairPrice(uint256 pair, uint256 price, uint256 decimals);

    constructor(address supraOraclePull) {
        oracle = ISupraOraclePull(supraOraclePull);
    }

    function GetPairPrice(bytes calldata _bytesProof, uint256 pair) external returns (uint256) {
        // Verify the proof
        ISupraOraclePull.PriceData memory prices = oracle.verifyOracleProof(_bytesProof);
        // Set the price and decimals for the requested data pair
        uint256 price = 0;
        uint256 decimals = 0;
        for (uint256 i = 0; i < prices.pairs.length; i++) {
            if (prices.pairs[i] == pair) {
                price = prices.prices[i];
                decimals = prices.decimals[i];
                break;
            }
        }
        require(price != 0, "Pair not found");
        return price;
    }
}
