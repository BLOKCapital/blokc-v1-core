// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";
import { TickMath } from "src/garden/libraries/TickMath.sol";

/// @title UniswapV3QuoteRouter
/// @notice Standalone spot-price quoter for Uniswap V3 compatible pools.
///         Uses the pool's slot0 sqrtPriceX96 (or TWAP if twapInterval > 0) to
///         compute an approximate amountOut without executing a swap.
///
///         Implements `uniswapV3QuoteExactInputForPool` with the same 5-parameter
///         signature as UniswapV3Facet so it can be used directly as `dexFacetAddress`
///         in the optimal-path engine config without deploying a full Diamond.
///
///         The pool registry address is set at construction, making this contract
///         chain-agnostic unlike the hardcoded facet implementations.
contract UniswapV3QuoteRouter {
    // =========================================================================
    // Immutables
    // =========================================================================

    /// @notice LiquidityPoolRegistry used to verify pool registrations
    address public immutable poolRegistry;

    // =========================================================================
    // Errors
    // =========================================================================

    error QuoteRouter_InvalidPool();
    error QuoteRouter_UnregisteredPool();
    error QuoteRouter_InvalidPath();

    // =========================================================================
    // Constructor
    // =========================================================================

    constructor(address _poolRegistry) {
        poolRegistry = _poolRegistry;
    }

    // =========================================================================
    // Quote
    // =========================================================================

    /// @notice Quotes the output amount for an exact-input swap on a single V3 pool
    /// @dev Uses slot0 sqrtPriceX96 for spot price (twapInterval == 0) or the TWAP
    ///      tick otherwise. Matches the 5-parameter signature expected by the engine.
    /// @param poolAddress  The Uniswap V3 pool to quote from
    /// @param amountIn     Amount of tokenIn (in raw token units)
    /// @param tokenIn      Input token address
    /// @param tokenOut     Output token address
    /// @param twapInterval TWAP interval in seconds; 0 = use instantaneous slot0 price
    /// @return amountOut   Estimated output amount (spot price, no slippage model)
    function uniswapV3QuoteExactInputForPool(
        address poolAddress,
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        uint32 twapInterval
    )
        external
        view
        returns (uint256 amountOut)
    {
        if (poolAddress == address(0)) revert QuoteRouter_InvalidPool();
        if (!ILiquidityPoolRegistry(poolRegistry).isPoolRegistered(poolAddress)) {
            revert QuoteRouter_UnregisteredPool();
        }

        uint160 sqrtPriceX96 = _getSqrtPrice(poolAddress, twapInterval);
        address token0 = IUniswapV3Pool(poolAddress).token0();
        address token1 = IUniswapV3Pool(poolAddress).token1();

        // zeroForOne: tokenIn = token0, tokenOut = token1
        // amountOut = amountIn * (sqrtP / 2^96)^2
        if (tokenIn == token0 && tokenOut == token1) {
            uint256 step = (amountIn * uint256(sqrtPriceX96)) >> 96;
            return (step * uint256(sqrtPriceX96)) >> 96;
        }

        // oneForZero: tokenIn = token1, tokenOut = token0
        // amountOut = amountIn / (sqrtP / 2^96)^2
        if (tokenIn == token1 && tokenOut == token0) {
            uint256 step = (amountIn << 96) / uint256(sqrtPriceX96);
            return (step << 96) / uint256(sqrtPriceX96);
        }

        revert QuoteRouter_InvalidPath();
    }

    // =========================================================================
    // Internal helpers
    // =========================================================================

    function _getSqrtPrice(address pool, uint32 twapInterval) internal view returns (uint160 sqrtPriceX96) {
        if (twapInterval == 0) {
            (sqrtPriceX96,,,,,,) = IUniswapV3Pool(pool).slot0();
        } else {
            uint32[] memory secondsAgo = new uint32[](2);
            secondsAgo[0] = twapInterval;
            secondsAgo[1] = 0;
            (int56[] memory tickCumulatives,) = IUniswapV3Pool(pool).observe(secondsAgo);
            int24 avgTick =
                int24((tickCumulatives[1] - tickCumulatives[0]) / int56(int32(twapInterval)));
            sqrtPriceX96 = TickMath.getSqrtRatioAtTick(avgTick);
        }
    }
}
