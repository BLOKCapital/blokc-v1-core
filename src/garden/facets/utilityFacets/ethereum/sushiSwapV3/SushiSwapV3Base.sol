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
import { SwapInstruction, QuoteInstruction } from "src/interfaces/ISwapInstruction.sol";

// Local Libraries
import { TickMath } from "src/garden/libraries/TickMath.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when contract has insufficient token balance
error SushiSwapV3Facet_InsufficientBalance();

/// @notice Thrown when pool is not registered in the LiquidityPoolRegistry
error SushiSwapV3Facet_UnregisteredPool();

/// @notice Thrown when swap deadline has already passed
error SushiSwapV3Facet_SwapDeadlineHasPassed();

/// @notice Thrown when swap path is invalid
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

/// @notice Thrown when multi-hop exact-output is attempted (not supported without a SwapRouter)
error SushiSwapV3Facet_MultiHopExactOutputNotSupported();

/**
 * @title SushiSwapV3Base
 * @notice Base contract for SushiSwap V3 (clAMM) interactions on Ethereum Mainnet, providing shared logic for swaps
 * and price queries. This abstract contract is inherited by SushiSwapV3Facet which implements the external functions.
 * It includes internal functions for executing exact input/output swaps (single and multi-hop) and fetching TWAP
 * prices. SushiSwap V3 shares the same pool interface as Uniswap V3 but does not deploy a SwapRouter — swaps are
 * executed by calling pool.swap() directly, which triggers a uniswapV3SwapCallback to pull tokens mid-swap.
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

    /// @dev Lower bound for sqrtPriceLimitX96 — passed when zeroForOne to mean no price limit
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    /// @dev Upper bound for sqrtPriceLimitX96 — passed when oneForZero to mean no price limit
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

    /// @notice SushiSwap V3 base exact input single swap
    /// @param params Single-hop swap parameters including tokens, amounts, fees, and deadline
    /// @param pool The SushiSwap V3 pool to swap through
    /// @dev Calls pool.swap() directly; the pool triggers uniswapV3SwapCallback to pull tokens.
    function _sushiSwapV3ExactInputSingle(
        ISushiSwapV3.SushiSwapV3ExactInputSingleParams memory params,
        address pool
    )
        internal
        returns (uint256 amountOut)
    {
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

    /// @notice SushiSwap V3 base exact input swap (multi-hop)
    /// @param params Multi-hop swap parameters including path, amounts, and deadline
    /// @param pools Ordered pool addresses, one per hop (pools.length == pathWithFees.length - 1)
    /// @dev Chains pool.swap() calls; each hop's output becomes the next hop's input.
    ///      The callback for each hop transfers the owed tokens directly to the pool.
    function _sushiSwapV3ExactInput(
        ISushiSwapV3.SushiSwapV3ExactInputParams memory params,
        address[] calldata pools
    )
        internal
    {
        if (params.pathWithFees.length < 2) {
            revert SushiSwapV3Facet_InvalidPath();
        }

        uint256 amountIn = params.amountIn;

        for (uint256 i = 0; i < pools.length; i++) {
            address tokenIn = params.pathWithFees[i].token;
            address tokenOut = params.pathWithFees[i + 1].token;
            address pool = pools[i];

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

    /// @notice SushiSwap V3 base exact output single swap
    /// @param params Single-hop swap parameters including tokens, amounts, fees, and deadline
    /// @param pool The SushiSwap V3 pool to swap through
    /// @dev Passes negative amountSpecified to signal exact-output to the pool.
    ///      The pool pulls however much input it needs via the callback, bounded by amountInMaximum.
    function _sushiSwapV3ExactOutputSingle(
        ISushiSwapV3.SushiSwapV3ExactOutputSingleParams memory params,
        address pool
    )
        internal
    {
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

    /// @notice Multi-hop exact-output is not supported — SushiSwap V3 has no SwapRouter to
    ///         handle reverse-chained callbacks. Always reverts.
    function _sushiSwapV3ExactOutput(ISushiSwapV3.SushiSwapV3ExactOutputParams memory) internal pure {
        revert SushiSwapV3Facet_MultiHopExactOutputNotSupported();
    }

    // ========================================================================
    // Swap Dispatcher
    // ========================================================================

    /// @notice Standardised swap dispatcher for the rebalance flow.
    ///         Reads fee tiers from pool contracts on-chain, then delegates to the
    ///         appropriate internal helper (single/multi, exactIn/exactOut).
    function _sushiSwapV3Swap(SwapInstruction calldata inst) internal {
        uint256 hops = inst.pools.length;
        if (hops == 0 || inst.tokens.length != hops + 1) revert SushiSwapV3Facet_InvalidPath();

        // Validate all pools upfront: registered in PoolRegistry + canonical in SushiSwap factory
        _validateSwapPools(inst);

        if (hops == 1) {
            uint24 fee = IUniswapV3Pool(inst.pools[0]).fee();

            if (!inst.exactOutput) {
                _sushiSwapV3ExactInputSingle(
                    ISushiSwapV3.SushiSwapV3ExactInputSingleParams({
                        amountIn: inst.amountIn,
                        amountOutMinimum: inst.amountOut,
                        deadline: block.timestamp,
                        tokenIn: inst.tokens[0],
                        tokenOut: inst.tokens[1],
                        swapFee: fee
                    }),
                    inst.pools[0]
                );
            } else {
                _sushiSwapV3ExactOutputSingle(
                    ISushiSwapV3.SushiSwapV3ExactOutputSingleParams({
                        amountOut: inst.amountOut,
                        amountInMaximum: inst.amountIn,
                        deadline: block.timestamp,
                        tokenIn: inst.tokens[0],
                        tokenOut: inst.tokens[1],
                        swapFee: fee
                    }),
                    inst.pools[0]
                );
            }
        } else {
            ISushiSwapV3.TokenWithFee[] memory pathWithFees = new ISushiSwapV3.TokenWithFee[](inst.tokens.length);
            for (uint256 i; i < inst.tokens.length; i++) {
                uint24 fee = i < hops ? IUniswapV3Pool(inst.pools[i]).fee() : 0;
                pathWithFees[i] = ISushiSwapV3.TokenWithFee({ token: inst.tokens[i], fee: fee });
            }

            if (!inst.exactOutput) {
                _sushiSwapV3ExactInput(
                    ISushiSwapV3.SushiSwapV3ExactInputParams({
                        pathWithFees: pathWithFees,
                        deadline: block.timestamp,
                        amountIn: inst.amountIn,
                        amountOutMin: inst.amountOut
                    }),
                    inst.pools
                );
            } else {
                _sushiSwapV3ExactOutput(
                    ISushiSwapV3.SushiSwapV3ExactOutputParams({
                        pathWithFees: pathWithFees,
                        deadline: block.timestamp,
                        amountOut: inst.amountOut,
                        amountInMaximum: inst.amountIn
                    })
                );
            }
        }
    }

    // ========================================================================
    // Quote Dispatcher
    // ========================================================================

    /// @notice Unified quote dispatcher. Chains quotes through each pool in the path.
    ///         Uses 30s TWAP by default for manipulation resistance.
    function _sushiSwapV3Quote(QuoteInstruction calldata inst) internal view returns (uint256 result) {
        uint256 hops = inst.pools.length;
        if (hops == 0 || inst.tokens.length != hops + 1) revert SushiSwapV3Facet_InvalidPath();

        uint32 twapInterval = 30;

        if (!inst.exactOutput) {
            result = inst.amount;
            for (uint256 i; i < hops; i++) {
                result = _quotePool(inst.pools[i], result, inst.tokens[i], inst.tokens[i + 1], twapInterval);
            }
        } else {
            result = inst.amount;
            for (uint256 i = hops; i > 0; i--) {
                result =
                    _reverseQuotePool(inst.pools[i - 1], result, inst.tokens[i - 1], inst.tokens[i], twapInterval);
            }
        }
    }

    // ========================================================================
    // Quote Helpers
    // ========================================================================

    function _quotePool(
        address pool,
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        uint32 twapInterval
    )
        internal
        view
        returns (uint256 amountOut)
    {
        if (pool == address(0)) revert SushiSwapV3Facet_InvalidPoolAddress();
        if (!ILiquidityPoolRegistry(POOL_REGISTRY_ADDRESS).isPoolRegistered(pool)) {
            revert SushiSwapV3Facet_UnregisteredPool();
        }

        (uint160 sqrtPriceX96,) = _getSushiSqrtTwapX96(pool, twapInterval);
        address token0 = IUniswapV3Pool(pool).token0();
        address token1 = IUniswapV3Pool(pool).token1();

        uint256 price = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) >> 192;
        uint24 fee = IUniswapV3Pool(pool).fee();

        if (tokenIn == token0 && tokenOut == token1) {
            amountOut = (amountIn * price) >> 96;
        } else if (tokenIn == token1 && tokenOut == token0) {
            amountOut = amountIn / price;
        } else {
            revert SushiSwapV3Facet_InvalidPath();
        }
        // Deduct the pool's swap fee from the quoted output
        amountOut = amountOut * (1_000_000 - fee) / 1_000_000;
    }

    function _reverseQuotePool(
        address pool,
        uint256 amountOut,
        address tokenIn,
        address tokenOut,
        uint32 twapInterval
    )
        internal
        view
        returns (uint256 amountIn)
    {
        if (pool == address(0)) revert SushiSwapV3Facet_InvalidPoolAddress();
        if (!ILiquidityPoolRegistry(POOL_REGISTRY_ADDRESS).isPoolRegistered(pool)) {
            revert SushiSwapV3Facet_UnregisteredPool();
        }

        (uint160 sqrtPriceX96,) = _getSushiSqrtTwapX96(pool, twapInterval);
        address token0 = IUniswapV3Pool(pool).token0();
        address token1 = IUniswapV3Pool(pool).token1();

        uint256 price = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) >> 192;
        uint24 fee = IUniswapV3Pool(pool).fee();

        if (tokenIn == token0 && tokenOut == token1) {
            amountIn = (amountOut << 96) / price;
        } else if (tokenIn == token1 && tokenOut == token0) {
            amountIn = amountOut * price;
        } else {
            revert SushiSwapV3Facet_InvalidPath();
        }
        // Account for pool swap fee: need more input to cover the fee deduction (ceil division)
        amountIn = (amountIn * 1_000_000 + (1_000_000 - fee) - 1) / (1_000_000 - fee);
    }

    // ========================================================================
    // TWAP Helpers
    // ========================================================================

    /// @notice Gets the TWAP sqrt price for a single SushiSwap V3 pool
    /// @dev Returns either the current spot price (if twapInterval is 0) or the
    ///      TWAP price over the specified interval. Price is returned in Q64.96 format.
    /// @param sushiSwapV3Pool Address of the SushiSwap V3 pool to query
    /// @param twapInterval TWAP observation interval in seconds (applies to all pools)
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
        if (sushiSwapV3Pool == address(0)) {
            revert SushiSwapV3Facet_InvalidPoolAddress();
        }

        if (twapInterval == 0) {
            // Use the instantaneous slot0 sqrt price
            (sqrtPriceX96,,,,,,) = IUniswapV3Pool(sushiSwapV3Pool).slot0();
            deadline = block.timestamp + 300;
        } else {
            uint32[] memory secondsAgo = new uint32[](2);
            secondsAgo[0] = twapInterval;
            secondsAgo[1] = 0;

            // Observe two cumulative ticks and compute average tick over interval
            (int56[] memory tickCumulative,) = IUniswapV3Pool(sushiSwapV3Pool).observe(secondsAgo);

            // Average tick = (tickCumulative[1] - tickCumulative[0]) / interval
            int24 avgTick = int24(int56(tickCumulative[1] - tickCumulative[0]) / int56(int32(twapInterval)));

            sqrtPriceX96 = TickMath.getSqrtRatioAtTick(avgTick);
            deadline = block.timestamp + 300;
        }
    }

    /// @notice Gets a combined TWAP price across multiple SushiSwap V3 pools
    /// @dev Multiplies prices from multiple pools together, with optional inversion.
    ///      Useful for calculating prices across complex paths (e.g., ETH -> USDC -> DAI).
    /// @param pools Array of PoolInfo describing which pools to combine
    /// @param twapInterval TWAP observation interval in seconds (applies to all pools)
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
        if (pools.length < 2) {
            revert SushiSwapV3Facet_PathMustHaveAtLeastTwoPools();
        }

        combinedPriceX96 = _calculateCombinedPrice(pools, twapInterval);
        deadline = block.timestamp + 300;
    }

    // ========================================================================
    // Callback Handler
    // ========================================================================

    /// @notice Handles the token pull triggered by a SushiSwap V3 pool during pool.swap()
    /// @dev Must NOT have nonReentrant — called from inside an already-executing swap.
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

    /// @notice Validates a single pool: registered in PoolRegistry AND canonical in SushiSwap factory
    /// @param pool The pool address from SwapInstruction.pools[]
    /// @param tokenIn The input token for this hop
    /// @param tokenOut The output token for this hop
    function _validatePool(address pool, address tokenIn, address tokenOut) internal view {
        if (pool == address(0)) revert SushiSwapV3Facet_InvalidPoolAddress();
        if (tokenIn == address(0) || tokenOut == address(0)) revert SushiSwapV3Facet_InvalidTokenAddress();

        // 1. Pool must be registered in our PoolRegistry
        if (!ILiquidityPoolRegistry(POOL_REGISTRY_ADDRESS).isPoolRegistered(pool)) {
            revert SushiSwapV3Facet_UnregisteredPool();
        }

        // 2. Pool must be the canonical SushiSwap V3 factory pool for this pair + fee
        uint24 fee = IUniswapV3Pool(pool).fee();
        address canonical = IUniswapV3Factory(SUSHISWAP_FACTORY_ADDRESS).getPool(tokenIn, tokenOut, fee);
        if (canonical != pool) revert SushiSwapV3Facet_UnregisteredPool();
    }

    /// @notice Validates all pools in a SwapInstruction upfront before execution
    /// @param instruction The swap instruction to validate
    function _validateSwapPools(SwapInstruction calldata instruction) internal view {
        for (uint256 i; i < instruction.pools.length; i++) {
            _validatePool(instruction.pools[i], instruction.tokens[i], instruction.tokens[i + 1]);
        }
    }

    // ========================================================================
    // Math Helpers
    // ========================================================================

    /// @notice Calculates combined TWAP price across multiple pools
    /// @dev Multiplies prices together, handling inversions. Uses Q96 fixed-point arithmetic.
    /// @param pools Array of PoolInfo describing which pools to combine
    /// @param twapInterval TWAP observation interval in seconds (applies to all pools)
    /// @return combinedPriceX96 Combined price in Q96 format
    function _calculateCombinedPrice(
        ISushiSwapV3.PoolInfo[] memory pools,
        uint32 twapInterval
    )
        internal
        view
        returns (uint256 combinedPriceX96)
    {
        // Start with 2**96 to preserve Q96 fixed-point scaling
        combinedPriceX96 = _pow(2, 96, 1);

        for (uint256 i = 0; i < pools.length; i++) {
            if (pools[i].pool == address(0)) {
                revert SushiSwapV3Facet_InvalidPoolAddress();
            }

            uint160 sqrtPriceX96;
            address pool = pools[i].pool;
            bool inverse = pools[i].inverse;

            if (twapInterval == 0) {
                // Use the instantaneous slot0 sqrt price
                (sqrtPriceX96,,,,,,) = IUniswapV3Pool(pool).slot0();
            } else {
                uint32[] memory secondsAgo = new uint32[](2);
                secondsAgo[0] = twapInterval;
                secondsAgo[1] = 0;

                // Observe two cumulative ticks and compute average tick over interval
                (int56[] memory tickCumulative,) = IUniswapV3Pool(pool).observe(secondsAgo);
                int24 avgTick = int24((tickCumulative[1] - tickCumulative[0]) / int56(int32(twapInterval)));
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

    /// @notice Internal integer power function with rounding and overflow guards
    /// @dev This helper is used for fixed-point normalization in Q96 calculations.
    ///      Implemented in assembly for gas efficiency.
    /// @param x Base value
    /// @param n Exponent
    /// @param b Base scaling (used for fixed-point rounding)
    /// @return z Result of x**n in scaled representation
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
