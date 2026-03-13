// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

/// @title ICamelotV3
/// @author BLOK Capital DAO
/// @notice Interface for Camelot V3 integration (concentrated liquidity swaps)
interface ICamelotV3 {
    /// @notice Parameters for a single-hop exact-input swap
    /// @param tokenIn Address of the ERC20 input token
    /// @param tokenOut Address of the ERC20 output token
    /// @param recipient Address to receive the output tokens
    /// @param deadline Unix timestamp after which the swap is invalid
    /// @param amountIn Amount of input token to swap
    /// @param amountOutMinimum Minimum acceptable output amount (slippage protection)
    /// @param limitSqrtPrice Limit price for the swap
    struct CamelotV3ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 limitSqrtPrice;
    }

    /// @notice Executes a single-hop exact-input swap on Camelot V3
    /// @param params The parameters necessary for the swap, encoded as `CamelotV3ExactInputSingleParams`
    /// @return amountOut The amount of the received token
    function camelotV3ExactInputSingle(CamelotV3ExactInputSingleParams calldata params)
        external
        returns (uint256 amountOut);

    /// @notice Parameters for a multi-hop exact-input swap
    /// @param path Array of addresses describing the swap path
    /// @param recipient Address to receive the output tokens
    /// @param deadline Unix timestamp after which the swap is invalid
    /// @param amountIn Amount of input token to swap
    /// @param amountOutMinimum Minimum acceptable output amount (slippage protection)
    struct CamelotV3ExactInputParams {
        address[] path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another along the specified path
    /// @param params The parameters necessary for the multi-hop swap, encoded as `CamelotV3ExactInputParams`
    /// @return amountOut The amount of the received token
    function camelotV3ExactInput(CamelotV3ExactInputParams calldata params) external returns (uint256 amountOut);

    /// @notice Parameters for a single-hop exact-output swap
    /// @param tokenIn Address of the ERC20 input token
    /// @param tokenOut Address of the ERC20 output token
    /// @param recipient Address to receive the input tokens
    /// @param deadline Unix timestamp after which the swap is invalid
    /// @param amountOut Amount of output token to swap
    /// @param amountInMaximum Maximum acceptable input amount (slippage protection)
    /// @param limitSqrtPrice Limit price for the swap
    struct CamelotV3ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 limitSqrtPrice;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another token
    /// @param params The parameters necessary for the swap, encoded as `CamelotV3ExactOutputSingleParams`
    /// @return amountIn The amount of the input token
    function camelotV3ExactOutputSingle(CamelotV3ExactOutputSingleParams calldata params)
        external
        returns (uint256 amountIn);

    /// @notice Parameters for a multi-hop exact-output swap
    /// @param path Array of addresses describing the swap path
    /// @param recipient Address to receive the input tokens
    /// @param deadline Unix timestamp after which the swap is invalid
    /// @param amountOut Amount of output token to swap
    /// @param amountInMaximum Maximum acceptable input amount (slippage protection)
    struct CamelotV3ExactOutputParams {
        address[] path;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another along the specified path (reversed)
    /// @param params The parameters necessary for the multi-hop swap, encoded as `CamelotV3ExactOutputParams`
    /// @return amountIn The amount of the input token
    function camelotV3ExactOutput(CamelotV3ExactOutputParams calldata params) external returns (uint256 amountIn);

    /// @notice Gets the TWAP sqrt price for a Camelot V3 pool (spot price if twapInterval is 0)
    /// @param poolAddress Address of the Camelot V3 pool to query
    /// @param twapInterval TWAP observation interval in seconds (0 for spot price)
    /// @return sqrtPriceX96 The sqrt price in Q64.96 format
    /// @return deadline Suggested deadline for swaps using this price (now + 300s)
    function camelotV3GetSqrtTwapX96(address poolAddress, uint32 twapInterval)
        external
        view
        returns (uint160 sqrtPriceX96, uint256 deadline);

    /// @notice Quotes output amount for exact input on a specific Camelot V3 pool
    /// @param poolAddress Address of the V3 pool (must be registered in PoolRegistry)
    /// @param amountIn Amount of input token
    /// @param tokenIn Input token address
    /// @param tokenOut Output token address
    /// @param twapInterval TWAP interval (0 for spot price)
    /// @return amountOut Expected output amount
    function camelotV3QuoteExactInputForPool(
        address poolAddress,
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        uint32 twapInterval
    )
        external
        view
        returns (uint256 amountOut);
}
