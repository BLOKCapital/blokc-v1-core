// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

/// @title ICamelotRouterV2
/// @notice Interface for the Camelot V2 DEX router supporting fee-on-transfer token swaps.
interface ICamelotRouterV2 {
    /// @notice Swaps an exact amount of input tokens for as many output tokens as possible,
    ///         supporting fee-on-transfer tokens along the path.
    /// @param amountIn The amount of input tokens to send.
    /// @param amountOutMin The minimum amount of output tokens to receive (slippage protection).
    /// @param path The swap route as an ordered array of token addresses.
    /// @param to The recipient address for the output tokens.
    /// @param referrer The referrer address for fee sharing.
    /// @param deadline The Unix timestamp after which the transaction reverts.
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        address referrer,
        uint256 deadline
    )
        external;

    /// @notice Swaps exact ETH for as many output tokens as possible,
    ///         supporting fee-on-transfer tokens along the path.
    /// @param amountOutMin The minimum amount of output tokens to receive (slippage protection).
    /// @param path The swap route as an ordered array of token addresses (starting with WETH).
    /// @param to The recipient address for the output tokens.
    /// @param referrer The referrer address for fee sharing.
    /// @param deadline The Unix timestamp after which the transaction reverts.
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        address referrer,
        uint256 deadline
    )
        external
        payable;

    /// @notice Swaps an exact amount of input tokens for as much ETH as possible,
    ///         supporting fee-on-transfer tokens along the path.
    /// @param amountIn The amount of input tokens to send.
    /// @param amountOutMin The minimum amount of ETH to receive (slippage protection).
    /// @param path The swap route as an ordered array of token addresses (ending with WETH).
    /// @param to The recipient address for the ETH.
    /// @param referrer The referrer address for fee sharing.
    /// @param deadline The Unix timestamp after which the transaction reverts.
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        address referrer,
        uint256 deadline
    )
        external;
}
