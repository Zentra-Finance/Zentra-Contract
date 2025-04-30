// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FeeManager is Ownable {
    mapping(bytes32 => uint256) private _deploymentPrices;
    mapping(bytes32 => bool) private _deploymentExists;
    bytes32[] private _deploymentKeys;

    event PriceSet(bytes32 indexed deploymentKey, uint256 price);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function setPrice(bytes32 deploymentKey, uint256 price) external onlyOwner {
        if (!_deploymentExists[deploymentKey]) {
            _deploymentKeys.push(deploymentKey);
            _deploymentExists[deploymentKey] = true;
        }

        _deploymentPrices[deploymentKey] = price;
        emit PriceSet(deploymentKey, price);
    }

    function getPrice(bytes32 deploymentKey) external view returns (uint256) {
        return _deploymentPrices[deploymentKey];
    }

    function getAllDeploymentKeys() external view returns (bytes32[] memory) {
        return _deploymentKeys;
    }

    function withdrawNative(address recipient, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "insufficient fund");
        (bool success,) = payable(recipient).call{value: amount}("");
        require(success);
    }

    function withdrawToken(address token, address recipient, uint256 amount) external onlyOwner {
        require(IERC20(token).balanceOf(address(this)) >= amount, "insufficient fund");
        IERC20(token).transfer(recipient, amount);
    }

    receive() external payable {}
}
