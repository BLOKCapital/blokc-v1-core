//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*###############################################################################

    @title ICamelotV2
    @author BLOK Capital DAO
    @notice Interface for Camelot V2 integration (swaps)
    @dev This interface provides the functionality for Camelot V2 integration (swaps)

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

interface ICamelotV2 {
    /// @notice Camelot V2 exact input single swap
    /// @param amountIn Amount of input token to swap
    /// @param amountOutMin Minimum acceptable output amount (slippage protection)
    /// @param path Array of addresses describing the path
    /// @param to Address to receive the output tokens
    /// @param referrer Address of the referrer
    /// @param deadline Unix timestamp after which the swap is invalid
    function camelotV2ExactInputSingle(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        address referrer,
        uint256 deadline
    )
        external;

    /// @notice Camelot V2 exact input swap
    /// @param amountInMax Maximum acceptable input amount (slippage protection)
    /// @param amountOutMin Minimum acceptable output amount (slippage protection)
    /// @param path Array of addresses describing the path
    /// @param to Address to receive the output tokens
    /// @param referrer Address of the referrer
    /// @param deadline Unix timestamp after which the swap is invalid
    function camelotV2ExactInput(
        uint256 amountInMax,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        address referrer,
        uint256 deadline
    )
        external;

    /// @notice Camelot V2 exact output single swap
    /// @param amountIn Amount of input token to swap
    /// @param amountOutMin Minimum acceptable output amount (slippage protection)
    /// @param path Array of addresses describing the path
    /// @param to Address to receive the input tokens
    /// @param referrer Address of the referrer
    /// @param deadline Unix timestamp after which the swap is invalid
    function camelotV2ExactOutputSingle(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        address referrer,
        uint256 deadline
    )
        external;

    /// @notice Quotes output amount for exact input on a specific Camelot V2 pool
    /// @param poolAddress Address of the V2 pair (must be registered in PoolRegistry)
    /// @param amountIn Amount of input token
    /// @param tokenIn Input token address
    /// @param tokenOut Output token address
    /// @return amountOut Expected output amount
    function camelotV2QuoteExactInputForPool(
        address poolAddress,
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    )
        external
        view
        returns (uint256 amountOut);
}
