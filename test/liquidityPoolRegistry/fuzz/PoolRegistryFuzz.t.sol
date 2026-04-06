// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { PoolRegistryTestBase, MockPool } from "../PoolRegistryTestBase.sol";
import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";

contract PoolRegistryFuzzTest is PoolRegistryTestBase {
    // ═════════════════════════════════════════════════════════════════
    //                  FUZZ — addPool success
    // ═════════════════════════════════════════════════════════════════

    /// @notice Any valid pool addition registers and is queryable
    function testFuzz_addPool_registersSuccessfully(uint256 dexSeed) public {
        // Pick from pre-registered DEXes
        bytes32[3] memory dexes = [DEX_UNISWAP_V3, DEX_UNISWAP_V2, DEX_CAMELOT_V3];
        bytes32 dexId = dexes[dexSeed % dexes.length];

        _addPool(pool1, tokenA, tokenB, dexId, "A/B");

        assertTrue(registry.isPoolRegistered(pool1));
        assertEq(registry.getPoolCount(), 1);

        ILiquidityPoolRegistry.PoolInfo memory info = registry.getPool(pool1);
        assertEq(info.dexId, dexId);
    }

    /// @notice Token order should always be canonicalized (token0 < token1)
    function testFuzz_addPool_canonicalizesTokenOrder(address tA, address tB) public {
        tA = _boundAddress(tA);
        tB = _boundAddress(tB);
        vm.assume(tA != tB);

        address poolAddr = _deployMockPool(42);
        _addPool(poolAddr, tA, tB, DEX_UNISWAP_V3, "pair");

        ILiquidityPoolRegistry.PoolInfo memory info = registry.getPool(poolAddr);
        assertTrue(info.token0 < info.token1);
    }

    /// @notice Pool count always increments by 1
    function testFuzz_addPool_incrementsCountByOne(uint256 seed) public {
        uint256 n = bound(seed, 1, 5);

        for (uint256 i = 0; i < n; i++) {
            address p = _deployMockPool(i + 100);
            // Each _deployMockPool returns a unique address; uniqueness is by address
            _addPool(p, tokenA, tokenB, DEX_UNISWAP_V3, "pair");
        }

        assertEq(registry.getPoolCount(), n);
    }

    // ═════════════════════════════════════════════════════════════════
    //                  FUZZ — addPool reverts
    // ═════════════════════════════════════════════════════════════════

    /// @notice Identical tokens should always revert
    function testFuzz_addPool_revertsOnIdenticalTokens(address token) public {
        token = _boundAddress(token);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("LiquidityPoolRegistry_IdenticalTokens()"));
        registry.addPool(_params(pool1, token, token, DEX_UNISWAP_V3, "X/X"));
    }

    /// @notice Pair name at exactly 128 bytes should succeed; 129 should revert
    function testFuzz_addPool_pairNameLengthBoundary(uint256 len) public {
        len = bound(len, 1, 200);
        bytes memory name = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            name[i] = "A";
        }

        vm.prank(owner);
        if (len > 128) {
            vm.expectRevert(abi.encodeWithSignature("LiquidityPoolRegistry_PairNameTooLong()"));
        }
        registry.addPool(_params(pool1, tokenA, tokenB, DEX_UNISWAP_V3, string(name)));

        if (len <= 128) {
            assertTrue(registry.isPoolRegistered(pool1));
        }
    }

    // ═════════════════════════════════════════════════════════════════
    //                  FUZZ — removePool
    // ═════════════════════════════════════════════════════════════════

    /// @notice Removing a pool always reduces count by 1
    function testFuzz_removePool_decrementsCount(uint256 seed) public {
        uint256 n = bound(seed, 1, 5);
        address[] memory pools = new address[](n);

        for (uint256 i = 0; i < n; i++) {
            pools[i] = _deployMockPool(i + 200);
            // Each pool has a unique address; uniqueness is by address
            _addPool(pools[i], tokenA, tokenB, DEX_UNISWAP_V3, "pair");
        }

        uint256 removeIdx = seed % n;
        _removePool(pools[removeIdx]);
        assertEq(registry.getPoolCount(), n - 1);
        assertFalse(registry.isPoolRegistered(pools[removeIdx]));
    }

    // ═════════════════════════════════════════════════════════════════
    //                  FUZZ — pair query symmetry
    // ═════════════════════════════════════════════════════════════════

    /// @notice Querying with reversed token order should always give same results
    function testFuzz_pairQuerySymmetry(address tA, address tB) public {
        tA = _boundAddress(tA);
        tB = _boundAddress(tB);
        vm.assume(tA != tB);

        address p = _deployMockPool(999);
        _addPool(p, tA, tB, DEX_UNISWAP_V3, "pair");

        // Both orderings should return same result
        address[] memory forward = registry.getPoolsForPair(tA, tB);
        address[] memory reverse = registry.getPoolsForPair(tB, tA);
        assertEq(forward.length, reverse.length);
        assertEq(forward[0], reverse[0]);
    }
}
