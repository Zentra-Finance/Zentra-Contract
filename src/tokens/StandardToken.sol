// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IFeeManager} from "../interfaces/IFeeManager.sol";

contract StandardToken is ERC20, Ownable {
    uint8 private _decimals;
    uint256 private _totalSupply;
    address payable private _serviceFeeReceiver;
    bytes32 public constant DEPLOYMENT_KEY = keccak256("STANDARD_TOKEN");
    IFeeManager private constant FEE_MANAGER = IFeeManager(address(0));

    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint256 totalSupply_)
        payable
        ERC20(name_, symbol_)
        Ownable(msg.sender)
    {
        uint256 serviceFee = FEE_MANAGER.getPrice(DEPLOYMENT_KEY);
        require(msg.value >= serviceFee, "Service fee is not enough!");
        _decimals = decimals_;
        _totalSupply = totalSupply_;

        _mint(msg.sender, totalSupply_);

        (bool success,) = payable(address(FEE_MANAGER)).call{value: msg.value}("");
        require(success);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    receive() external payable {}
}
