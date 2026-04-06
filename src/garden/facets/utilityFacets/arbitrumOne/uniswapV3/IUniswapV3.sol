// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { SwapInstruction, QuoteInstruction } from "src/interfaces/ISwapInstruction.sol";

/// @title IUniswapV3
/// @author BLOK Capital DAO
/// @notice Interface for Uniswap V3 integration (swaps and TWAP queries)
/// @dev Provides functions for executing token swaps on Uniswap V3
///      and querying TWAP (Time-Weighted Average Price) prices from pools.
interface IUniswapV3 {
    // ========================================================================
    // Structs
    // ========================================================================

    /// @notice Parameters for a single-hop exact-input swap
    /// @param amountIn Amount of input token to swap
    /// @param amountOutMinimum Minimum acceptable output amount (slippage protection)
    /// @param deadline Unix timestamp after which the swap is invalid
    /// @param tokenIn Address of the ERC20 input token
    /// @param tokenOut Address of the ERC20 output token
    struct UniswapV3ExactInputSingleParams {
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint256 deadline;
        address tokenIn;
        address tokenOut;
        uint24 swapFee;
    }

    /// @notice Encodes a token + pool fee entry for multi-hop paths
    /// @param token Token address for this path step
    /// @param fee Fee tier (uint24) used by the following pool
    struct TokenWithFee {
        address token;
        uint24 fee;
    }

    /// @notice Parameters for a multi-hop exact-input swap
    /// @param pathWithFees Array describing the token path and fees between hops
    /// @param deadline Unix timestamp after which the swap is invalid
    /// @param amountIn Amount of input token to swap
    /// @param amountOutMin Minimum acceptable output amount (slippage protection)
    struct UniswapV3ExactInputParams {
        TokenWithFee[] pathWithFees;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMin;
    }

    /// @notice Parameters for a single-hop exact-output swap
    /// @param swapFee Fee tier (e.g., 3000 for 0.3%)
    /// @param amountOut Amount of output token to swap
    /// @param amountInMaximum Maximum acceptable input amount (slippage protection)
    /// @param deadline Unix timestamp after which the swap is invalid
    /// @param tokenIn Address of the ERC20 input token
    /// @param tokenOut Address of the ERC20 output token
    struct UniswapV3ExactOutputSingleParams {
        uint256 amountOut;
        uint256 amountInMaximum;
        uint256 deadline;
        address tokenIn;
        address tokenOut;
        uint24 swapFee;
    }

    /// @notice Parameters for a multi-hop exact-output swap
    /// @param pathWithFees Array describing the token path and fees between hops
    /// @param deadline Unix timestamp after which the swap is invalid
    /// @param amountOut Amount of output token to swap
    /// @param amountInMaximum Maximum acceptable input amount (slippage protection)
    struct UniswapV3ExactOutputParams {
        TokenWithFee[] pathWithFees;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    /// @notice Pool info for multi-hop TWAP aggregation
    /// @param pool Address of the Uniswap V3 pool
    /// @param inverse If true, the price from this pool is inverted when combining
    struct PoolInfo {
        address pool;
        bool inverse;
    }

    // ========================================================================
    // Functions
    // ========================================================================

    /// @notice Single entry point for all Uniswap V3 swaps.
    ///         Derives fee tiers on-chain from pool contracts. Handles single-hop and
    ///         multi-hop, exact-input and exact-output — all from one selector.
    /// @param instruction The universal SwapInstruction (same struct across all DEX facets)
    function uniswapV3Swap(SwapInstruction calldata instruction) external;

    /// @notice Gets the TWAP sqrt price for a single Uniswap V3 pool
    /// @dev Returns either the current spot price (if twapInterval is 0) or the
    ///      TWAP price over the specified interval. Price is returned in Q64.96 format.
    /// @param uniswapV3Pool Address of the Uniswap V3 pool to query
    /// @param twapInterval TWAP observation interval in seconds (applies to all pools)
    /// @return sqrtPriceX96 The sqrt price in Q64.96 format
    /// @return deadline Suggested deadline for swaps using this price (now + 300s)
    function getSqrtTwapX96(
        address uniswapV3Pool,
        uint32 twapInterval
    )
        external
        view
        returns (uint160 sqrtPriceX96, uint256 deadline);

    /// @notice Gets a combined TWAP price across multiple Uniswap V3 pools
    /// @dev Multiplies prices from multiple pools together, with optional inversion.
    ///      Useful for calculating prices across complex paths (e.g., ETH -> USDC -> DAI).
    /// @param pools Array of PoolInfo describing which pools to combine
    /// @param twapInterval TWAP observation interval in seconds (applies to all pools)
    /// @return combinedPriceX96 The combined price in Q96 format
    /// @return deadline Suggested deadline for swaps using this price (now + 300s)
    function getCombinedTwapX96(
        PoolInfo[] memory pools,
        uint32 twapInterval
    )
        external
        view
        returns (uint256 combinedPriceX96, uint256 deadline);

    /// @notice Single entry point for all Uniswap V3 quotes.
    ///         Handles single-hop and multi-hop, exact-input and exact-output.
    ///         Uses 30s TWAP by default for manipulation resistance.
    /// @param instruction The universal QuoteInstruction (same struct across all DEX facets)
    /// @return result exactOutput=false: estimated output amount.
    ///                exactOutput=true:  estimated input amount needed.
    function uniswapV3Quote(QuoteInstruction calldata instruction) external view returns (uint256 result);
}
