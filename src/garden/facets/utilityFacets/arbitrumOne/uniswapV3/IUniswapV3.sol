// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    @title IUniswapV3
    @author BLOK Capital DAO
    @notice Interface for Uniswap V3 integration (swaps and TWAP queries)
    @dev This interface provides functions for executing token swaps on Uniswap V3
         and querying TWAP (Time-Weighted Average Price) prices from pools.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

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
        uint8 swapFee;
    }

    /// @notice Encodes a token + pool fee entry for multi-hop paths
    /// @param token Token address for this path step
    /// @param fee Fee tier (uint24) used by the following pool
    struct TokenWithFee {
        address token;
        uint8 fee;
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
        uint8 swapFee;
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

    /// @notice Executes a single-hop exact-input swap on Uniswap V3
    /// @dev Swaps an exact amount of input token for output token using a single pool.
    ///      Pool must be registered in the LiquidityPoolRegistry. All operations are restricted
    ///      to the diamond owner.
    /// @param params Swap parameters including tokens, amounts, fees, and deadline
    function uniswapV3ExactInputSingle(UniswapV3ExactInputSingleParams calldata params) external;

    /// @notice Executes a multi-hop exact-input swap on Uniswap V3
    /// @dev Swaps an exact amount of input token across multiple pools in a path.
    ///      All pools in the path must be registered in the LiquidityPoolRegistry.
    /// @param params Multi-hop swap parameters including path, amounts, and deadline
    function uniswapV3ExactInput(UniswapV3ExactInputParams calldata params) external;

    /// @notice Executes a single-hop exact-output swap on Uniswap V3
    /// @dev Swaps an exact amount of output token for input token using a single pool.
    ///      Pool must be registered in the LiquidityPoolRegistry. All operations are restricted
    ///      to the diamond owner.
    /// @param params Swap parameters including tokens, amounts, fees, and deadline
    function uniswapV3ExactOutputSingle(UniswapV3ExactOutputSingleParams calldata params) external;

    /// @notice Executes a multi-hop exact-output swap on Uniswap V3
    /// @dev Swaps an exact amount of output token across multiple pools in a path.
    ///      All pools in the path must be registered in the LiquidityPoolRegistry.
    /// @param params Multi-hop swap parameters including path, amounts, and deadline
    function uniswapV3ExactOutput(UniswapV3ExactOutputParams calldata params) external;

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
}
