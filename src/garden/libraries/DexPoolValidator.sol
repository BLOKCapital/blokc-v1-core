// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import { SwapInstruction } from "src/interfaces/ISwapInstruction.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when a pool address is zero
error DexPoolValidator_InvalidPoolAddress();

/// @notice Thrown when a token address is zero (V3 only)
error DexPoolValidator_InvalidTokenAddress();

/// @notice Thrown when a pool is not registered in the LiquidityPoolRegistry
error DexPoolValidator_UnregisteredPool(address pool);

/// @notice Thrown when a pool is not the canonical pool from the DEX's factory
error DexPoolValidator_NotCanonicalPool(address pool, address canonical);

/// @notice Thrown when a factory getPair/getPool call fails (V2-style)
error DexPoolValidator_FactoryCallFailed();

/// @notice Thrown when tokenA and tokenB are the same address (cannot form a valid pair)
error DexPoolValidator_IdenticalTokens();

/// @notice Thrown when a SwapInstruction has mismatched tokens/pools array lengths
error DexPoolValidator_InvalidPath();

/**
 * @title DexPoolValidator
 * @author BLOK Capital DAO
 * @notice Shared library for DEX pool validation. Enforces that pools are registered in the
 *         LiquidityPoolRegistry AND canonical in their DEX's factory. Used by both Garden
 *         DEX facets and the CumulativeRebalancer so validation logic stays in one place.
 *
 *         Two validation paths:
 *         - V2-style (Camelot V2, Uniswap V2): factory.getPair(tokenA, tokenB)
 *         - V3-style (Uniswap V3):            factory.getPool(tokenA, tokenB, fee)
 */
library DexPoolValidator {
    // ========================================================================
    // V2-style Validation (Camelot V2, Uniswap V2)
    // ========================================================================

    /**
     * @notice Validates that a V2-style pool is registered in the PoolRegistry and
     *         canonical in the given factory. The factory is called via staticcall
     *         with getPair(tokenA, tokenB) — works for both Uniswap V2 and Camelot V2 factories.
     * @param poolRegistry Address of the LiquidityPoolRegistry contract
     * @param factory Address of the DEX factory contract
     * @param pool Address of the liquidity pool to validate
     * @param tokenA First token in the pair
     * @param tokenB Second token in the pair
     */
    function validateV2Pool(
        address poolRegistry,
        address factory,
        address pool,
        address tokenA,
        address tokenB
    )
        internal
        view
    {
        if (pool == address(0)) revert DexPoolValidator_InvalidPoolAddress();
        if (tokenA == address(0) || tokenB == address(0)) revert DexPoolValidator_InvalidTokenAddress();
        if (tokenA == tokenB) revert DexPoolValidator_IdenticalTokens();

        // 1. Pool must be registered in the LiquidityPoolRegistry
        if (!ILiquidityPoolRegistry(poolRegistry).isPoolRegistered(pool)) {
            revert DexPoolValidator_UnregisteredPool(pool);
        }

        // 2. Pool must be the canonical factory pair for this token pair
        (bool ok, bytes memory data) =
            factory.staticcall(abi.encodeWithSignature("getPair(address,address)", tokenA, tokenB));
        if (!ok || data.length < 32) revert DexPoolValidator_FactoryCallFailed();

        address canonical = abi.decode(data, (address));
        if (canonical != pool) revert DexPoolValidator_NotCanonicalPool(pool, canonical);
    }

    // ========================================================================
    // V3-style Validation (Uniswap V3)
    // ========================================================================

    /**
     * @notice Validates that a Uniswap V3 pool is registered in the PoolRegistry and
     *         canonical in the Uniswap V3 factory. Reads the fee tier from the pool on-chain.
     * @param poolRegistry Address of the LiquidityPoolRegistry contract
     * @param factory Address of the Uniswap V3 factory contract
     * @param pool Address of the Uniswap V3 pool to validate
     * @param tokenA First token in the pair
     * @param tokenB Second token in the pair
     */
    function validateV3Pool(
        address poolRegistry,
        address factory,
        address pool,
        address tokenA,
        address tokenB
    )
        internal
        view
    {
        if (pool == address(0)) revert DexPoolValidator_InvalidPoolAddress();
        if (tokenA == address(0) || tokenB == address(0)) revert DexPoolValidator_InvalidTokenAddress();
        if (tokenA == tokenB) revert DexPoolValidator_IdenticalTokens();

        // 1. Pool must be registered in the LiquidityPoolRegistry
        if (!ILiquidityPoolRegistry(poolRegistry).isPoolRegistered(pool)) {
            revert DexPoolValidator_UnregisteredPool(pool);
        }

        // 2. Pool must be the canonical Uniswap V3 factory pool for this pair + fee
        uint24 fee = IUniswapV3Pool(pool).fee();
        address canonical = IUniswapV3Factory(factory).getPool(tokenA, tokenB, fee);
        if (canonical != pool) revert DexPoolValidator_NotCanonicalPool(pool, canonical);
    }

    // ========================================================================
    // Camelot V3 Validation
    // ========================================================================

    /**
     * @notice Validates that a Camelot V3 pool is registered and canonical.
     *         Camelot V3 uses Algebra-style pools (concentrated liquidity, similar to Uniswap V3)
     *         but its factory exposes `poolByPair(tokenA, tokenB)` instead of `getPool(tokenA, tokenB, fee)`.
     *         Fee tiers are dynamic on Camelot V3, so canonicality is checked by the pair alone.
     * @param poolRegistry Address of the LiquidityPoolRegistry contract
     * @param factory Address of the Camelot V3 factory contract
     * @param pool Address of the Camelot V3 pool to validate
     * @param tokenA First token in the pair
     * @param tokenB Second token in the pair
     */
    function validateCamelotV3Pool(
        address poolRegistry,
        address factory,
        address pool,
        address tokenA,
        address tokenB
    )
        internal
        view
    {
        if (pool == address(0)) revert DexPoolValidator_InvalidPoolAddress();
        if (tokenA == address(0) || tokenB == address(0)) revert DexPoolValidator_InvalidTokenAddress();
        if (tokenA == tokenB) revert DexPoolValidator_IdenticalTokens();

        // 1. Pool must be registered in the LiquidityPoolRegistry
        if (!ILiquidityPoolRegistry(poolRegistry).isPoolRegistered(pool)) {
            revert DexPoolValidator_UnregisteredPool(pool);
        }

        // 2. Pool must be the canonical Camelot V3 factory pool for this pair
        (bool ok, bytes memory data) =
            factory.staticcall(abi.encodeWithSignature("poolByPair(address,address)", tokenA, tokenB));
        if (!ok || data.length < 32) revert DexPoolValidator_FactoryCallFailed();

        address canonical = abi.decode(data, (address));
        if (canonical != pool) revert DexPoolValidator_NotCanonicalPool(pool, canonical);
    }

    // ========================================================================
    // Bulk Validation (SwapInstruction)
    // ========================================================================

    /**
     * @notice Validates all pools in a SwapInstruction. Dispatches per-pool based on whether
     *         the caller passes V2 or V3 factories. For heterogeneous multi-hop paths, call
     *         validateV2Pool / validateV3Pool directly per hop.
     *
     *         This convenience overload uses a single factory — suitable when all hops
     *         are on the same DEX (the common case).
     * @param poolRegistry Address of the LiquidityPoolRegistry contract
     * @param factory Address of the DEX factory contract
     * @param instruction The SwapInstruction to validate
     * @param isV3 True for Uniswap V3 factory (uses getPool with fee), false for V2 (uses getPair)
     */
    function validateSwapPools(
        address poolRegistry,
        address factory,
        SwapInstruction calldata instruction,
        bool isV3
    )
        internal
        view
    {
        if (instruction.tokens.length != instruction.pools.length + 1) revert DexPoolValidator_InvalidPath();

        for (uint256 i = 0; i < instruction.pools.length; i++) {
            if (isV3) {
                validateV3Pool(
                    poolRegistry, factory, instruction.pools[i], instruction.tokens[i], instruction.tokens[i + 1]
                );
            } else {
                validateV2Pool(
                    poolRegistry, factory, instruction.pools[i], instruction.tokens[i], instruction.tokens[i + 1]
                );
            }
        }
    }
}
