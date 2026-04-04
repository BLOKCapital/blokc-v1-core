// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { PoolRegistryTestBase } from "../PoolRegistryTestBase.sol";
import { PoolRegistryHandler } from "./PoolRegistryHandler.sol";

contract PoolRegistryInvariantTest is PoolRegistryTestBase {
    PoolRegistryHandler public handler;

    function setUp() public override {
        super.setUp();
        handler = new PoolRegistryHandler(registry, owner);
        targetContract(address(handler));
    }

    // ═════════════════════════════════════════════════════════════════
    //                     POOL COUNT INVARIANTS
    // ═════════════════════════════════════════════════════════════════

    /// @notice getPoolCount must match ghost total
    function invariant_poolCountMatchesGhost() public view {
        assertEq(registry.getPoolCount(), handler.ghost_totalRegistered());
    }

    /// @notice getAllPools().length must equal getPoolCount()
    function invariant_allPoolsLengthMatchesCount() public view {
        assertEq(registry.getAllPools().length, registry.getPoolCount());
    }

    // ═════════════════════════════════════════════════════════════════
    //                     REGISTRATION INVARIANTS
    // ═════════════════════════════════════════════════════════════════

    /// @notice isPoolRegistered must match ghost state for every pool we've seen
    function invariant_registrationMatchesGhost() public view {
        uint256 len = handler.ghost_poolsLength();
        for (uint256 i = 0; i < len; i++) {
            address pool = handler.ghost_poolAt(i);
            assertEq(registry.isPoolRegistered(pool), handler.ghost_isRegistered(pool));
        }
    }

    // ═════════════════════════════════════════════════════════════════
    //                     POOL INFO INVARIANTS
    // ═════════════════════════════════════════════════════════════════

    /// @notice Registered pools must have token0 < token1 (canonical ordering)
    function invariant_registeredPoolsHaveCanonicalTokenOrder() public view {
        uint256 len = handler.ghost_poolsLength();
        for (uint256 i = 0; i < len; i++) {
            address pool = handler.ghost_poolAt(i);
            if (handler.ghost_isRegistered(pool)) {
                (address t0, address t1,) = registry.getPoolSwapInfo(pool);
                assertTrue(t0 < t1);
            }
        }
    }

    /// @notice Registered pools must have non-zero poolAddress in info
    function invariant_registeredPoolInfoHasNonZeroAddress() public view {
        uint256 len = handler.ghost_poolsLength();
        for (uint256 i = 0; i < len; i++) {
            address pool = handler.ghost_poolAt(i);
            if (handler.ghost_isRegistered(pool)) {
                assertEq(registry.getPool(pool).poolAddress, pool);
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════
    //                     DEX TRACKING INVARIANT
    // ═════════════════════════════════════════════════════════════════

    /// @notice Sum of getPoolsByDex across all known DEXes must equal total registered
    function invariant_dexCountsSumToTotal() public view {
        bytes32[] memory dexes = handler.getDexIds();
        uint256 sum;
        for (uint256 i = 0; i < dexes.length; i++) {
            sum += registry.getPoolsByDex(dexes[i]).length;
        }
        assertEq(sum, registry.getPoolCount());
    }

    // ═════════════════════════════════════════════════════════════════
    //                     PAIR ID INVARIANT
    // ═════════════════════════════════════════════════════════════════

    /// @notice Every pair ID returned by getAllPairIds must have at least one pool
    function invariant_pairIdsHaveAtLeastOnePool() public view {
        bytes32[] memory pairIds = registry.getAllPairIds();
        address[] memory allPools = registry.getAllPools();

        for (uint256 i = 0; i < pairIds.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < allPools.length; j++) {
                if (registry.isPoolRegistered(allPools[j])) {
                    if (registry.getPool(allPools[j]).pairId == pairIds[i]) {
                        found = true;
                        break;
                    }
                }
            }
            assertTrue(found);
        }
    }
}
