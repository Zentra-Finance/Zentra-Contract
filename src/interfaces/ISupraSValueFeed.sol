// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ISupraSValueFeed {
    function getSvalue(uint64 _pairIndex) external view returns (bytes32, bool);
    function getSvalues(uint64[] memory _pairIndexes) external view returns (bytes32[] memory, bool[] memory);
}
