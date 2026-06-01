// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { ICamelotV2 } from "src/garden/facets/utilityFacets/arbitrumOne/camelotV2/ICamelotV2.sol";
import { ICamelotRouterV2 } from "src/interfaces/ICamelotRouterV2.sol";
import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { SwapInstruction, QuoteInstruction } from "src/interfaces/ISwapInstruction.sol";
import { DexPoolValidator } from "src/garden/libraries/DexPoolValidator.sol";

interface ICamelotV2PairLike {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

/// @notice Thrown when the resolved pool address is the zero address
error CamelotV2Facet_InvalidPoolAddress();

/// @notice Thrown when a pool along the swap path is not registered in the pool registry
error CamelotV2Facet_UnregisteredPool();

/// @notice Thrown when the swap path is invalid (wrong lengths)
error CamelotV2Facet_InvalidPath();

/// @notice Thrown when exact-output is requested (not supported on Camelot V2)
error CamelotV2Facet_ExactOutputNotSupported();

/**
 * @title CamelotV2Base
 * @notice Base contract for Camelot V2 swaps and quotes on Arbitrum One. Camelot V2 uses
 *         the classic AMM (constant-product) with 0.3% fee. One pool per token pair,
 *         identified by factory's getPair(tokenA, tokenB). Only exact-input swaps are
 *         supported; exact-output reverts.
 */
abstract contract CamelotV2Base {
    using SafeERC20 for IERC20;

    /// @notice Camelot V2 router address on Arbitrum One
    address internal constant CAMELOT_V2_ROUTER_ADDRESS = 0xc873fEcbd354f5A56E00E710B90EF4201db2448d;

    /// @notice Camelot V2 factory address on Arbitrum One
    address internal constant CAMELOT_V2_FACTORY_ADDRESS = 0x6EcCab422D763aC031210895C81787E87B43A652;

    /// @notice Liquidity pool registry address on Arbitrum One
    address internal constant POOL_REGISTRY_ADDRESS = 0xA3178280c191dD46c551b91c651F337E47594d85;

    /// @notice Emitted when a Camelot V2 swap is successfully executed
    /// @param tokenIn The input token address
    /// @param tokenOut The output token address
    /// @param amountIn The amount of input tokens swapped
    /// @param amountOut The amount of output tokens received
    event CamelotV2FacetTokensSwapped(
        address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
    );

    // ========================================================================
    // Swap Dispatcher
    // ========================================================================

    /// @notice Standardised swap dispatcher. Validates pools upfront, then delegates to the router.
    ///         Only exact-input swaps are supported. Exact-output reverts.
    function _camelotV2Swap(SwapInstruction calldata instruction) internal {
        uint256 hops = instruction.pools.length;
        if (hops == 0 || instruction.tokens.length != hops + 1) revert CamelotV2Facet_InvalidPath();

        if (instruction.exactOutput) revert CamelotV2Facet_ExactOutputNotSupported();

        _validateSwapPools(instruction);

        // Approve the input tokens for the swap
        IERC20 tokenIn = IERC20(instruction.tokens[0]);
        tokenIn.forceApprove(CAMELOT_V2_ROUTER_ADDRESS, instruction.amountIn);

        // Snapshot output token balance before swap
        address tokenOutAddr = instruction.tokens[instruction.tokens.length - 1];
        uint256 balanceBefore = IERC20(tokenOutAddr).balanceOf(address(this));

        // Execute the swap via the fee-on-transfer compatible router function
        ICamelotRouterV2(CAMELOT_V2_ROUTER_ADDRESS)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                instruction.amountIn,
                instruction.amountOut,
                instruction.tokens,
                address(this),
                address(0), // referrer
                block.timestamp
            );

        // Compute actual output from balance delta
        uint256 amountOut = IERC20(tokenOutAddr).balanceOf(address(this)) - balanceBefore;

        emit CamelotV2FacetTokensSwapped(instruction.tokens[0], tokenOutAddr, instruction.amountIn, amountOut);
    }

    // ========================================================================
    // Quote Dispatcher
    // ========================================================================

    /// @notice Unified quote dispatcher. Chains quotes through each pool using constant-product formula.
    function _camelotV2Quote(QuoteInstruction calldata inst) internal view returns (uint256 result) {
        uint256 hops = inst.pools.length;
        if (hops == 0 || inst.tokens.length != hops + 1) revert CamelotV2Facet_InvalidPath();

        if (!inst.exactOutput) {
            // Forward: chain amountIn through each hop
            result = inst.amount;
            for (uint256 i; i < hops; i++) {
                result = _quotePool(inst.pools[i], result, inst.tokens[i], inst.tokens[i + 1]);
            }
        } else {
            // Reverse: chain amountOut backwards through each hop
            result = inst.amount;
            for (uint256 i = hops; i > 0; i--) {
                result = _reverseQuotePool(inst.pools[i - 1], result, inst.tokens[i - 1], inst.tokens[i]);
            }
        }
    }

    // ========================================================================
    // Validation
    // ========================================================================

    /// @notice Validates a single V2 pool through the shared DexPoolValidator library
    function _validatePool(address pool, address tokenIn, address tokenOut) internal view {
        DexPoolValidator.validateV2Pool(POOL_REGISTRY_ADDRESS, CAMELOT_V2_FACTORY_ADDRESS, pool, tokenIn, tokenOut);
    }

    /// @notice Validates all pools in a SwapInstruction through DexPoolValidator
    function _validateSwapPools(SwapInstruction calldata instruction) internal view {
        DexPoolValidator.validateSwapPools(POOL_REGISTRY_ADDRESS, CAMELOT_V2_FACTORY_ADDRESS, instruction, false);
    }

    // ========================================================================
    // Quote Helpers
    // ========================================================================

    /// @notice Quotes output amount for exact input on a specific Camelot V2 pool using constant-product formula
    function _quotePool(
        address pool,
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    )
        internal
        view
        returns (uint256)
    {
        if (pool == address(0)) revert CamelotV2Facet_InvalidPoolAddress();
        if (!ILiquidityPoolRegistry(POOL_REGISTRY_ADDRESS).isPoolRegistered(pool)) {
            revert CamelotV2Facet_UnregisteredPool();
        }

        (uint112 reserve0, uint112 reserve1,) = ICamelotV2PairLike(pool).getReserves();
        address token0 = ICamelotV2PairLike(pool).token0();

        uint256 reserveIn;
        uint256 reserveOut;
        if (tokenIn == token0) {
            reserveIn = uint256(reserve0);
            reserveOut = uint256(reserve1);
        } else {
            reserveIn = uint256(reserve1);
            reserveOut = uint256(reserve0);
        }

        // Constant-product formula with 0.3% fee
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        return numerator / denominator;
    }

    /// @notice Quotes input amount needed for exact output on a specific Camelot V2 pool (reverse quote)
    function _reverseQuotePool(
        address pool,
        uint256 amountOut,
        address tokenIn,
        address tokenOut
    )
        internal
        view
        returns (uint256)
    {
        if (pool == address(0)) revert CamelotV2Facet_InvalidPoolAddress();
        if (!ILiquidityPoolRegistry(POOL_REGISTRY_ADDRESS).isPoolRegistered(pool)) {
            revert CamelotV2Facet_UnregisteredPool();
        }

        (uint112 reserve0, uint112 reserve1,) = ICamelotV2PairLike(pool).getReserves();
        address token0 = ICamelotV2PairLike(pool).token0();

        uint256 reserveIn;
        uint256 reserveOut;
        if (tokenIn == token0) {
            reserveIn = uint256(reserve0);
            reserveOut = uint256(reserve1);
        } else {
            reserveIn = uint256(reserve1);
            reserveOut = uint256(reserve0);
        }

        // Reverse constant-product formula: amountIn = (reserveIn * amountOut * 1000) / ((reserveOut - amountOut) *
        // 997) + 1
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        return (numerator / denominator) + 1;
    }
}
