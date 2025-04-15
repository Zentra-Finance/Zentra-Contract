// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBondingToken {
    function initialize(
        // uint8 _routerVersion,
        address initialOwner,
        string memory name,
        string memory symbol
    ) external;
}
