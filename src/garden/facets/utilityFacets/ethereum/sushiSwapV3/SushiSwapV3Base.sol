// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

// OpenZeppelin Contracts
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Uniswap V3 Core (SushiSwap V3 pools implement the same interface)
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

// Local Interfaces
import { ISushiSwapV3 } from "src/garden/facets/utilityFacets/ethereum/sushiSwapV3/ISushiSwapV3.sol";
import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";

// Local Libraries
import { TickMath } from "src/garden/libraries/TickMath.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when pool is not registered in the LiquidityPoolRegistry
error SushiSwapV3Facet_UnregisteredPool();

/// @notice Thrown when swap deadline has already passed
error SushiSwapV3Facet_SwapDeadlineHasPassed();

/// @notice Thrown when swap path has fewer than two tokens
error SushiSwapV3Facet_InvalidPath();

/// @notice Thrown when multi-hop path has fewer than two pools
error SushiSwapV3Facet_PathMustHaveAtLeastTwoPools();

/// @notice Thrown when token address is zero
error SushiSwapV3Facet_InvalidTokenAddress();

/// @notice Thrown when pool address is zero
error SushiSwapV3Facet_InvalidPoolAddress();

/// @notice Thrown when the swap output is below the caller's minimum
error SushiSwapV3Facet_InsufficientOutputAmount();

/// @notice Thrown when the swap input exceeds the caller's maximum
error SushiSwapV3Facet_ExcessiveInputAmount();

/// @notice Thrown when uniswapV3SwapCallback is called by an unexpected address
error SushiSwapV3Facet_InvalidCallbackCaller();

/**
 * @title SushiSwapV3Base
 * @notice Base contract for SushiSwap V3 (clAMM) interactions on Ethereum Mainnet.
 * @dev SushiSwap V3 shares the same pool interface as Uniswap V3 but does not deploy a SwapRouter.
 *      Swaps are executed by calling pool.swap() directly, which triggers a uniswapV3SwapCallback
 *      on the caller (this contract) to pull tokens into the pool mid-swap.
 *      TWAP price queries work identically to Uniswap V3 since the pool interface is the same.
 */
abstract contract SushiSwapV3Base {
    using SafeERC20 for IERC20;

    // ========================================================================
    // Constants
    // ========================================================================

    /// @notice SushiSwap V3 Factory address on Ethereum Mainnet
    address internal constant SUSHISWAP_FACTORY_ADDRESS = 0xbACEB8eC6b9355Dfc0269C18bac9d6E2Bdc29C4F;
    /// @notice Pool Registry address on Ethereum Mainnet
    address internal constant POOL_REGISTRY_ADDRESS = 0xDe6338E4dd7B0A2076e8CE63cC0443dC6cE7f0B6;

    /// @dev Lower bound for sqrtPriceLimitX96 — passed when direction is zeroForOne to mean no price limit
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    /// @dev Upper bound for sqrtPriceLimitX96 — passed when direction is oneForZero to mean no price limit
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    // ========================================================================
    // Events
    // ========================================================================

    /// @notice Emitted when tokens are swapped on SushiSwap V3
    /// @param tokenIn The input token address
    /// @param tokenOut The output token address
    /// @param amountIn The input amount
    /// @param amountOut The output amount received
    event SushiSwapV3FacetTokensSwapped(
        address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
    );

    // ========================================================================
    // Internal Swap Functions
    // ========================================================================

    /// @notice Executes a single-hop exact-input swap via pool.swap()
    /// @dev pool.swap() triggers uniswapV3SwapCallback on the diamond (implemented in SushiSwapV3Facet)
    ///      which calls _handleSushiSwapCallback here to transfer the owed tokens to the pool.
    function _sushiSwapV3ExactInputSingle(ISushiSwapV3.SushiSwapV3ExactInputSingleParams memory params)
        internal
        returns (uint256 amountOut)
    {
        if (block.timestamp > params.deadline) revert SushiSwapV3Facet_SwapDeadlineHasPassed();

        _validatePool(params.tokenIn, params.tokenOut, params.swapFee);

        address pool = IUniswapV3Factory(SUSHISWAP_FACTORY_ADDRESS).getPool(params.tokenIn, params.tokenOut, params.swapFee);
        bool zeroForOne = params.tokenIn == IUniswapV3Pool(pool).token0();

        (int256 amount0, int256 amount1) = IUniswapV3Pool(pool).swap(
            address(this),
            zeroForOne,
            int256(params.amountIn),
            zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1,
            abi.encode(params.tokenIn, pool)
        );

        amountOut = uint256(-(zeroForOne ? amount1 : amount0));
        if (amountOut < params.amountOutMinimum) revert SushiSwapV3Facet_InsufficientOutputAmount();

        emit SushiSwapV3FacetTokensSwapped(params.tokenIn, params.tokenOut, params.amountIn, amountOut);
    }

    /// @notice Executes a multi-hop exact-input swap by chaining pool.swap() calls
    /// @dev Each hop's output lands in address(this) and is paid in the next hop's callback.
    ///      pathWithFees[i].fee is the fee tier for the pool between token[i] and token[i+1].
    function _sushiSwapV3ExactInput(ISushiSwapV3.SushiSwapV3ExactInputParams memory params) internal {
        if (params.pathWithFees.length < 2) revert SushiSwapV3Facet_InvalidPath();
        if (block.timestamp > params.deadline) revert SushiSwapV3Facet_SwapDeadlineHasPassed();

        uint256 amountIn = params.amountIn;

        for (uint256 i = 0; i < params.pathWithFees.length - 1; i++) {
            address tokenIn = params.pathWithFees[i].token;
            address tokenOut = params.pathWithFees[i + 1].token;
            uint24 fee = params.pathWithFees[i].fee;

            _validatePool(tokenIn, tokenOut, fee);

            address pool = IUniswapV3Factory(SUSHISWAP_FACTORY_ADDRESS).getPool(tokenIn, tokenOut, fee);
            bool zeroForOne = tokenIn == IUniswapV3Pool(pool).token0();

            (int256 amount0, int256 amount1) = IUniswapV3Pool(pool).swap(
                address(this),
                zeroForOne,
                int256(amountIn),
                zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1,
                abi.encode(tokenIn, pool)
            );

            // Output of this hop becomes input for the next
            amountIn = uint256(-(zeroForOne ? amount1 : amount0));
        }

        if (amountIn < params.amountOutMin) revert SushiSwapV3Facet_InsufficientOutputAmount();

        emit SushiSwapV3FacetTokensSwapped(
            params.pathWithFees[0].token,
            params.pathWithFees[params.pathWithFees.length - 1].token,
            params.amountIn,
            amountIn
        );
    }

    /// @notice Executes a single-hop exact-output swap via pool.swap() with negative amountSpecified
    /// @dev Negative amountSpecified signals to the pool that we want an exact output amount.
    ///      The pool pulls however much input it needs via the callback, bounded by amountInMaximum.
    function _sushiSwapV3ExactOutputSingle(ISushiSwapV3.SushiSwapV3ExactOutputSingleParams memory params) internal {
        if (block.timestamp > params.deadline) revert SushiSwapV3Facet_SwapDeadlineHasPassed();

        _validatePool(params.tokenIn, params.tokenOut, params.swapFee);

        address pool = IUniswapV3Factory(SUSHISWAP_FACTORY_ADDRESS).getPool(params.tokenIn, params.tokenOut, params.swapFee);
        bool zeroForOne = params.tokenIn == IUniswapV3Pool(pool).token0();

        (int256 amount0, int256 amount1) = IUniswapV3Pool(pool).swap(
            address(this),
            zeroForOne,
            -int256(params.amountOut),
            zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1,
            abi.encode(params.tokenIn, pool)
        );

        uint256 amountIn = uint256(zeroForOne ? amount0 : amount1);
        if (amountIn > params.amountInMaximum) revert SushiSwapV3Facet_ExcessiveInputAmount();

        emit SushiSwapV3FacetTokensSwapped(params.tokenIn, params.tokenOut, amountIn, params.amountOut);
    }

    // ========================================================================
    // Internal TWAP Functions
    // ========================================================================

    /// @notice Gets the TWAP sqrt price for a single SushiSwap V3 pool
    /// @param sushiSwapV3Pool Address of the SushiSwap V3 pool to query
    /// @param twapInterval TWAP observation interval in seconds (0 = spot price)
    /// @return sqrtPriceX96 The sqrt price in Q64.96 format
    /// @return deadline Suggested deadline for swaps using this price (now + 300s)
    function _getSushiSqrtTwapX96(
        address sushiSwapV3Pool,
        uint32 twapInterval
    )
        internal
        view
        returns (uint160 sqrtPriceX96, uint256 deadline)
    {
        if (sushiSwapV3Pool == address(0)) revert SushiSwapV3Facet_InvalidPoolAddress();

        if (twapInterval == 0) {
            (sqrtPriceX96,,,,,,) = IUniswapV3Pool(sushiSwapV3Pool).slot0();
            deadline = block.timestamp + 300;
        } else {
            uint32[] memory secondsAgo = new uint32[](2);
            secondsAgo[0] = twapInterval;
            secondsAgo[1] = 0;

            (int56[] memory tickCumulative,) = IUniswapV3Pool(sushiSwapV3Pool).observe(secondsAgo);
            int24 avgTick = int24(int56(tickCumulative[1] - tickCumulative[0]) / int56(int32(twapInterval)));

            sqrtPriceX96 = TickMath.getSqrtRatioAtTick(avgTick);
            deadline = block.timestamp + 300;
        }
    }

    /// @notice Gets a combined TWAP price across multiple SushiSwap V3 pools
    /// @param pools Array of PoolInfo describing which pools to combine
    /// @param twapInterval TWAP observation interval in seconds (0 = spot price)
    /// @return combinedPriceX96 The combined price in Q96 format
    /// @return deadline Suggested deadline for swaps using this price (now + 300s)
    function _getSushiCombinedTwapX96(
        ISushiSwapV3.PoolInfo[] memory pools,
        uint32 twapInterval
    )
        internal
        view
        returns (uint256 combinedPriceX96, uint256 deadline)
    {
        if (pools.length < 2) revert SushiSwapV3Facet_PathMustHaveAtLeastTwoPools();

        combinedPriceX96 = _pow(2, 96, 1);

        for (uint256 i = 0; i < pools.length; i++) {
            if (pools[i].pool == address(0)) revert SushiSwapV3Facet_InvalidPoolAddress();

            uint160 sqrtPriceX96;

            if (twapInterval == 0) {
                (sqrtPriceX96,,,,,,) = IUniswapV3Pool(pools[i].pool).slot0();
            } else {
                uint32[] memory secondsAgo = new uint32[](2);
                secondsAgo[0] = twapInterval;
                secondsAgo[1] = 0;

                (int56[] memory tickCumulative,) = IUniswapV3Pool(pools[i].pool).observe(secondsAgo);
                int24 avgTick = int24((tickCumulative[1] - tickCumulative[0]) / int56(int32(twapInterval)));
                sqrtPriceX96 = TickMath.getSqrtRatioAtTick(avgTick);
            }

            if (pools[i].inverse) {
                sqrtPriceX96 = uint160(2 ** 192 / uint256(sqrtPriceX96));
            }

            combinedPriceX96 = (uint256(combinedPriceX96) * uint256(sqrtPriceX96)) / _pow(2, 96, 1);
        }

        deadline = block.timestamp + 300;
    }

    /// @notice Quotes output amount for exact input on a specific SushiSwap V3 pool using TWAP
    function _sushiSwapV3QuoteExactInputForPool(
        address poolAddress,
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        uint32 twapInterval
    )
        internal
        view
        returns (uint256 amountOut)
    {
        if (poolAddress == address(0)) revert SushiSwapV3Facet_InvalidPoolAddress();
        if (!ILiquidityPoolRegistry(POOL_REGISTRY_ADDRESS).isPoolRegistered(poolAddress)) {
            revert SushiSwapV3Facet_UnregisteredPool();
        }

        (uint160 sqrtPriceX96,) = _getSushiSqrtTwapX96(poolAddress, twapInterval);
        address token0 = IUniswapV3Pool(poolAddress).token0();
        address token1 = IUniswapV3Pool(poolAddress).token1();

        if (tokenIn == token0 && tokenOut == token1) {
            uint256 price = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) >> 192;
            return (amountIn * price) >> 96;
        }
        if (tokenIn == token1 && tokenOut == token0) {
            uint256 price = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) >> 192;
            return amountIn / price;
        }
        revert SushiSwapV3Facet_InvalidPath();
    }

    // ========================================================================
    // Callback Handler
    // ========================================================================

    /// @notice Handles the token pull triggered by a SushiSwap V3 pool during pool.swap()
    /// @dev Must NOT have nonReentrant — called from inside an already-executing swap function.
    ///      Secured by verifying msg.sender matches the pool encoded in callbackData and that
    ///      the pool is registered in the LiquidityPoolRegistry.
    /// @param amount0Delta Token0 owed to the pool (positive = we pay, negative = we receive)
    /// @param amount1Delta Token1 owed to the pool (positive = we pay, negative = we receive)
    /// @param data ABI-encoded (address tokenIn, address pool)
    function _handleSushiSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) internal {
        (address tokenIn, address pool) = abi.decode(data, (address, address));

        if (msg.sender != pool) revert SushiSwapV3Facet_InvalidCallbackCaller();
        if (!ILiquidityPoolRegistry(POOL_REGISTRY_ADDRESS).isPoolRegistered(pool)) {
            revert SushiSwapV3Facet_InvalidCallbackCaller();
        }

        uint256 amountOwed = amount0Delta > 0 ? uint256(amount0Delta) : uint256(amount1Delta);
        IERC20(tokenIn).safeTransfer(pool, amountOwed);
    }

    // ========================================================================
    // Pool Validation
    // ========================================================================

    /// @notice Checks that a pool exists in the SushiSwap V3 factory and is registered
    function _validatePool(address tokenIn, address tokenOut, uint24 swapFee) internal view {
        address pool = IUniswapV3Factory(SUSHISWAP_FACTORY_ADDRESS).getPool(tokenIn, tokenOut, swapFee);

        if (pool == address(0) || !ILiquidityPoolRegistry(POOL_REGISTRY_ADDRESS).isPoolRegistered(pool)) {
            revert SushiSwapV3Facet_UnregisteredPool();
        }
    }

    // ========================================================================
    // Math Helpers
    // ========================================================================

    /// @notice Assembly-optimized integer power with overflow guards (used for Q96 normalization)
    function _pow(uint256 x, uint256 n, uint256 b) internal pure returns (uint256 z) {
        assembly {
            switch x
            case 0 {
                switch n
                case 0 { z := b }
                default { z := 0 }
            }
            default {
                switch mod(n, 2)
                case 0 { z := b }
                default { z := x }
                let half := div(b, 2)
                for { n := div(n, 2) } n { n := div(n, 2) } {
                    let xx := mul(x, x)
                    if iszero(eq(div(xx, x), x)) { revert(0, 0) }
                    let xxRound := add(xx, half)
                    if lt(xxRound, xx) { revert(0, 0) }
                    x := div(xxRound, b)
                    if mod(n, 2) {
                        let zx := mul(z, x)
                        if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0, 0) }
                        let zxRound := add(zx, half)
                        if lt(zxRound, zx) { revert(0, 0) }
                        z := div(zxRound, b)
                    }
                }
            }
        }
    }
}
