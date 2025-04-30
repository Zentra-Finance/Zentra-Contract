// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IUniswapV2Router02} from "@uniswap/v2-periphery/interfaces/IUniswapV2Router02.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library PoolLibrary {
    using SafeERC20 for IERC20;

    function convertCurrencyToToken(uint256 amount, uint256 rate) internal pure returns (uint256) {
        return (amount * rate) / 1e18;
    }

    function addLiquidity(
        address router,
        address currency,
        address token,
        uint256 liquidityEth,
        uint256 liquidityToken,
        address pool
    ) internal returns (uint256 liquidity) {
        IERC20(token).forceApprove(router, liquidityToken);

        if (currency == address(0)) {
            (,, liquidity) = IUniswapV2Router02(router).addLiquidityETH{value: liquidityEth}(
                token, liquidityToken, 0, 0, pool, block.timestamp
            );
        } else {
            (,, liquidity) = IUniswapV2Router02(router).addLiquidity(
                token, currency, liquidityToken, liquidityEth, 0, 0, pool, block.timestamp
            );
        }
    }

    function calculateFeeAndLiquidity(
        uint256 totalRaised,
        uint256 ethFeePercent,
        uint256 tokenFeePercent,
        uint256 totalVolumePurchased,
        uint256 liquidityPercent,
        uint256 liquidityListingRate
    ) internal pure returns (uint256 ethFee, uint256 tokenFee, uint256 liquidityEth, uint256 liquidityToken) {
        ethFee = (totalRaised * ethFeePercent) / 100;
        tokenFee = (totalVolumePurchased * tokenFeePercent) / 100;
        liquidityEth = ((totalRaised - ethFee) * liquidityPercent) / 100;
        liquidityToken = (liquidityEth * liquidityListingRate) / 1e18;
    }
}
