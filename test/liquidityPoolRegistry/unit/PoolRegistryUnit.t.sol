// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { PoolRegistryTestBase } from "../PoolRegistryTestBase.sol";
import { LiquidityPoolRegistry } from "src/liquidityPoolRegistry/LiquidityPoolRegistry.sol";
import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";

contract PoolRegistryUnitTest is PoolRegistryTestBase {
    // ═════════════════════════════════════════════════════════════════
    //                     CONSTRUCTOR
    // ═════════════════════════════════════════════════════════════════

    function test_constructor_setsOwner() public view {
        assertEq(registry.owner(), owner);
    }

    function test_constructor_startsEmpty() public view {
        assertEq(registry.getPoolCount(), 0);
        assertEq(registry.getAllPools().length, 0);
        assertEq(registry.getAllPairIds().length, 0);
    }

    function test_constructor_revertsOnZeroOwner() public {
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableInvalidOwner(address)")), address(0)));
        new LiquidityPoolRegistry(address(0));
    }

    // ═════════════════════════════════════════════════════════════════
    //                     addPool — SUCCESS
    // ═════════════════════════════════════════════════════════════════

    function test_addPool_registersPool() public {
        _addDefaultPool();
        assertTrue(registry.isPoolRegistered(pool1));
        assertEq(registry.getPoolCount(), 1);
    }

    function test_addPool_storesCorrectPoolInfo() public {
        _addPool(pool1, tokenB, tokenA, DEX_UNISWAP_V3, "TOKENA/TOKENB", FEE_MEDIUM);

        ILiquidityPoolRegistry.PoolInfo memory info = registry.getPool(pool1);
        assertEq(info.poolAddress, pool1);
        assertEq(info.dexId, DEX_UNISWAP_V3);
        assertEq(info.swapFee, FEE_MEDIUM);
        // Tokens should be sorted: tokenA < tokenB
        assertEq(info.token0, tokenA);
        assertEq(info.token1, tokenB);
    }

    function test_addPool_sortsTokensCanonically() public {
        // Pass tokenB first, tokenA second — should still store as (tokenA, tokenB)
        _addPool(pool1, tokenB, tokenA, DEX_UNISWAP_V3, "B/A", FEE_MEDIUM);
        ILiquidityPoolRegistry.PoolInfo memory info = registry.getPool(pool1);
        assertTrue(info.token0 < info.token1);
    }

    function test_addPool_emitsPoolAdded() public {
        bytes32 expectedPairId = _computePairId(tokenA, tokenB);
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit ILiquidityPoolRegistry.PoolAdded(pool1, expectedPairId, DEX_UNISWAP_V3, tokenA, tokenB, FEE_MEDIUM);
        registry.addPool(_params(pool1, tokenA, tokenB, DEX_UNISWAP_V3, "TOKENA/TOKENB", FEE_MEDIUM));
    }

    function test_addPool_tracksPairId() public {
        _addDefaultPool();
        bytes32[] memory pairIds = registry.getAllPairIds();
        assertEq(pairIds.length, 1);
        assertEq(pairIds[0], _computePairId(tokenA, tokenB));
    }

    function test_addPool_multiplePools() public {
        _addPool(pool1, tokenA, tokenB, DEX_UNISWAP_V3, "A/B V3", FEE_MEDIUM);
        _addPool(pool2, tokenA, tokenB, DEX_UNISWAP_V2, "A/B V2", FEE_MEDIUM);
        _addPool(pool3, tokenC, tokenD, DEX_UNISWAP_V3, "C/D V3", FEE_LOW);

        assertEq(registry.getPoolCount(), 3);
        assertEq(registry.getAllPairIds().length, 2); // 2 unique pairs
    }

    function test_addPool_samePairDifferentFees() public {
        _addPool(pool1, tokenA, tokenB, DEX_UNISWAP_V3, "A/B low", FEE_LOW);
        _addPool(pool2, tokenA, tokenB, DEX_UNISWAP_V3, "A/B med", FEE_MEDIUM);
        _addPool(pool3, tokenA, tokenB, DEX_UNISWAP_V3, "A/B high", FEE_HIGH);

        assertEq(registry.getPoolCount(), 3);
        assertEq(registry.getPoolsForPair(tokenA, tokenB).length, 3);
    }

    // ═════════════════════════════════════════════════════════════════
    //                     addPool — REVERTS
    // ═════════════════════════════════════════════════════════════════

    function test_addPool_revertsOnZeroPoolAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("LiquidityPoolRegistry_ZeroAddress()"));
        registry.addPool(_params(address(0), tokenA, tokenB, DEX_UNISWAP_V3, "A/B", FEE_MEDIUM));
    }

    function test_addPool_revertsOnZeroTokenA() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("LiquidityPoolRegistry_ZeroAddress()"));
        registry.addPool(_params(pool1, address(0), tokenB, DEX_UNISWAP_V3, "A/B", FEE_MEDIUM));
    }

    function test_addPool_revertsOnZeroTokenB() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("LiquidityPoolRegistry_ZeroAddress()"));
        registry.addPool(_params(pool1, tokenA, address(0), DEX_UNISWAP_V3, "A/B", FEE_MEDIUM));
    }

    function test_addPool_revertsOnIdenticalTokens() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("LiquidityPoolRegistry_IdenticalTokens()"));
        registry.addPool(_params(pool1, tokenA, tokenA, DEX_UNISWAP_V3, "A/A", FEE_MEDIUM));
    }

    function test_addPool_revertsOnUnregisteredDex() public {
        bytes32 unregisteredDex = keccak256("SUSHISWAP");
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("LiquidityPoolRegistry_DexDoesNotExist(bytes32)", unregisteredDex));
        registry.addPool(_params(pool1, tokenA, tokenB, unregisteredDex, "A/B", FEE_MEDIUM));
    }

    function test_addPool_revertsOnZeroDexId() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("LiquidityPoolRegistry_DexDoesNotExist(bytes32)", bytes32(0)));
        registry.addPool(_params(pool1, tokenA, tokenB, bytes32(0), "A/B", FEE_MEDIUM));
    }

    function test_addPool_revertsOnEmptyPairName() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("LiquidityPoolRegistry_EmptyPairName()"));
        registry.addPool(_params(pool1, tokenA, tokenB, DEX_UNISWAP_V3, "", FEE_MEDIUM));
    }

    function test_addPool_revertsOnPairNameTooLong() public {
        // 129 bytes — exceeds MAX_PAIR_NAME_LENGTH (128)
        bytes memory longName = new bytes(129);
        for (uint256 i = 0; i < 129; i++) {
            longName[i] = "X";
        }
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("LiquidityPoolRegistry_PairNameTooLong()"));
        registry.addPool(_params(pool1, tokenA, tokenB, DEX_UNISWAP_V3, string(longName), FEE_MEDIUM));
    }

    function test_addPool_revertsOnNonContract() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("LiquidityPoolRegistry_NotContract()"));
        registry.addPool(_params(address(0xDEAD), tokenA, tokenB, DEX_UNISWAP_V3, "A/B", FEE_MEDIUM));
    }

    function test_addPool_revertsOnDuplicatePool() public {
        _addDefaultPool();
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("LiquidityPoolRegistry_PoolAlreadyExists(address)")), pool1)
        );
        registry.addPool(_params(pool1, tokenA, tokenB, DEX_UNISWAP_V3, "dup", FEE_MEDIUM));
    }

    function test_addPool_revertsOnDuplicatePoolKey() public {
        _addPool(pool1, tokenA, tokenB, DEX_UNISWAP_V3, "first", FEE_MEDIUM);
        // Same pair, same dex, same fee — different pool address
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("LiquidityPoolRegistry_DuplicatePoolKey()"));
        registry.addPool(_params(pool2, tokenA, tokenB, DEX_UNISWAP_V3, "second", FEE_MEDIUM));
    }

    function test_addPool_revertsWhenNotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        registry.addPool(_params(pool1, tokenA, tokenB, DEX_UNISWAP_V3, "A/B", FEE_MEDIUM));
    }

    // ═════════════════════════════════════════════════════════════════
    //                     removePool — SUCCESS
    // ═════════════════════════════════════════════════════════════════

    function test_removePool_unregistersPool() public {
        _addDefaultPool();
        _removePool(pool1);
        assertFalse(registry.isPoolRegistered(pool1));
        assertEq(registry.getPoolCount(), 0);
    }

    function test_removePool_emitsPoolRemoved() public {
        _addDefaultPool();
        bytes32 pairId = _computePairId(tokenA, tokenB);
        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit ILiquidityPoolRegistry.PoolRemoved(pool1, pairId);
        registry.removePool(pool1);
    }

    function test_removePool_cleansPairIdWhenLastPoolForPair() public {
        _addDefaultPool();
        assertEq(registry.getAllPairIds().length, 1);
        _removePool(pool1);
        assertEq(registry.getAllPairIds().length, 0);
    }

    function test_removePool_keepsPairIdWhenOtherPoolsExist() public {
        _addPool(pool1, tokenA, tokenB, DEX_UNISWAP_V3, "A/B V3", FEE_MEDIUM);
        _addPool(pool2, tokenA, tokenB, DEX_UNISWAP_V2, "A/B V2", FEE_MEDIUM);
        _removePool(pool1);
        assertEq(registry.getAllPairIds().length, 1);
        assertEq(registry.getPoolsForPair(tokenA, tokenB).length, 1);
    }

    function test_removePool_removesFromDexTracking() public {
        _addDefaultPool();
        assertEq(registry.getPoolsByDex(DEX_UNISWAP_V3).length, 1);
        _removePool(pool1);
        assertEq(registry.getPoolsByDex(DEX_UNISWAP_V3).length, 0);
    }

    function test_removePool_allowsReAddingSameKeyAfterRemoval() public {
        _addDefaultPool();
        _removePool(pool1);
        // Same pool key (pair+dex+fee) should be available again
        _addPool(pool2, tokenA, tokenB, DEX_UNISWAP_V3, "readded", FEE_MEDIUM);
        assertTrue(registry.isPoolRegistered(pool2));
    }

    // ═════════════════════════════════════════════════════════════════
    //                     removePool — REVERTS
    // ═════════════════════════════════════════════════════════════════

    function test_removePool_revertsOnNonExistentPool() public {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("LiquidityPoolRegistry_PoolDoesNotExist(address)")), pool1)
        );
        registry.removePool(pool1);
    }

    function test_removePool_revertsWhenNotOwner() public {
        _addDefaultPool();
        vm.prank(nonOwner);
        vm.expectRevert();
        registry.removePool(pool1);
    }

    // ═════════════════════════════════════════════════════════════════
    //                     SINGLE POOL QUERIES
    // ═════════════════════════════════════════════════════════════════

    function test_getPool_revertsOnUnregistered() public {
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("LiquidityPoolRegistry_PoolDoesNotExist(address)")), pool1)
        );
        registry.getPool(pool1);
    }

    function test_getPoolSwapInfo_returnsInvalidForUnregistered() public view {
        (address t0, address t1, uint24 fee) = registry.getPoolSwapInfo(pool1);
        assertEq(t0, address(0));
        assertEq(t1, address(0));
        assertEq(fee, 0);
    }

    // ═════════════════════════════════════════════════════════════════
    //                     PAIR QUERIES
    // ═════════════════════════════════════════════════════════════════

    function test_getPoolsForPair_returnsAllPools() public {
        _addPool(pool1, tokenA, tokenB, DEX_UNISWAP_V3, "V3", FEE_MEDIUM);
        _addPool(pool2, tokenA, tokenB, DEX_UNISWAP_V2, "V2", FEE_MEDIUM);

        address[] memory pools = registry.getPoolsForPair(tokenA, tokenB);
        assertEq(pools.length, 2);
    }

    function test_getPoolsForPair_tokenOrderDoesntMatter() public {
        _addDefaultPool();
        // Query with reversed order
        address[] memory pools = registry.getPoolsForPair(tokenB, tokenA);
        assertEq(pools.length, 1);
        assertEq(pools[0], pool1);
    }

    function test_getPoolsForPair_emptyForUnknownPair() public view {
        assertEq(registry.getPoolsForPair(tokenA, tokenC).length, 0);
    }

    // ═════════════════════════════════════════════════════════════════
    //                     DEX QUERIES
    // ═════════════════════════════════════════════════════════════════

    function test_getPoolsByDex_returnsPoolsOnDex() public {
        _addPool(pool1, tokenA, tokenB, DEX_UNISWAP_V3, "V3", FEE_MEDIUM);
        _addPool(pool2, tokenC, tokenD, DEX_UNISWAP_V3, "V3-2", FEE_LOW);
        _addPool(pool3, tokenA, tokenB, DEX_UNISWAP_V2, "V2", FEE_MEDIUM);

        assertEq(registry.getPoolsByDex(DEX_UNISWAP_V3).length, 2);
        assertEq(registry.getPoolsByDex(DEX_UNISWAP_V2).length, 1);
    }

    function test_getPoolsByDex_revertsForUnknownDex() public {
        vm.expectRevert(
            abi.encodeWithSignature("LiquidityPoolRegistry_DexDoesNotExist(bytes32)", keccak256("NONEXISTENT"))
        );
        registry.getPoolsByDex(keccak256("NONEXISTENT"));
    }

    function test_getPoolsForPairOnDex_filtersCorrectly() public {
        _addPool(pool1, tokenA, tokenB, DEX_UNISWAP_V3, "V3", FEE_MEDIUM);
        _addPool(pool2, tokenA, tokenB, DEX_UNISWAP_V2, "V2", FEE_MEDIUM);

        address[] memory v3 = registry.getPoolsForPairOnDex(tokenA, tokenB, DEX_UNISWAP_V3);
        address[] memory v2 = registry.getPoolsForPairOnDex(tokenA, tokenB, DEX_UNISWAP_V2);

        assertEq(v3.length, 1);
        assertEq(v3[0], pool1);
        assertEq(v2.length, 1);
        assertEq(v2[0], pool2);
    }

    function test_getPoolsForPairOnDex_emptyForWrongDex() public {
        _addDefaultPool();
        assertEq(registry.getPoolsForPairOnDex(tokenA, tokenB, DEX_UNISWAP_V2).length, 0);
    }

    // ═════════════════════════════════════════════════════════════════
    //                     GLOBAL QUERIES
    // ═════════════════════════════════════════════════════════════════

    function test_getAllPools_returnsAllRegistered() public {
        _addPool(pool1, tokenA, tokenB, DEX_UNISWAP_V3, "A/B", FEE_MEDIUM);
        _addPool(pool2, tokenC, tokenD, DEX_UNISWAP_V2, "C/D", FEE_LOW);

        address[] memory all = registry.getAllPools();
        assertEq(all.length, 2);
    }

    function test_getAllPairIds_tracksUniquePairs() public {
        _addPool(pool1, tokenA, tokenB, DEX_UNISWAP_V3, "V3", FEE_MEDIUM);
        _addPool(pool2, tokenA, tokenB, DEX_UNISWAP_V2, "V2", FEE_MEDIUM);
        _addPool(pool3, tokenC, tokenD, DEX_UNISWAP_V3, "C/D", FEE_LOW);

        bytes32[] memory ids = registry.getAllPairIds();
        assertEq(ids.length, 2); // A/B and C/D
    }
}
