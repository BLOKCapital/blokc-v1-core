// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Test } from "forge-std/Test.sol";
import { LiquidityPoolRegistry } from "src/liquidityPoolRegistry/LiquidityPoolRegistry.sol";
import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";

/// @title MockPoolForHandler
/// @notice Minimal contract so poolAddress.code.length > 0
contract MockPoolForHandler {
    uint256 private _id;

    constructor(uint256 id_) {
        _id = id_;
    }
}

/// @title PoolRegistryHandler
/// @notice Invariant handler for LiquidityPoolRegistry.
///         Performs bounded add / remove actions and tracks ghost state.
contract PoolRegistryHandler is Test {
    LiquidityPoolRegistry public registry;
    address public registryOwner;

    // ── Bounded token pool
    // ──────────────────────────────────────────
    address[] public tokens;
    uint256 public constant NUM_TOKENS = 4;

    // ── DEX IDs
    // ─────────────────────────────────────────────────────
    bytes32[] public dexIds;

    // ── Deployed pools for use
    // ──────────────────────────────────────
    address[] public ghost_pools;
    mapping(address => bool) public ghost_isRegistered;

    // ── Counters
    // ────────────────────────────────────────────────────
    uint256 public ghost_totalRegistered;
    uint256 private _poolNonce;

    // ── Per-dex tracking
    // ────────────────────────────────────────────
    mapping(bytes32 => uint256) public ghost_dexCount;

    constructor(LiquidityPoolRegistry registry_, address registryOwner_) {
        registry = registry_;
        registryOwner = registryOwner_;

        // Deterministic tokens
        tokens.push(address(0xAAAA));
        tokens.push(address(0xBBBB));
        tokens.push(address(0xCCCC));
        tokens.push(address(0xDDDD));

        // DEX IDs
        dexIds.push(keccak256("UNISWAP_V3"));
        dexIds.push(keccak256("UNISWAP_V2"));
        dexIds.push(keccak256("CAMELOT_V3"));
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     HANDLER ACTIONS
    // ═══════════════════════════════════════════════════════════════════

    function addPool(uint256 tokenSeedA, uint256 tokenSeedB, uint256 dexSeed) external {
        uint256 idxA = tokenSeedA % NUM_TOKENS;
        uint256 idxB = tokenSeedB % NUM_TOKENS;
        if (idxA == idxB) idxB = (idxB + 1) % NUM_TOKENS;

        address tA = tokens[idxA];
        address tB = tokens[idxB];
        bytes32 dexId = dexIds[dexSeed % dexIds.length];

        // Deploy a fresh pool contract
        address poolAddr = address(new MockPoolForHandler(++_poolNonce));

        vm.prank(registryOwner);
        try registry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: poolAddr, tokenA: tA, tokenB: tB, dexId: dexId, pairName: "PAIR"
            })
        ) {
            ghost_pools.push(poolAddr);
            ghost_isRegistered[poolAddr] = true;
            ghost_totalRegistered++;
            ghost_dexCount[dexId]++;
        } catch {
            // already exists — skip
        }
    }

    function removePool(uint256 poolSeed) external {
        if (ghost_pools.length == 0) return;
        uint256 idx = poolSeed % ghost_pools.length;
        address poolAddr = ghost_pools[idx];
        if (!ghost_isRegistered[poolAddr]) return;

        // Get dexId before removal
        ILiquidityPoolRegistry.PoolInfo memory info = registry.getPool(poolAddr);

        vm.prank(registryOwner);
        registry.removePool(poolAddr);

        ghost_isRegistered[poolAddr] = false;
        ghost_totalRegistered--;
        ghost_dexCount[info.dexId]--;
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     GHOST ACCESSORS
    // ═══════════════════════════════════════════════════════════════════

    function ghost_poolsLength() external view returns (uint256) {
        return ghost_pools.length;
    }

    function ghost_poolAt(uint256 i) external view returns (address) {
        return ghost_pools[i];
    }

    function getDexIds() external view returns (bytes32[] memory) {
        return dexIds;
    }
}
