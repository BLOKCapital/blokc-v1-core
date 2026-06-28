// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { ICamelotRouterV3 } from "src/interfaces/ICamelotRouterV3.sol";
import { ICamelotV3 } from "src/garden/facets/utilityFacets/arbitrumOne/camelotV3/ICamelotV3.sol";
import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { TickMath } from "src/garden/libraries/TickMath.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { SwapInstruction, QuoteInstruction } from "src/interfaces/ISwapInstruction.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { DexPoolValidator } from "src/garden/libraries/DexPoolValidator.sol";

/// @notice Thrown when the factory poolByPair call returns an invalid pool address
error CamelotV3Facet_InvalidPoolAddress();

/// @notice Thrown when the resolved pool address is the zero address
error CamelotV3Facet_InvalidPool();

/// @notice Thrown when a pool is not registered or doesn't match the factory canonical pool
error CamelotV3Facet_UnregisteredPool();

/// @notice Thrown when the swap path is invalid (wrong lengths)
error CamelotV3Facet_InvalidPath();

/**
 * @title CamelotV3Base
 * @notice Base contract for Camelot V3 swaps and quotes on Arbitrum One. Camelot V3 uses
 *         the Algebra protocol with dynamic fees — no fee parameter is needed. One pool
 *         per token pair, identified by factory's poolByPair(tokenA, tokenB).
 */
abstract contract CamelotV3Base {
    using SafeERC20 for IERC20;

    /// @notice Camelot V3 router address on Arbitrum One
    address internal constant CAMELOT_V3_ROUTER_ADDRESS = 0x1F721E2E82F6676FCE4eA07A5958cF098D339e18;

    /// @notice Camelot V3 factory address on Arbitrum One
    address internal constant CAMELOT_V3_FACTORY_ADDRESS = 0x1a3c9B1d2F0529D97f2afC5136Cc23e58f1FD35B;

    /// @notice Liquidity pool registry address on Arbitrum One
    address internal constant POOL_REGISTRY_ADDRESS = 0xA3178280c191dD46c551b91c651F337E47594d85;

    /// @notice Emitted when a Camelot V3 swap is successfully executed
    event CamelotV3FacetTokensSwapped(
        address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
    );

    // ========================================================================
    // Swap Dispatcher
    // ========================================================================

    /// @notice Standardised swap dispatcher. Validates pools upfront, then delegates.
    function _camelotV3Swap(SwapInstruction calldata instruction) internal {
        uint256 hops = instruction.pools.length;
        if (hops == 0 || instruction.tokens.length != hops + 1) revert CamelotV3Facet_InvalidPath();

        _validateSwapPools(instruction);

        if (hops == 1) {
            if (!instruction.exactOutput) {
                _camelotV3ExactInputSingle(
                    ICamelotV3.CamelotV3ExactInputSingleParams({
                        tokenIn: instruction.tokens[0],
                        tokenOut: instruction.tokens[1],
                        recipient: address(this),
                        deadline: block.timestamp,
                        amountIn: instruction.amountIn,
                        amountOutMinimum: instruction.amountOut,
                        limitSqrtPrice: 0
                    })
                );
            } else {
                _camelotV3ExactOutputSingle(
                    ICamelotV3.CamelotV3ExactOutputSingleParams({
                        tokenIn: instruction.tokens[0],
                        tokenOut: instruction.tokens[1],
                        recipient: address(this),
                        deadline: block.timestamp,
                        amountOut: instruction.amountOut,
                        amountInMaximum: instruction.amountIn,
                        limitSqrtPrice: 0
                    })
                );
            }
        } else {
            if (!instruction.exactOutput) {
                _camelotV3ExactInput(
                    ICamelotV3.CamelotV3ExactInputParams({
                        path: instruction.tokens,
                        recipient: address(this),
                        deadline: block.timestamp,
                        amountIn: instruction.amountIn,
                        amountOutMinimum: instruction.amountOut
                    })
                );
            } else {
                _camelotV3ExactOutput(
                    ICamelotV3.CamelotV3ExactOutputParams({
                        path: instruction.tokens,
                        recipient: address(this),
                        deadline: block.timestamp,
                        amountOut: instruction.amountOut,
                        amountInMaximum: instruction.amountIn
                    })
                );
            }
        }
    }

    // ========================================================================
    // Quote Dispatcher
    // ========================================================================

    /// @notice Unified quote dispatcher. Chains quotes through each pool. Uses 30s TWAP.
    function _camelotV3Quote(QuoteInstruction calldata inst) internal view returns (uint256 result) {
        uint256 hops = inst.pools.length;
        if (hops == 0 || inst.tokens.length != hops + 1) revert CamelotV3Facet_InvalidPath();

        uint32 twapInterval = 30;

        if (!inst.exactOutput) {
            result = inst.amount;
            for (uint256 i; i < hops; i++) {
                result = _quotePool(inst.pools[i], result, inst.tokens[i], inst.tokens[i + 1], twapInterval);
            }
        } else {
            result = inst.amount;
            for (uint256 i = hops; i > 0; i--) {
                result = _reverseQuotePool(inst.pools[i - 1], result, inst.tokens[i - 1], inst.tokens[i], twapInterval);
            }
        }
    }

    // ========================================================================
    // Internal Swap Helpers (no validation — caller validates upfront)
    // ========================================================================

    function _camelotV3ExactInputSingle(ICamelotV3.CamelotV3ExactInputSingleParams memory params) internal {
        ICamelotRouterV3 router = ICamelotRouterV3(CAMELOT_V3_ROUTER_ADDRESS);
        IERC20(params.tokenIn).forceApprove(CAMELOT_V3_ROUTER_ADDRESS, params.amountIn);

        uint256 amountOut = router.exactInputSingle(
            ICamelotRouterV3.ExactInputSingleParams({
                tokenIn: params.tokenIn,
                tokenOut: params.tokenOut,
                recipient: address(this),
                deadline: params.deadline,
                amountIn: params.amountIn,
                amountOutMinimum: params.amountOutMinimum,
                limitSqrtPrice: params.limitSqrtPrice
            })
        );

        emit CamelotV3FacetTokensSwapped(params.tokenIn, params.tokenOut, params.amountIn, amountOut);
    }

    function _camelotV3ExactInput(ICamelotV3.CamelotV3ExactInputParams memory params) internal {
        ICamelotRouterV3 router = ICamelotRouterV3(CAMELOT_V3_ROUTER_ADDRESS);
        IERC20(params.path[0]).forceApprove(CAMELOT_V3_ROUTER_ADDRESS, params.amountIn);

        bytes memory encodedPath = _encodePath(params.path);
        uint256 amountOut = router.exactInput(
            ICamelotRouterV3.ExactInputParams({
                path: encodedPath,
                recipient: address(this),
                deadline: params.deadline,
                amountIn: params.amountIn,
                amountOutMinimum: params.amountOutMinimum
            })
        );

        emit CamelotV3FacetTokensSwapped(
            params.path[0], params.path[params.path.length - 1], params.amountIn, amountOut
        );
    }

    function _camelotV3ExactOutputSingle(ICamelotV3.CamelotV3ExactOutputSingleParams memory params) internal {
        ICamelotRouterV3 router = ICamelotRouterV3(CAMELOT_V3_ROUTER_ADDRESS);
        IERC20(params.tokenIn).forceApprove(CAMELOT_V3_ROUTER_ADDRESS, params.amountInMaximum);

        uint256 amountIn = router.exactOutputSingle(
            ICamelotRouterV3.ExactOutputSingleParams({
                tokenIn: params.tokenIn,
                tokenOut: params.tokenOut,
                recipient: address(this),
                deadline: params.deadline,
                amountOut: params.amountOut,
                amountInMaximum: params.amountInMaximum,
                limitSqrtPrice: params.limitSqrtPrice
            })
        );

        emit CamelotV3FacetTokensSwapped(params.tokenIn, params.tokenOut, amountIn, params.amountOut);
    }

    function _camelotV3ExactOutput(ICamelotV3.CamelotV3ExactOutputParams memory params) internal {
        ICamelotRouterV3 router = ICamelotRouterV3(CAMELOT_V3_ROUTER_ADDRESS);
        IERC20(params.path[0]).forceApprove(CAMELOT_V3_ROUTER_ADDRESS, params.amountInMaximum);

        bytes memory encodedPath = _encodePath(params.path);
        uint256 amountIn = router.exactOutput(
            ICamelotRouterV3.ExactOutputParams({
                path: encodedPath,
                recipient: address(this),
                deadline: params.deadline,
                amountOut: params.amountOut,
                amountInMaximum: params.amountInMaximum
            })
        );

        emit CamelotV3FacetTokensSwapped(
            params.path[0], params.path[params.path.length - 1], amountIn, params.amountOut
        );
    }

    // ========================================================================
    // Validation
    // ========================================================================

    /// @notice Validates all pools in a SwapInstruction through DexPoolValidator
    function _validateSwapPools(SwapInstruction calldata instruction) internal view {
        for (uint256 i; i < instruction.pools.length; i++) {
            DexPoolValidator.validateCamelotV3Pool(
                POOL_REGISTRY_ADDRESS,
                CAMELOT_V3_FACTORY_ADDRESS,
                instruction.pools[i],
                instruction.tokens[i],
                instruction.tokens[i + 1]
            );
        }
    }

    // ========================================================================
    // Quote Helpers
    // ========================================================================

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
        returns (uint256)
    {
        if (pool == address(0)) revert CamelotV3Facet_InvalidPoolAddress();
        if (!ILiquidityPoolRegistry(POOL_REGISTRY_ADDRESS).isPoolRegistered(pool)) {
            revert CamelotV3Facet_UnregisteredPool();
        }

        (uint160 sqrtPriceX96,) = _camelotV3GetSqrtTwapX96(pool, twapInterval);
        address token0 = IUniswapV3Pool(pool).token0();
        address token1 = IUniswapV3Pool(pool).token1();
        uint256 sqrtP = uint256(sqrtPriceX96);
        uint256 Q96 = 1 << 96;
        uint24 fee = IUniswapV3Pool(pool).fee();

        uint256 rawAmountOut;
        if (tokenIn == token0 && tokenOut == token1) {
            rawAmountOut = Math.mulDiv(Math.mulDiv(amountIn, sqrtP, Q96), sqrtP, Q96);
        } else if (tokenIn == token1 && tokenOut == token0) {
            rawAmountOut = Math.mulDiv(Math.mulDiv(amountIn, Q96, sqrtP), Q96, sqrtP);
        } else {
            revert CamelotV3Facet_InvalidPool();
        }
        // Deduct the pool's swap fee from the quoted output
        return Math.mulDiv(rawAmountOut, 1_000_000 - fee, 1_000_000);
    }

    /// @dev Inverse of _quotePool. Rounds up so estimated input is sufficient.
    function _reverseQuotePool(
        address pool,
        uint256 amountOut,
        address tokenIn,
        address tokenOut,
        uint32 twapInterval
    )
        internal
        view
        returns (uint256)
    {
        if (pool == address(0)) revert CamelotV3Facet_InvalidPoolAddress();
        if (!ILiquidityPoolRegistry(POOL_REGISTRY_ADDRESS).isPoolRegistered(pool)) {
            revert CamelotV3Facet_UnregisteredPool();
        }

        (uint160 sqrtPriceX96,) = _camelotV3GetSqrtTwapX96(pool, twapInterval);
        address token0 = IUniswapV3Pool(pool).token0();
        address token1 = IUniswapV3Pool(pool).token1();
        uint256 sqrtP = uint256(sqrtPriceX96);
        uint256 Q96 = 1 << 96;
        uint24 fee = IUniswapV3Pool(pool).fee();

        uint256 rawAmountIn;
        if (tokenIn == token0 && tokenOut == token1) {
            rawAmountIn =
                Math.mulDiv(Math.mulDiv(amountOut, Q96, sqrtP, Math.Rounding.Ceil), Q96, sqrtP, Math.Rounding.Ceil);
        } else if (tokenIn == token1 && tokenOut == token0) {
            rawAmountIn =
                Math.mulDiv(Math.mulDiv(amountOut, sqrtP, Q96, Math.Rounding.Ceil), sqrtP, Q96, Math.Rounding.Ceil);
        } else {
            revert CamelotV3Facet_InvalidPool();
        }
        // Account for pool swap fee: need more input to cover the fee deduction
        return Math.mulDiv(rawAmountIn, 1_000_000, 1_000_000 - fee, Math.Rounding.Ceil);
    }

    // ========================================================================
    // TWAP & Path Encoding
    // ========================================================================

    function _camelotV3GetSqrtTwapX96(
        address poolAddress,
        uint32 twapInterval
    )
        internal
        view
        returns (uint160 sqrtPriceX96, uint256 deadline)
    {
        if (poolAddress == address(0)) revert CamelotV3Facet_InvalidPool();

        if (twapInterval == 0) {
            (sqrtPriceX96,,,,,,) = IUniswapV3Pool(poolAddress).slot0();
            deadline = block.timestamp + 300;
        } else {
            uint32[] memory secondsAgo = new uint32[](2);
            secondsAgo[0] = twapInterval;
            secondsAgo[1] = 0;
            (int56[] memory tickCumulative,) = IUniswapV3Pool(poolAddress).observe(secondsAgo);
            int24 avgTick = int24(int56(tickCumulative[1] - tickCumulative[0]) / int56(int32(twapInterval)));
            sqrtPriceX96 = TickMath.getSqrtRatioAtTick(avgTick);
            deadline = block.timestamp + 300;
        }
    }

    function _encodePath(address[] memory path) internal pure returns (bytes memory encodedPath) {
        encodedPath = abi.encodePacked(path[0]);
        for (uint256 i = 1; i < path.length; ++i) {
            encodedPath = abi.encodePacked(encodedPath, path[i]);
        }
    }
}
