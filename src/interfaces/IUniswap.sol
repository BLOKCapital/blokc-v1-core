// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/*###############################################################################

    @title Uniswap Interface
    @author BLOK Capital DAO
    @notice Minimal typed interface used by the Uniswap facet to perform swaps and TWAP lookups.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

interface IUniswap {
    /**
     * @notice Parameters for a single-hop exact-input swap.
     * @param routerAddress Address of the Uniswap V3 periphery swap router.
     * @param swapFee Fee tier (e.g. 3000 for 0.3%).
     * @param amountIn Amount of input token to swap.
     * @param amountOutMinimum Minimum acceptable output amount (slippage protection).
     * @param deadline Unix timestamp after which the swap is invalid.
     * @param tokenIn Address of the ERC20 input token.
     * @param tokenOut Address of the ERC20 output token.
     */
    struct UniswapSingleHopSwapParams {
        address routerAddress;
        uint24 swapFee;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint256 deadline;
        address tokenIn;
        address tokenOut;
    }

    /**
     * @notice Encodes a token + pool fee entry for multi-hop paths.
     * @param token Token address for this path step.
     * @param fee Fee tier (uint24) used by the following pool.
     */
    struct TokenWithFee {
        address token;
        uint24 fee;
    }

    /**
     * @notice Parameters for a multi-hop exact-input swap.
     * @param routerAddress Address of the Uniswap V3 periphery swap router.
     * @param pathWithFees Array describing the token path and fees between hops.
     * @param deadline Unix timestamp after which the swap is invalid.
     * @param amountIn Amount of input token to swap.
     * @param amountOutMin Minimum acceptable output amount.
     */
    struct UniswapMultiHopSwapParams {
        address routerAddress;
        TokenWithFee[] pathWithFees;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMin;
    }

    /**
     * @notice Parameters to fetch a TWAP sqrt price for a single hop pool.
     * @param uniswapV3Pool Address of the Uniswap V3 pool to query.
     * @param twapInterval TWAP interval in seconds. If zero, returns current slot0 price.
     */
    struct UniswapSingleHopTwapParams {
        address uniswapV3Pool;
        uint32 twapInterval;
    }

    /**
     * @notice Pool info for multi-hop TWAP aggregation.
     * @param pool Address of the Uniswap V3 pool.
     * @param inverse If true, the price from this pool is inverted when combining.
     */
    struct UniswapPoolInfo {
        address pool;
        bool inverse;
    }

    /**
     * @notice Parameters for computing a combined TWAP across multiple pools.
     * @param pools Array of PoolInfo describing which pools to combine.
     * @param twapInterval TWAP observation interval in seconds (applies to all pools).
     */
    struct UniswapMultiHopTwapParams {
        UniswapPoolInfo[] pools;
        uint32 twapInterval;
    }

    /// @notice Swap exact `amountIn` from tokenIn -> tokenOut using a single Uniswap V3 pool.
    function swapExactInputSingleHop(UniswapSingleHopSwapParams calldata params) external;

    /// @notice Swap exact `amountIn` over a multi-hop path described by `pathWithFees`.
    function swapExactInputMultiHop(UniswapMultiHopSwapParams calldata params) external;

    /// @notice Get sqrt(price) X96 for the given pool using a TWAP or current price.
    /// @return sqrtPriceX96 Q64.96 sqrt price.
    /// @return deadline Suggests a client-side expiry for any swap using this price (now + 300s).
    function getSqrtTwapX96(UniswapSingleHopTwapParams memory params)
        external
        view
        returns (uint160 sqrtPriceX96, uint256 deadline);

    /// @notice Get a combined TWAP price (as Q96) across multiple pools.
    /// @return combinedPriceX96 Aggregated price (scaled to 2**96).
    /// @return deadline Suggests a client-side expiry for any swap using this price (now + 300s).
    function getCombinedTwapX96(UniswapMultiHopTwapParams memory params)
        external
        view
        returns (uint256 combinedPriceX96, uint256 deadline);
}
