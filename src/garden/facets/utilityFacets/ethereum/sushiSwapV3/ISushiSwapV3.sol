// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

/// @title ISushiSwapV3
/// @author BLOK Capital DAO
/// @notice Interface for SushiSwap V3 integration (swaps and TWAP queries)
/// @dev Provides functions for executing token swaps on SushiSwap V3
///      and querying TWAP (Time-Weighted Average Price) prices from pools.
interface ISushiSwapV3 {
    // ========================================================================
    // Structs
    // ========================================================================

    /// @notice Parameters for a single-hop exact-input swap
    /// @param amountIn Amount of input token to swap
    /// @param amountOutMinimum Minimum acceptable output amount (slippage protection)
    /// @param deadline Unix timestamp after which the swap is invalid
    /// @param tokenIn Address of the ERC20 input token
    /// @param tokenOut Address of the ERC20 output token
    /// @param swapFee Fee tier of the pool (e.g., 500 for 0.05%)
    struct SushiSwapV3ExactInputSingleParams {
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
    struct SushiSwapV3ExactInputParams {
        TokenWithFee[] pathWithFees;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMin;
    }

    /// @notice Parameters for a single-hop exact-output swap
    /// @param amountOut Amount of output token to receive
    /// @param amountInMaximum Maximum acceptable input amount (slippage protection)
    /// @param deadline Unix timestamp after which the swap is invalid
    /// @param tokenIn Address of the ERC20 input token
    /// @param tokenOut Address of the ERC20 output token
    /// @param swapFee Fee tier of the pool (e.g., 500 for 0.05%)
    struct SushiSwapV3ExactOutputSingleParams {
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
    /// @param amountOut Amount of output token to receive
    /// @param amountInMaximum Maximum acceptable input amount (slippage protection)
    struct SushiSwapV3ExactOutputParams {
        TokenWithFee[] pathWithFees;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    /// @notice Pool info for multi-hop TWAP aggregation
    /// @param pool Address of the SushiSwap V3 pool
    /// @param inverse If true, the price from this pool is inverted when combining
    struct PoolInfo {
        address pool;
        bool inverse;
    }

    // ========================================================================
    // Functions
    // ========================================================================

    /// @notice Executes a single-hop exact-input swap on SushiSwap V3
    /// @dev Swaps an exact amount of input token for output token using a single pool.
    ///      Pool must be registered in the LiquidityPoolRegistry. All operations are restricted
    ///      to the diamond owner.
    /// @param params Swap parameters including tokens, amounts, fees, and deadline
    function sushiSwapV3ExactInputSingle(SushiSwapV3ExactInputSingleParams calldata params) external;

    /// @notice Executes a multi-hop exact-input swap on SushiSwap V3
    /// @dev Swaps an exact amount of input token across multiple pools in a path.
    ///      All pools in the path must be registered in the LiquidityPoolRegistry.
    /// @param params Multi-hop swap parameters including path, amounts, and deadline
    function sushiSwapV3ExactInput(SushiSwapV3ExactInputParams calldata params) external;

    /// @notice Executes a single-hop exact-output swap on SushiSwap V3
    /// @dev Swaps an exact amount of output token for input token using a single pool.
    ///      Pool must be registered in the LiquidityPoolRegistry. All operations are restricted
    ///      to the diamond owner.
    /// @param params Swap parameters including tokens, amounts, fees, and deadline
    function sushiSwapV3ExactOutputSingle(SushiSwapV3ExactOutputSingleParams calldata params) external;

    /// @notice Executes a multi-hop exact-output swap on SushiSwap V3
    /// @dev Swaps an exact amount of output token across multiple pools in a path.
    ///      All pools in the path must be registered in the LiquidityPoolRegistry.
    /// @param params Multi-hop swap parameters including path, amounts, and deadline
    function sushiSwapV3ExactOutput(SushiSwapV3ExactOutputParams calldata params) external;

    /// @notice Gets the TWAP sqrt price for a single SushiSwap V3 pool
    /// @dev Returns either the current spot price (if twapInterval is 0) or the
    ///      TWAP price over the specified interval. Price is returned in Q64.96 format.
    /// @param sushiSwapV3Pool Address of the SushiSwap V3 pool to query
    /// @param twapInterval TWAP observation interval in seconds (applies to all pools)
    /// @return sqrtPriceX96 The sqrt price in Q64.96 format
    /// @return deadline Suggested deadline for swaps using this price (now + 300s)
    function getSushiSqrtTwapX96(
        address sushiSwapV3Pool,
        uint32 twapInterval
    )
        external
        view
        returns (uint160 sqrtPriceX96, uint256 deadline);

    /// @notice Gets a combined TWAP price across multiple SushiSwap V3 pools
    /// @dev Multiplies prices from multiple pools together, with optional inversion.
    ///      Useful for calculating prices across complex paths (e.g., ETH -> USDC -> DAI).
    /// @param pools Array of PoolInfo describing which pools to combine
    /// @param twapInterval TWAP observation interval in seconds (applies to all pools)
    /// @return combinedPriceX96 The combined price in Q96 format
    /// @return deadline Suggested deadline for swaps using this price (now + 300s)
    function getSushiCombinedTwapX96(
        PoolInfo[] memory pools,
        uint32 twapInterval
    )
        external
        view
        returns (uint256 combinedPriceX96, uint256 deadline);

    /// @notice Quotes output amount for exact input on a specific SushiSwap V3 pool
    /// @param poolAddress Address of the V3 pool (must be registered in PoolRegistry)
    /// @param amountIn Amount of input token
    /// @param tokenIn Input token address
    /// @param tokenOut Output token address
    /// @param twapInterval TWAP interval (0 for spot price)
    /// @return amountOut Expected output amount
    function sushiSwapV3QuoteExactInputForPool(
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
