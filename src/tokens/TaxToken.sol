// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IFeeManager} from "../interfaces/IFeeManager.sol";

contract TaxToken is ERC20, Ownable {
    using SafeERC20 for IERC20;

    uint8 private _decimals;
    uint256 private _totalSupply;

    address payable public _taxReceiver;
    uint24 private _buyFee; //percent 10^6
    uint24 private _sellFee; // percent 10^6

    address public _v2Router;

    address public _v2Pair;

    mapping(address => bool) public automatedMarketMakerPairs;
    bytes32 public constant DEPLOYMENT_KEY = keccak256("TAX_TOKEN");
    IFeeManager private constant FEE_MANAGER = IFeeManager(address(0));

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        uint24 buyFee_,
        uint24 sellFee_,
        address payable taxReceiver_,
        address v2Router_
    ) payable ERC20(name_, symbol_) Ownable(msg.sender) {
        uint256 serviceFee = FEE_MANAGER.getPrice(DEPLOYMENT_KEY);
        require(msg.value >= serviceFee, "Service fee is not enough!");
        require(buyFee_ <= 1000000, "sell fee should be less than 100%");
        require(sellFee_ <= 1000000, "buy fee should be less than 100%");
        _decimals = decimals_;
        _totalSupply = totalSupply_;
        _buyFee = buyFee_;
        _sellFee = sellFee_;
        _taxReceiver = taxReceiver_;
        _v2Router = v2Router_;
        _mint(msg.sender, totalSupply_);

        (bool success,) = payable(address(FEE_MANAGER)).call{value: msg.value}("");
        require(success);

        _v2Pair = IUniswapV2Factory(IUniswapV2Router02(_v2Router).factory()).createPair(
            address(this), IUniswapV2Router02(_v2Router).WETH()
        );
        _setAutomatedMarketMakerPair(_v2Pair, true);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function updateTaxFee(uint24 _sellTaxFee, uint24 _buyTaxFee) external onlyOwner {
        require(_sellTaxFee <= 1000000, "sell fee should be less than 100%");
        require(_buyTaxFee <= 1000000, "buy fee should be less than 100%");

        _buyFee = _buyTaxFee;
        _sellFee = _sellTaxFee;
    }

    function updateTaxReceiver(address taxReceiver_) external onlyOwner {
        require(taxReceiver_ != address(0), "marketing wallet can't be 0");
        _taxReceiver = payable(taxReceiver_);
    }

    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(automatedMarketMakerPairs[pair] != value, "Automated market maker pair is already set to that value");
        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;
    }

    function updateMainPair(address _mainRouter, address _baseTokenForMarket) external onlyOwner {
        address mainPair;
        mainPair =
            IUniswapV2Factory(IUniswapV2Router02(_mainRouter).factory()).createPair(address(this), _baseTokenForMarket);
        _setAutomatedMarketMakerPair(mainPair, true);
    }

    function _update(address from, address to, uint256 amount) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 _swapFee;
        // Buy
        if (automatedMarketMakerPairs[from]) {
            _swapFee = amount * _buyFee / 1000000;
        }
        // Sell
        else if (automatedMarketMakerPairs[to]) {
            _swapFee = amount * _sellFee / 1000000;
        }
        if (_swapFee > 0) {
            super._update(from, _taxReceiver, _swapFee);
            amount = amount - _swapFee;
        }
        super._update(from, to, amount);
    }

    function withdrawETH() external onlyOwner {
        (bool success,) = address(owner()).call{value: address(this).balance}("");
        require(success, "Failed in withdrawal");
    }

    function withdrawToken(address token) external onlyOwner {
        require(address(this) != token, "Not allowed");
        IERC20(token).safeTransfer(owner(), IERC20(token).balanceOf(address(this)));
    }

    receive() external payable {}
}
