// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { SwapInstruction, QuoteInstruction } from "src/interfaces/ISwapInstruction.sol";

/// @title ICamelotV3
/// @author BLOK Capital DAO
/// @notice Interface for Camelot V3 integration (concentrated liquidity swaps and quotes)
interface ICamelotV3 {
    // ========================================================================
    // Structs (internal use — kept for Base contract helpers)
    // ========================================================================

    struct CamelotV3ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 limitSqrtPrice;
    }

    struct CamelotV3ExactInputParams {
        address[] path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    struct CamelotV3ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 limitSqrtPrice;
    }

    struct CamelotV3ExactOutputParams {
        address[] path;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    // ========================================================================
    // Functions
    // ========================================================================

    /// @notice Single entry point for all Camelot V3 swaps.
    ///         Handles single-hop and multi-hop, exact-input and exact-output.
    ///         No fee parameter needed — Camelot V3 uses dynamic fees.
    /// @param instruction The universal SwapInstruction (same struct across all DEX facets)
    function camelotV3Swap(SwapInstruction calldata instruction) external;

    /// @notice Gets the TWAP sqrt price for a Camelot V3 pool (spot price if twapInterval is 0)
    /// @param poolAddress Address of the Camelot V3 pool to query
    /// @param twapInterval TWAP observation interval in seconds (0 for spot price)
    /// @return sqrtPriceX96 The sqrt price in Q64.96 format
    /// @return deadline Suggested deadline for swaps using this price (now + 300s)
    function camelotV3GetSqrtTwapX96(address poolAddress, uint32 twapInterval)
        external
        view
        returns (uint160 sqrtPriceX96, uint256 deadline);

    /// @notice Single entry point for all Camelot V3 quotes.
    ///         Handles single-hop and multi-hop, exact-input and exact-output.
    ///         Uses 30s TWAP by default for manipulation resistance.
    /// @param instruction The universal QuoteInstruction (same struct across all DEX facets)
    /// @return result exactOutput=false: estimated output. exactOutput=true: estimated input needed.
    function camelotV3Quote(QuoteInstruction calldata instruction) external view returns (uint256 result);
}
