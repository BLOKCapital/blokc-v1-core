// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▛▀▜▌▐▛▚▖     ▐▌   ▐▌ ▐▌▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import { UniswapV3Base } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3Base.sol";
import { UniswapV3Facet_InvalidPath } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3Base.sol";
import { QuoteInstruction } from "src/interfaces/ISwapInstruction.sol";

/// @notice Thrown when a pool has zero in-range liquidity — it cannot absorb any swap
/// @param pool The empty pool
error UniswapV3DepthQuote_ZeroLiquidity(address pool);

/// @notice Thrown when a pool's one-side holdings are too small to deliver the quoted output
///         without extreme price impact (see MIN_SIDE_BALANCE_MULTIPLE)
/// @param pool The shallow pool
/// @param expectedOut The quoted output the pool could not feasibly deliver
/// @param maxAllowed The largest output this pool could feasibly deliver (balance / multiple)
error UniswapV3DepthQuote_InsufficientDepth(address pool, uint256 expectedOut, uint256 maxAllowed);

/// @title UniswapV3DepthQuoteFacet
/// @notice Liquidity-aware replacement for the rebalancer's Uniswap V3 quoting. The stock
///         UniswapV3Facet quote is price-only (30s TWAP): a factory-canonical-but-empty pool
///         quotes a perfectly normal price and wins route selection, then the router reverts
///         "Too little received" at execution time (production incident on LINK/USDC 0.05%).
///         This facet quotes identically but reverts up-front for pools that cannot plausibly
///         fill the trade:
///           1. pool.liquidity() == 0 — no in-range liquidity at all;
///           2. quoted output > pool's one-side token balance / MIN_SIDE_BALANCE_MULTIPLE —
///              the pool does not hold enough of the output token for the quote to be real.
///         Deployed standalone and wired to the Rebalancer via setDexConfig; exposes the SAME
///         uniswapV3Quote(QuoteInstruction) selector (0xc86f92af) as UniswapV3Facet, so the
///         pool registry's stored quote selector and the Rebalancer both work unchanged.
///         A depth revert reaches the Rebalancer as a failed quote staticcall, which skips the
///         pool (now evented) and tries the next one.
contract UniswapV3DepthQuoteFacet is UniswapV3Base {
    /// @notice Quoted output must be <= the pool's output-token balance divided by this
    ///         multiple. 4 means a leg may take at most 25% of the pool's one-side holdings.
    ///         Chosen so dust pools (the ~$35 LINK/USDC 0.05% incident pool) fail for every
    ///         realistic leg while ordinary mid-depth pools still route at current portfolio
    ///         sizes. balanceOf overstates deployable depth (out-of-range tokens + accrued
    ///         fees), so this is a proxy, not an impact model — combined with the rebalancer's
    ///         5% minOut and 0.5% value-loss guard it is sufficient.
    uint256 public constant MIN_SIDE_BALANCE_MULTIPLE = 4;

    /// @notice Liquidity-aware quote — same ABI as UniswapV3Facet.uniswapV3Quote
    /// @param instruction The QuoteInstruction describing the path and direction
    /// @return result exactOutput=false: estimated output. exactOutput=true: estimated input.
    function uniswapV3Quote(QuoteInstruction calldata instruction) external view returns (uint256 result) {
        uint256 hops = instruction.pools.length;
        if (hops == 0 || instruction.tokens.length != hops + 1) revert UniswapV3Facet_InvalidPath();

        uint32 twapInterval = 30; // 30s TWAP, identical to UniswapV3Facet

        if (!instruction.exactOutput) {
            // Exact input: quote hop by hop, then depth-check each hop's QUOTED OUTPUT against
            // the pool's output-token balance (same units by construction). Each hop's quoted
            // output becomes the next hop's input — and the next hop's depth requirement.
            result = instruction.amount;
            for (uint256 i; i < hops; i++) {
                result = _quotePool(
                    instruction.pools[i], result, instruction.tokens[i], instruction.tokens[i + 1], twapInterval
                );
                _checkDepth(instruction.pools[i], instruction.tokens[i + 1], result);
            }
        } else {
            // Exact output: walk backward; each hop's desired output is the depth requirement.
            result = instruction.amount;
            for (uint256 i = hops; i > 0; i--) {
                _checkDepth(instruction.pools[i - 1], instruction.tokens[i], result);
                result = _reverseQuotePool(
                    instruction.pools[i - 1], result, instruction.tokens[i - 1], instruction.tokens[i], twapInterval
                );
            }
        }
    }

    /// @dev Reverts when the pool cannot plausibly deliver `expectedOut` of `tokenOut`.
    function _checkDepth(address pool, address tokenOut, uint256 expectedOut) internal view {
        if (IUniswapV3Pool(pool).liquidity() == 0) {
            revert UniswapV3DepthQuote_ZeroLiquidity(pool);
        }
        uint256 sideBalance = IERC20(tokenOut).balanceOf(pool);
        uint256 maxAllowed = sideBalance / MIN_SIDE_BALANCE_MULTIPLE;
        if (expectedOut > maxAllowed) {
            revert UniswapV3DepthQuote_InsufficientDepth(pool, expectedOut, maxAllowed);
        }
    }
}
