// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { SwapInstruction, QuoteInstruction } from "src/interfaces/ISwapInstruction.sol";

/// @title IUniswapV2
/// @author BLOK Capital DAO
/// @notice Interface for Uniswap V2 swap and quote functions within the Garden diamond
/// @dev Provides functions for executing token swaps on Uniswap V2
///      and querying quote/amount calculations
interface IUniswapV2 {
    // ========================================================================
    // Structs
    // ========================================================================

    /// @notice Parameters for exact-input token-to-token swap
    /// @param amountIn Amount of input token to swap
    /// @param amountOutMin Minimum acceptable output amount (slippage protection)
    /// @param path Array of token addresses representing the swap path
    /// @param to Recipient address for the output tokens
    /// @param deadline Unix timestamp after which the swap is invalid
    struct UniswapV2SwapExactTokensForTokensParams {
        uint256 amountIn;
        uint256 amountOutMin;
        address[] path;
        address to;
        uint256 deadline;
    }

    /// @notice Parameters for exact-output token-to-token swap
    /// @param amountOut Amount of output token desired
    /// @param amountInMax Maximum acceptable input amount (slippage protection)
    /// @param path Array of token addresses representing the swap path
    /// @param to Recipient address for the output tokens
    /// @param deadline Unix timestamp after which the swap is invalid
    struct UniswapV2SwapTokensForExactTokensParams {
        uint256 amountOut;
        uint256 amountInMax;
        address[] path;
        address to;
        uint256 deadline;
    }

    // ========================================================================
    // Functions
    // ========================================================================

    /// @notice Single entry point for all Uniswap V2 swaps.
    ///         Handles single-hop and multi-hop, exact-input and exact-output — all from one selector.
    /// @param instruction The universal SwapInstruction (same struct across all DEX facets)
    function uniswapV2Swap(SwapInstruction calldata instruction) external;

    /// @notice Single entry point for all Uniswap V2 quotes.
    ///         Handles single-hop and multi-hop, exact-input and exact-output.
    ///         Uses router's getAmountsOut / getAmountsIn for price estimation.
    /// @param instruction The universal QuoteInstruction (same struct across all DEX facets)
    /// @return result exactOutput=false: estimated output amount.
    ///                exactOutput=true:  estimated input amount needed.
    function uniswapV2Quote(QuoteInstruction calldata instruction) external view returns (uint256 result);

    // ========================================================================
    // View Functions
    // ========================================================================

    /// @notice Given an input amount and reserves, returns the maximum output amount
    /// @param amountIn Amount of input token
    /// @param reserveIn Reserve of input token in the pair
    /// @param reserveOut Reserve of output token in the pair
    /// @return amountOut Maximum output amount
    function uniswapV2GetAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    )
        external
        pure
        returns (uint256 amountOut);

    /// @notice Given an output amount and reserves, returns a required input amount
    /// @param amountOut Amount of output token
    /// @param reserveIn Reserve of input token in the pair
    /// @param reserveOut Reserve of output token in the pair
    /// @return amountIn Required input amount
    function uniswapV2GetAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    )
        external
        pure
        returns (uint256 amountIn);

    /// @notice Returns the amount of output tokens for a given input amount along a path
    /// @param amountIn Amount of input token
    /// @param path Array of token addresses representing the swap path
    /// @return amounts Array of output amounts for each step in the path
    function uniswapV2GetAmountsOut(
        uint256 amountIn,
        address[] calldata path
    )
        external
        view
        returns (uint256[] memory amounts);

    /// @notice Returns the amount of input tokens required for a given output amount along a path
    /// @param amountOut Amount of output token
    /// @param path Array of token addresses representing the swap path
    /// @return amounts Array of input amounts for each step in the path
    function uniswapV2GetAmountsIn(
        uint256 amountOut,
        address[] calldata path
    )
        external
        view
        returns (uint256[] memory amounts);
}
