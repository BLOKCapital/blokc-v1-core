// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

/// @title ICamelotRouterV3
/// @notice Interface for the Camelot V3 (Algebra) DEX router supporting exact-input and exact-output swaps.
interface ICamelotRouterV3 {
    /// @notice Parameters for a single-hop exact-input swap.
    /// @param tokenIn The address of the input token.
    /// @param tokenOut The address of the output token.
    /// @param recipient The address that receives the output tokens.
    /// @param deadline The Unix timestamp after which the transaction reverts.
    /// @param amountIn The exact amount of input tokens to send.
    /// @param amountOutMinimum The minimum output amount (slippage protection).
    /// @param limitSqrtPrice The price limit for the swap (0 for no limit).
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 limitSqrtPrice;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another token.
    /// @param params The parameters for the swap, encoded as `ExactInputSingleParams`.
    /// @return amountOut The amount of the output token received.
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    /// @notice Parameters for a multi-hop exact-input swap.
    /// @param path The encoded swap path (sequence of token addresses and fees).
    /// @param recipient The address that receives the output tokens.
    /// @param deadline The Unix timestamp after which the transaction reverts.
    /// @param amountIn The exact amount of the first input token to send.
    /// @param amountOutMinimum The minimum output amount (slippage protection).
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another along the specified path.
    /// @param params The parameters for the multi-hop swap, encoded as `ExactInputParams`.
    /// @return amountOut The amount of the output token received.
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

    /// @notice Parameters for a single-hop exact-output swap.
    /// @param tokenIn The address of the input token.
    /// @param tokenOut The address of the output token.
    /// @param recipient The address that receives the output tokens.
    /// @param deadline The Unix timestamp after which the transaction reverts.
    /// @param amountOut The exact amount of output tokens desired.
    /// @param amountInMaximum The maximum input amount (slippage protection).
    /// @param limitSqrtPrice The price limit for the swap (0 for no limit).
    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 limitSqrtPrice;
    }

    /// @notice Swaps as little as possible of one token for exactly `amountOut` of another token.
    /// @param params The parameters for the swap, encoded as `ExactOutputSingleParams`.
    /// @return amountIn The amount of the input token spent.
    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);

    /// @notice Parameters for a multi-hop exact-output swap.
    /// @param path The encoded swap path (sequence of token addresses and fees, reversed).
    /// @param recipient The address that receives the output tokens.
    /// @param deadline The Unix timestamp after which the transaction reverts.
    /// @param amountOut The exact amount of the final output token desired.
    /// @param amountInMaximum The maximum input amount (slippage protection).
    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    /// @notice Swaps as little as possible of one token for exactly `amountOut` of another along a reversed path.
    /// @param params The parameters for the multi-hop swap, encoded as `ExactOutputParams`.
    /// @return amountIn The amount of the input token spent.
    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);
}
