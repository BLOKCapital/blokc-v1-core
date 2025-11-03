// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title UniswapFacet
    @author BLOK Capital DAO
    @notice Facet exposing Uniswap V3 swap and TWAP functions
    @dev This facet provides integration with Uniswap V3 for token swaps and price
         oracle queries. All swap operations are protected by owner-only access control.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

// OpenZeppelin Contracts
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Uniswap V3 Contracts
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

// Local Interfaces
import { IUniswap } from "src/interfaces/IUniswap.sol";
import { IPoolRegistry } from "src/interfaces/IPoolRegistry.sol";

// Local Libraries
import { LibDiamond } from "src/diamond/libraries/LibDiamond.sol";
import { TickMath } from "src/diamond/libraries/TickMath.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when contract has insufficient token balance
error UniswapFacet_InsufficientBalance();

/// @notice Thrown when token approval fails
error UniswapFacet_ApprovalFailed();

/// @notice Thrown when pool is not registered in the PoolRegistry
error UniswapFacet_UnregisteredPool();

/// @notice Thrown when swap deadline has already passed
error UniswapFacet_SwapDeadlineHasPassed();

/// @notice Thrown when swap path is invalid
error UniswapFacet_InvalidPath();

/// @notice Thrown when swap amount is zero
error UniswapFacet_InvalidAmount();

/// @notice Thrown when multi-hop path has fewer than two pools
error UniswapFacet_PathMustHaveAtLeastTwoPools();

/// @notice Thrown when router address is zero
error UniswapFacet_InvalidRouterAddress();

/// @notice Thrown when token address is zero
error UniswapFacet_InvalidTokenAddress();

/// @notice Thrown when pool address is zero
error UniswapFacet_InvalidPoolAddress();

// ============================================================================
// UniswapFacet
// ============================================================================

/**
 * @title UniswapFacet
 * @notice Facet providing Uniswap V3 integration for swaps and price oracle queries
 * @dev This facet allows the diamond owner to:
 *      - Execute single-hop and multi-hop token swaps on Uniswap V3
 *      - Query TWAP (Time-Weighted Average Price) prices from pools
 *      - Calculate combined TWAP prices across multiple pools
 *
 *      All swap operations are protected by owner-only access control. Pools must
 *      be registered in the PoolRegistry before use. Uses SafeERC20 for secure
 *      token handling.
 */
contract UniswapFacet is IUniswap {
    using SafeERC20 for IERC20;

    // ========================================================================
    // Constants
    // ========================================================================

    /// @notice Uniswap V3 Factory address on Arbitrum One
    address internal constant UNISWAP_FACTORY_ADDRESS = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    // ========================================================================
    // Events
    // ========================================================================

    /// @notice Emitted when tokens are swapped on Uniswap
    /// @param tokenIn The input token address
    /// @param tokenOut The output token address
    /// @param amountIn The input amount
    /// @param amountOut The output amount received
    event UniswapFacetTokensSwapped(
        address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
    );

    // ========================================================================
    // Modifiers
    // ========================================================================

    /// @notice Restricts function to diamond owner only
    modifier onlyDiamondOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    // ========================================================================
    // External Functions (State-Changing)
    // ========================================================================

    /**
     * @notice Executes a single-hop exact-input swap on Uniswap V3
     * @dev Validates pool registration, handles token approvals, and executes swap.
     *      Uses SafeERC20 for secure token operations.
     * @param params Swap parameters including tokens, amounts, fees, and deadline
     */
    function swapExactInputSingleHop(UniswapSingleHopSwapParams calldata params) external override onlyDiamondOwner {
        // Input validation
        if (params.routerAddress == address(0)) {
            revert UniswapFacet_InvalidRouterAddress();
        }
        if (params.tokenIn == address(0) || params.tokenOut == address(0)) {
            revert UniswapFacet_InvalidTokenAddress();
        }
        if (params.amountIn == 0) {
            revert UniswapFacet_InvalidAmount();
        }
        if (block.timestamp > params.deadline) {
            revert UniswapFacet_SwapDeadlineHasPassed();
        }

        ISwapRouter router = ISwapRouter(params.routerAddress);
        IERC20 tokenIn = IERC20(params.tokenIn);

        // Ensure contract has sufficient balance
        if (tokenIn.balanceOf(address(this)) < params.amountIn) {
            revert UniswapFacet_InsufficientBalance();
        }

        // Get pool address from factory
        address pool =
            IUniswapV3Factory(UNISWAP_FACTORY_ADDRESS).getPool(params.tokenIn, params.tokenOut, params.swapFee);

        // Validate pool exists and is registered
        if (pool == address(0)) {
            revert UniswapFacet_InvalidPoolAddress();
        }

        address liquidityPoolRegistry = LibDiamond.liquidityPoolRegistry();
        if (!IPoolRegistry(liquidityPoolRegistry).isPoolRegistered(pool)) {
            revert UniswapFacet_UnregisteredPool();
        }

        // Safe approval pattern: use forceApprove which handles non-standard ERC20 tokens
        tokenIn.forceApprove(params.routerAddress, params.amountIn);

        // Build swap parameters
        ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter.ExactInputSingleParams({
            tokenIn: params.tokenIn,
            tokenOut: params.tokenOut,
            fee: params.swapFee,
            recipient: address(this),
            deadline: params.deadline,
            amountIn: params.amountIn,
            amountOutMinimum: params.amountOutMinimum,
            sqrtPriceLimitX96: 0
        });

        // Execute the swap
        uint256 amountOut = router.exactInputSingle(swapParams);

        emit UniswapFacetTokensSwapped(params.tokenIn, params.tokenOut, params.amountIn, amountOut);
    }

    /**
     * @notice Executes a multi-hop exact-input swap on Uniswap V3
     * @dev Validates all pools in the path are registered, handles approvals,
     *      encodes the path, and executes the swap.
     * @param params Multi-hop swap parameters including path, amounts, and deadline
     */
    function swapExactInputMultiHop(UniswapMultiHopSwapParams calldata params) external override onlyDiamondOwner {
        // Input validation
        if (params.routerAddress == address(0)) {
            revert UniswapFacet_InvalidRouterAddress();
        }
        if (params.pathWithFees.length < 2) {
            revert UniswapFacet_InvalidPath();
        }
        if (block.timestamp > params.deadline) {
            revert UniswapFacet_SwapDeadlineHasPassed();
        }
        if (params.amountIn == 0) {
            revert UniswapFacet_InvalidAmount();
        }

        ISwapRouter router = ISwapRouter(params.routerAddress);
        IERC20 tokenA = IERC20(params.pathWithFees[0].token);

        // Validate first token address
        if (params.pathWithFees[0].token == address(0)) {
            revert UniswapFacet_InvalidTokenAddress();
        }

        // Safe approval pattern: use forceApprove which handles non-standard ERC20 tokens
        tokenA.forceApprove(params.routerAddress, params.amountIn);

        address liquidityPoolRegistry = LibDiamond.liquidityPoolRegistry();

        // Validate all pools in the multi-hop path are registered
        _validateMultiHopPools(params, liquidityPoolRegistry);

        // Encode path (token, fee, token, fee, token, ...)
        bytes memory path = _encodePath(params);

        // Build swap parameters
        ISwapRouter.ExactInputParams memory swapParams = ISwapRouter.ExactInputParams({
            path: path,
            recipient: address(this),
            deadline: params.deadline,
            amountIn: params.amountIn,
            amountOutMinimum: params.amountOutMin
        });

        // Execute the swap
        uint256 amountOut = router.exactInput(swapParams);

        emit UniswapFacetTokensSwapped(
            params.pathWithFees[0].token,
            params.pathWithFees[params.pathWithFees.length - 1].token,
            params.amountIn,
            amountOut
        );
    }

    // ========================================================================
    // External Functions (View)
    // ========================================================================

    /**
     * @notice Gets the TWAP sqrt price for a single Uniswap V3 pool
     * @dev Returns either the current spot price (if twapInterval is 0) or the
     *      TWAP price over the specified interval. Price is returned in Q64.96 format.
     * @param params Parameters containing pool address and TWAP interval
     * @return sqrtPriceX96 The sqrt price in Q64.96 format
     * @return deadline Suggested deadline for swaps using this price (now + 300s)
     */
    function getSqrtTwapX96(UniswapSingleHopTwapParams memory params)
        external
        view
        override
        returns (uint160 sqrtPriceX96, uint256 deadline)
    {
        if (params.uniswapV3Pool == address(0)) {
            revert UniswapFacet_InvalidPoolAddress();
        }

        if (params.twapInterval == 0) {
            // Use the instantaneous slot0 sqrt price
            (sqrtPriceX96,,,,,,) = IUniswapV3Pool(params.uniswapV3Pool).slot0();
            deadline = block.timestamp + 300;
        } else {
            uint32[] memory secondsAgo = new uint32[](2);
            secondsAgo[0] = params.twapInterval;
            secondsAgo[1] = 0;

            // Observe two cumulative ticks and compute average tick over interval
            (int56[] memory tickCumulative,) = IUniswapV3Pool(params.uniswapV3Pool).observe(secondsAgo);

            // Average tick = (tickCumulative[1] - tickCumulative[0]) / interval
            int24 avgTick = int24(int56(tickCumulative[1] - tickCumulative[0]) / int56(int32(params.twapInterval)));

            sqrtPriceX96 = TickMath.getSqrtRatioAtTick(avgTick);
            deadline = block.timestamp + 300;
        }
    }

    /**
     * @notice Gets a combined TWAP price across multiple Uniswap V3 pools
     * @dev Multiplies prices from multiple pools together, with optional inversion.
     *      Useful for calculating prices across complex paths (e.g., ETH -> USDC -> DAI).
     * @param params Parameters containing pool array and TWAP interval
     * @return combinedPriceX96 The combined price in Q96 format
     * @return deadline Suggested deadline for swaps using this price (now + 300s)
     */
    function getCombinedTwapX96(UniswapMultiHopTwapParams memory params)
        external
        view
        override
        returns (uint256 combinedPriceX96, uint256 deadline)
    {
        if (params.pools.length < 2) {
            revert UniswapFacet_PathMustHaveAtLeastTwoPools();
        }

        combinedPriceX96 = _calculateCombinedPrice(params);
        deadline = block.timestamp + 300;
    }

    // ========================================================================
    // Internal Functions
    // ========================================================================

    /**
     * @notice Validates that all pools in a multi-hop path exist and are registered
     * @param params Multi-hop swap parameters
     * @param liquidityPoolRegistry Address of the PoolRegistry contract
     */
    function _validateMultiHopPools(
        UniswapMultiHopSwapParams calldata params,
        address liquidityPoolRegistry
    )
        internal
        view
    {
        for (uint256 i = 1; i < params.pathWithFees.length; ++i) {
            address tokenPrev = params.pathWithFees[i - 1].token;
            address tokenCurr = params.pathWithFees[i].token;
            uint24 fee = params.pathWithFees[i].fee;

            if (tokenCurr == address(0)) {
                revert UniswapFacet_InvalidTokenAddress();
            }

            // Get pool address from factory
            address pool = IUniswapV3Factory(UNISWAP_FACTORY_ADDRESS).getPool(tokenPrev, tokenCurr, fee);

            // Validate pool exists and is registered
            if (pool == address(0)) {
                revert UniswapFacet_InvalidPoolAddress();
            }
            if (!IPoolRegistry(liquidityPoolRegistry).isPoolRegistered(pool)) {
                revert UniswapFacet_UnregisteredPool();
            }
        }
    }

    /**
     * @notice Encodes a multi-hop path for Uniswap V3 router
     * @dev Encodes path as: token0, fee0, token1, fee1, token2, ...
     * @param params Multi-hop swap parameters
     * @return path Encoded path bytes
     */
    function _encodePath(UniswapMultiHopSwapParams calldata params) internal pure returns (bytes memory path) {
        path = abi.encodePacked(params.pathWithFees[0].token);
        for (uint256 i = 1; i < params.pathWithFees.length; ++i) {
            path = abi.encodePacked(path, params.pathWithFees[i - 1].fee, params.pathWithFees[i].token);
        }
    }

    /**
     * @notice Calculates combined TWAP price across multiple pools
     * @dev Multiplies prices together, handling inversions. Uses Q96 fixed-point arithmetic.
     * @param params Multi-hop TWAP parameters
     * @return combinedPriceX96 Combined price in Q96 format
     */
    function _calculateCombinedPrice(UniswapMultiHopTwapParams memory params)
        internal
        view
        returns (uint256 combinedPriceX96)
    {
        // Start with 2**96 to preserve Q96 fixed-point scaling
        combinedPriceX96 = _pow(2, 96, 1);

        for (uint256 i = 0; i < params.pools.length; i++) {
            if (params.pools[i].pool == address(0)) {
                revert UniswapFacet_InvalidPoolAddress();
            }

            uint160 sqrtPriceX96;
            address pool = params.pools[i].pool;
            bool inverse = params.pools[i].inverse;

            if (params.twapInterval == 0) {
                // Use the instantaneous slot0 sqrt price
                (sqrtPriceX96,,,,,,) = IUniswapV3Pool(pool).slot0();
            } else {
                uint32[] memory secondsAgo = new uint32[](2);
                secondsAgo[0] = params.twapInterval;
                secondsAgo[1] = 0;

                // Observe two cumulative ticks and compute average tick over interval
                (int56[] memory tickCumulative,) = IUniswapV3Pool(pool).observe(secondsAgo);
                int24 avgTick = int24((tickCumulative[1] - tickCumulative[0]) / int56(int32(params.twapInterval)));
                sqrtPriceX96 = TickMath.getSqrtRatioAtTick(avgTick);
            }

            // If inverse, use reciprocal of the sqrt price (scaled)
            if (inverse) {
                sqrtPriceX96 = uint160(2 ** 192 / uint256(sqrtPriceX96));
            }

            // Multiply and normalize back to Q96
            combinedPriceX96 = (uint256(combinedPriceX96) * uint256(sqrtPriceX96)) / _pow(2, 96, 1);
        }
    }

    /**
     * @notice Internal integer power function with rounding and overflow guards
     * @dev This helper is used for fixed-point normalization in Q96 calculations.
     *      Implemented in assembly for gas efficiency.
     * @param x Base value
     * @param n Exponent
     * @param b Base scaling (used for fixed-point rounding)
     * @return z Result of x**n in scaled representation
     */
    function _pow(uint256 x, uint256 n, uint256 b) internal pure returns (uint256 z) {
        assembly {
            switch x
            case 0 {
                switch n
                case 0 { z := b }
                // 0**0 = 1 in this context
                default { z := 0 }
            }
            default {
                switch mod(n, 2)
                case 0 { z := b }
                default { z := x }
                let half := div(b, 2)
                for { n := div(n, 2) } n { n := div(n, 2) } {
                    let xx := mul(x, x)
                    if iszero(eq(div(xx, x), x)) { revert(0, 0) } // Overflow check
                    let xxRound := add(xx, half)
                    if lt(xxRound, xx) { revert(0, 0) } // Overflow check
                    x := div(xxRound, b)
                    if mod(n, 2) {
                        let zx := mul(z, x)
                        if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0, 0) } // Overflow check
                        let zxRound := add(zx, half)
                        if lt(zxRound, zx) { revert(0, 0) } // Overflow check
                        z := div(zxRound, b)
                    }
                }
            }
        }
    }
}
