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

// Uniswap V3 Contracts
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

// Local Interfaces
import { IUniswapV3 } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/IUniswapV3.sol";
import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";
import { SwapInstruction, QuoteInstruction } from "src/interfaces/ISwapInstruction.sol";

// Local Libraries
import { TickMath } from "src/garden/libraries/TickMath.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when contract has insufficient token balance
error UniswapV3Facet_InsufficientBalance();

/// @notice Thrown when token approval fails
error UniswapV3Facet_ApprovalFailed();

/// @notice Thrown when pool is not registered in the LiquidityPoolRegistry
error UniswapV3Facet_UnregisteredPool();

/// @notice Thrown when swap deadline has already passed
error UniswapV3Facet_SwapDeadlineHasPassed();

/// @notice Thrown when swap path is invalid
error UniswapV3Facet_InvalidPath();

/// @notice Thrown when swap amount is zero
error UniswapV3Facet_InvalidAmount();

/// @notice Thrown when multi-hop path has fewer than two pools
error UniswapV3Facet_PathMustHaveAtLeastTwoPools();

/// @notice Thrown when router address is zero
error UniswapV3Facet_InvalidRouterAddress();

/// @notice Thrown when token address is zero
error UniswapV3Facet_InvalidTokenAddress();

/// @notice Thrown when pool address is zero
error UniswapV3Facet_InvalidPoolAddress();

/**
 * @title UniswapV3Base
 * @notice Base contract for Uniswap V3 interactions on Arbitrum One, providing shared logic for swaps and price
 * queries. This abstract contract is inherited by UniswapV3Facet which implements the external functions. It includes
 * internal functions for executing exact input/output swaps (single and multi-hop) and fetching TWAP prices. The
 * contract also validates pool registrations and handles token approvals securely using SafeERC20.
 */
abstract contract UniswapV3Base {
    using SafeERC20 for IERC20;

    // ========================================================================
    // Constants
    // ========================================================================

    /// @notice Uniswap V3 Router address on Arbitrum One
    address internal constant UNISWAP_V3_ROUTER_ADDRESS = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    /// @notice Pool Registry address on Arbitrum One
    address internal constant POOL_REGISTRY_ADDRESS = 0xA3178280c191dD46c551b91c651F337E47594d85;
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
    event UniswapV3FacetTokensSwapped(
        address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
    );

    /// @notice Uniswap V3 base exact input single swap
    /// @param params Single-hop swap parameters including tokens, amounts, fees, and deadline
    /// @dev Validates pool registration, handles token approvals, and executes swap.
    ///      Uses SafeERC20 for secure token operations.
    function _uniswapV3ExactInputSingle(IUniswapV3.UniswapV3ExactInputSingleParams memory params)
        internal
        returns (uint256 amountOut)
    {
        ISwapRouter router = ISwapRouter(UNISWAP_V3_ROUTER_ADDRESS);
        IERC20 tokenIn = IERC20(params.tokenIn);

        // Approve the input tokens for the swap
        tokenIn.forceApprove(UNISWAP_V3_ROUTER_ADDRESS, params.amountIn);

        // Build swap parameters
        ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter.ExactInputSingleParams({
            tokenIn: params.tokenIn,
            tokenOut: params.tokenOut,
            recipient: address(this),
            deadline: params.deadline,
            amountIn: params.amountIn,
            amountOutMinimum: params.amountOutMinimum,
            sqrtPriceLimitX96: 0,
            fee: params.swapFee
        });

        // Execute the swap
        amountOut = router.exactInputSingle(swapParams);

        // Emit the tokens swapped event
        emit UniswapV3FacetTokensSwapped(params.tokenIn, params.tokenOut, params.amountIn, amountOut);
    }

    /// @notice Uniswap V3 base exact input swap
    /// @param params Multi-hop swap parameters including path, amounts, and deadline
    /// @dev Validates all pools in the path are registered, handles approvals,
    ///      encodes the path, and executes the swap.
    function _uniswapV3ExactInput(IUniswapV3.UniswapV3ExactInputParams memory params) internal {
        if (params.pathWithFees.length < 2) {
            revert UniswapV3Facet_InvalidPath();
        }

        ISwapRouter router = ISwapRouter(UNISWAP_V3_ROUTER_ADDRESS);
        IERC20 tokenIn = IERC20(params.pathWithFees[0].token);
        address tokenOut = params.pathWithFees[params.pathWithFees.length - 1].token;

        // Approve the input tokens for the swap
        tokenIn.forceApprove(UNISWAP_V3_ROUTER_ADDRESS, params.amountIn);

        // Encode path (token, fee, token, fee, token, ...)
        bytes memory path = _encodePath(params.pathWithFees);
        ISwapRouter.ExactInputParams memory swapParams = ISwapRouter.ExactInputParams({
            path: path,
            recipient: address(this),
            deadline: params.deadline,
            amountIn: params.amountIn,
            amountOutMinimum: params.amountOutMin
        });

        // Execute the swap
        uint256 amountOut = router.exactInput(swapParams);

        // Emit the tokens swapped event
        emit UniswapV3FacetTokensSwapped(address(tokenIn), tokenOut, params.amountIn, amountOut);
    }

    /// @notice Uniswap V3 base exact output single swap
    /// @param params Single-hop swap parameters including tokens, amounts, fees, and deadline
    /// @dev Validates pool registration, handles token approvals, and executes swap.
    ///      Uses SafeERC20 for secure token operations.
    function _uniswapV3ExactOutputSingle(IUniswapV3.UniswapV3ExactOutputSingleParams memory params) internal {
        ISwapRouter router = ISwapRouter(UNISWAP_V3_ROUTER_ADDRESS);

        IERC20 tokenIn = IERC20(params.tokenIn);
        address tokenOut = params.tokenOut;

        // Approve the input tokens for the swap
        tokenIn.forceApprove(UNISWAP_V3_ROUTER_ADDRESS, params.amountInMaximum);

        // Build swap parameters
        ISwapRouter.ExactOutputSingleParams memory swapParams = ISwapRouter.ExactOutputSingleParams({
            tokenIn: address(tokenIn),
            tokenOut: tokenOut,
            fee: params.swapFee,
            recipient: address(this),
            deadline: params.deadline,
            amountOut: params.amountOut,
            amountInMaximum: params.amountInMaximum,
            sqrtPriceLimitX96: 0
        });

        // Execute the swap
        uint256 amountIn = router.exactOutputSingle(swapParams);

        // Emit the tokens swapped event
        emit UniswapV3FacetTokensSwapped(address(tokenIn), tokenOut, amountIn, params.amountOut);
    }

    /// @notice Uniswap V3 base exact output swap
    /// @param params Multi-hop swap parameters including path, amounts, and deadline
    /// @dev Validates all pools in the path are registered, handles approvals,
    ///      encodes the path, and executes the swap.
    function _uniswapV3ExactOutput(IUniswapV3.UniswapV3ExactOutputParams memory params) internal {
        if (params.pathWithFees.length < 2) {
            revert UniswapV3Facet_InvalidPath();
        }
        if (block.timestamp > params.deadline) {
            revert UniswapV3Facet_SwapDeadlineHasPassed();
        }
        ISwapRouter router = ISwapRouter(UNISWAP_V3_ROUTER_ADDRESS);
        IERC20 tokenIn = IERC20(params.pathWithFees[0].token);

        tokenIn.forceApprove(UNISWAP_V3_ROUTER_ADDRESS, params.amountInMaximum);

        // Encode path (token, fee, token, fee, token, ...)
        bytes memory path = _encodePath(params.pathWithFees);
        ISwapRouter.ExactOutputParams memory swapParams = ISwapRouter.ExactOutputParams({
            path: path,
            recipient: address(this),
            deadline: params.deadline,
            amountOut: params.amountOut,
            amountInMaximum: params.amountInMaximum
        });

        // Execute the swap
        uint256 amountIn = router.exactOutput(swapParams);

        // Emit the tokens swapped event
        emit UniswapV3FacetTokensSwapped(
            params.pathWithFees[0].token,
            params.pathWithFees[params.pathWithFees.length - 1].token,
            amountIn,
            params.amountOut
        );
    }

    /// @notice Standardised swap dispatcher for the rebalance flow.
    ///         Reads fee tiers from pool contracts on-chain, then delegates to the
    ///         appropriate internal helper (single/multi, exactIn/exactOut).
    function _uniswapV3Swap(SwapInstruction calldata instruction) internal {
        uint256 hops = instruction.pools.length;
        if (hops == 0 || instruction.tokens.length != hops + 1) revert UniswapV3Facet_InvalidPath();

        // Validate all pools upfront: registered in PoolRegistry + canonical in Uniswap factory
        _validateSwapPools(instruction);

        if (hops == 1) {
            uint24 fee = IUniswapV3Pool(instruction.pools[0]).fee();

            if (!instruction.exactOutput) {
                _uniswapV3ExactInputSingle(
                    IUniswapV3.UniswapV3ExactInputSingleParams({
                        amountIn: instruction.amountIn,
                        amountOutMinimum: instruction.amountOut,
                        deadline: block.timestamp,
                        tokenIn: instruction.tokens[0],
                        tokenOut: instruction.tokens[1],
                        swapFee: fee
                    })
                );
            } else {
                _uniswapV3ExactOutputSingle(
                    IUniswapV3.UniswapV3ExactOutputSingleParams({
                        amountOut: instruction.amountOut,
                        amountInMaximum: instruction.amountIn,
                        deadline: block.timestamp,
                        tokenIn: instruction.tokens[0],
                        tokenOut: instruction.tokens[1],
                        swapFee: fee
                    })
                );
            }
        } else {
            // Build TokenWithFee[] from tokens + on-chain pool fees.
            // Convention: pathWithFees[i].fee = fee of pool connecting token[i] → token[i+1].
            // The last entry's fee is unused by _encodePath but read by _validateMultiHopPools
            // at index [i], so we store the fee at index [i] = pool[i-1].fee for i>=1
            // to satisfy the existing validation loop.
            IUniswapV3.TokenWithFee[] memory pathWithFees = new IUniswapV3.TokenWithFee[](instruction.tokens.length);
            for (uint256 i; i < instruction.tokens.length; i++) {
                uint24 fee = i < hops ? IUniswapV3Pool(instruction.pools[i]).fee() : 0;
                pathWithFees[i] = IUniswapV3.TokenWithFee({ token: instruction.tokens[i], fee: fee });
            }

            if (!instruction.exactOutput) {
                _uniswapV3ExactInput(
                    IUniswapV3.UniswapV3ExactInputParams({
                        pathWithFees: pathWithFees,
                        deadline: block.timestamp,
                        amountIn: instruction.amountIn,
                        amountOutMin: instruction.amountOut
                    })
                );
            } else {
                _uniswapV3ExactOutput(
                    IUniswapV3.UniswapV3ExactOutputParams({
                        pathWithFees: pathWithFees,
                        deadline: block.timestamp,
                        amountOut: instruction.amountOut,
                        amountInMaximum: instruction.amountIn
                    })
                );
            }
        }
    }

    /// @notice Unified quote dispatcher. Chains quotes through each pool in the path.
    ///         Uses 30s TWAP by default for manipulation resistance.
    /// @param instruction The QuoteInstruction describing the path and direction
    /// @return result exactOutput=false: estimated output. exactOutput=true: estimated input needed.
    function _uniswapV3Quote(QuoteInstruction calldata instruction) internal view returns (uint256 result) {
        uint256 hops = instruction.pools.length;
        if (hops == 0 || instruction.tokens.length != hops + 1) revert UniswapV3Facet_InvalidPath();

        uint32 twapInterval = 30; // 30s TWAP default

        if (!instruction.exactOutput) {
            // Exact input: chain quotes forward
            result = instruction.amount;
            for (uint256 i; i < hops; i++) {
                result = _quotePool(
                    instruction.pools[i], result, instruction.tokens[i], instruction.tokens[i + 1], twapInterval
                );
            }
        } else {
            // Exact output: chain reverse-quotes backward
            result = instruction.amount;
            for (uint256 i = hops; i > 0; i--) {
                result = _reverseQuotePool(
                    instruction.pools[i - 1], result, instruction.tokens[i - 1], instruction.tokens[i], twapInterval
                );
            }
        }
    }

    /// @notice Quotes output for a single pool given an input amount (exact input direction)
    /// @dev Uses two-step Math.mulDiv to avoid precision loss from intermediate truncation.
    ///      price = sqrtPriceX96² / 2¹⁹²  (token1 per token0 in raw units)
    ///      token0→token1: amountOut = amountIn × sqrtP² / 2¹⁹²
    ///      token1→token0: amountOut = amountIn × 2¹⁹² / sqrtP²
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
        if (pool == address(0)) revert UniswapV3Facet_InvalidPoolAddress();
        if (!ILiquidityPoolRegistry(POOL_REGISTRY_ADDRESS).isPoolRegistered(pool)) {
            revert UniswapV3Facet_UnregisteredPool();
        }

        (uint160 sqrtPriceX96,) = _getSqrtTwapX96(pool, twapInterval);
        address token0 = IUniswapV3Pool(pool).token0();
        address token1 = IUniswapV3Pool(pool).token1();

        uint256 sqrtP = uint256(sqrtPriceX96);
        uint256 Q96 = 1 << 96;
        uint24 fee = IUniswapV3Pool(pool).fee();

        if (tokenIn == token0 && tokenOut == token1) {
            // amountOut = amountIn * sqrtP² / 2^192  (split into two mulDivs)
            amountOut = Math.mulDiv(Math.mulDiv(amountIn, sqrtP, Q96), sqrtP, Q96);
        } else if (tokenIn == token1 && tokenOut == token0) {
            // amountOut = amountIn * 2^192 / sqrtP²  (split into two mulDivs)
            amountOut = Math.mulDiv(Math.mulDiv(amountIn, Q96, sqrtP), Q96, sqrtP);
        } else {
            revert UniswapV3Facet_InvalidPath();
        }
        // Deduct the pool's swap fee from the quoted output
        amountOut = Math.mulDiv(amountOut, 1_000_000 - fee, 1_000_000);
    }

    /// @notice Reverse-quotes: given a desired output amount, estimates the input needed
    /// @dev Inverse of _quotePool, using Math.mulDiv for full precision. Rounds up
    ///      so the estimated input is sufficient to produce at least the desired output.
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
        if (pool == address(0)) revert UniswapV3Facet_InvalidPoolAddress();
        if (!ILiquidityPoolRegistry(POOL_REGISTRY_ADDRESS).isPoolRegistered(pool)) {
            revert UniswapV3Facet_UnregisteredPool();
        }

        (uint160 sqrtPriceX96,) = _getSqrtTwapX96(pool, twapInterval);
        address token0 = IUniswapV3Pool(pool).token0();
        address token1 = IUniswapV3Pool(pool).token1();

        uint256 sqrtP = uint256(sqrtPriceX96);
        uint256 Q96 = 1 << 96;
        uint24 fee = IUniswapV3Pool(pool).fee();

        // Reverse of _quotePool: invert the direction
        if (tokenIn == token0 && tokenOut == token1) {
            // Forward: out = in * sqrtP² / 2^192  →  Reverse: in = out * 2^192 / sqrtP²
            amountIn = Math.mulDiv(Math.mulDiv(amountOut, Q96, sqrtP, Math.Rounding.Ceil), Q96, sqrtP, Math.Rounding.Ceil);
        } else if (tokenIn == token1 && tokenOut == token0) {
            // Forward: out = in * 2^192 / sqrtP²  →  Reverse: in = out * sqrtP² / 2^192
            amountIn = Math.mulDiv(Math.mulDiv(amountOut, sqrtP, Q96, Math.Rounding.Ceil), sqrtP, Q96, Math.Rounding.Ceil);
        } else {
            revert UniswapV3Facet_InvalidPath();
        }
        // Account for pool swap fee: need more input to cover the fee deduction
        amountIn = Math.mulDiv(amountIn, 1_000_000, 1_000_000 - fee, Math.Rounding.Ceil);
    }

    /// @notice Gets the TWAP sqrt price for a single Uniswap V3 pool
    /// @dev Returns either the current spot price (if twapInterval is 0) or the
    ///      TWAP price over the specified interval. Price is returned in Q64.96 format.
    /// @param uniswapV3Pool Address of the Uniswap V3 pool to query
    /// @param twapInterval TWAP observation interval in seconds (applies to all pools)
    /// @return sqrtPriceX96 The sqrt price in Q64.96 format
    /// @return deadline Suggested deadline for swaps using this price (now + 300s)
    function _getSqrtTwapX96(
        address uniswapV3Pool,
        uint32 twapInterval
    )
        internal
        view
        returns (uint160 sqrtPriceX96, uint256 deadline)
    {
        if (uniswapV3Pool == address(0)) {
            revert UniswapV3Facet_InvalidPoolAddress();
        }

        if (twapInterval == 0) {
            // Use the instantaneous slot0 sqrt price
            (sqrtPriceX96,,,,,,) = IUniswapV3Pool(uniswapV3Pool).slot0();
            deadline = block.timestamp + 300;
        } else {
            uint32[] memory secondsAgo = new uint32[](2);
            secondsAgo[0] = twapInterval;
            secondsAgo[1] = 0;

            // Observe two cumulative ticks and compute average tick over interval
            (int56[] memory tickCumulative,) = IUniswapV3Pool(uniswapV3Pool).observe(secondsAgo);

            // Average tick = (tickCumulative[1] - tickCumulative[0]) / interval
            int24 avgTick = int24(int56(tickCumulative[1] - tickCumulative[0]) / int56(int32(twapInterval)));

            sqrtPriceX96 = TickMath.getSqrtRatioAtTick(avgTick);
            deadline = block.timestamp + 300;
        }
    }

    /// @notice Gets a combined TWAP price across multiple Uniswap V3 pools
    /// @dev Multiplies prices from multiple pools together, with optional inversion.
    ///      Useful for calculating prices across complex paths (e.g., ETH -> USDC -> DAI).
    /// @param pools Array of PoolInfo describing which pools to combine
    /// @param twapInterval TWAP observation interval in seconds (applies to all pools)
    /// @return combinedPriceX96 The combined price in Q96 format
    /// @return deadline Suggested deadline for swaps using this price (now + 300s)
    function _getCombinedTwapX96(
        IUniswapV3.PoolInfo[] memory pools,
        uint32 twapInterval
    )
        internal
        view
        returns (uint256 combinedPriceX96, uint256 deadline)
    {
        if (pools.length < 2) {
            revert UniswapV3Facet_PathMustHaveAtLeastTwoPools();
        }

        combinedPriceX96 = _calculateCombinedPrice(pools, twapInterval);
        deadline = block.timestamp + 300;
    }

    /// @notice Validates a single pool: registered in PoolRegistry AND canonical in Uniswap factory
    /// @param pool The pool address from SwapInstruction.pools[]
    /// @param tokenIn The input token for this hop
    /// @param tokenOut The output token for this hop
    function _validatePool(address pool, address tokenIn, address tokenOut) internal view {
        if (pool == address(0)) revert UniswapV3Facet_InvalidPoolAddress();
        if (tokenIn == address(0) || tokenOut == address(0)) revert UniswapV3Facet_InvalidTokenAddress();

        // 1. Pool must be registered in our PoolRegistry
        if (!ILiquidityPoolRegistry(POOL_REGISTRY_ADDRESS).isPoolRegistered(pool)) {
            revert UniswapV3Facet_UnregisteredPool();
        }

        // 2. Pool must be the canonical Uniswap V3 factory pool for this pair + fee
        uint24 fee = IUniswapV3Pool(pool).fee();
        address canonical = IUniswapV3Factory(UNISWAP_FACTORY_ADDRESS).getPool(tokenIn, tokenOut, fee);
        if (canonical != pool) revert UniswapV3Facet_UnregisteredPool();
    }

    /// @notice Validates all pools in a SwapInstruction upfront before execution
    /// @param instruction The swap instruction to validate
    function _validateSwapPools(SwapInstruction calldata instruction) internal view {
        for (uint256 i; i < instruction.pools.length; i++) {
            _validatePool(instruction.pools[i], instruction.tokens[i], instruction.tokens[i + 1]);
        }
    }

    /// @notice Encodes a multi-hop path for Uniswap V3 router
    /// @dev Encodes path as: token0, fee0, token1, fee1, token2, ...
    /// @param pathWithFees Array of TokenWithFee describing the path
    /// @return path Encoded path bytes
    function _encodePath(IUniswapV3.TokenWithFee[] memory pathWithFees) internal pure returns (bytes memory path) {
        path = abi.encodePacked(pathWithFees[0].token);
        for (uint256 i = 1; i < pathWithFees.length; ++i) {
            path = abi.encodePacked(path, pathWithFees[i - 1].fee, pathWithFees[i].token);
        }
    }

    /// @notice Calculates combined TWAP price across multiple pools
    /// @dev Multiplies prices together, handling inversions. Uses Q96 fixed-point arithmetic.
    /// @param pools Array of PoolInfo describing which pools to combine
    /// @param twapInterval TWAP observation interval in seconds (applies to all pools)
    /// @return combinedPriceX96 Combined price in Q96 format
    function _calculateCombinedPrice(
        IUniswapV3.PoolInfo[] memory pools,
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
                revert UniswapV3Facet_InvalidPoolAddress();
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
