// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.20;

import { PoolRegistryTestBase } from "./PoolRegistryTestBase.sol";
import { PoolRegistry } from "src/liquidityPoolRegistry/PoolRegistry.sol";
import { IPoolRegistry } from "src/interfaces/IPoolRegistry.sol";

/// @title Tests for PoolRegistry removePool functionality
contract PoolRegistryRemovePoolTest is PoolRegistryTestBase {
    function setUp() public override {
        super.setUp();

        // Setup initial state with multiple pools
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        addPool(pool2, PAIR_NAME_WBTC_ETH, DEX_SUSHISWAP);
        addPool(pool3, PAIR_NAME_DAI_USDC, DEX_CURVE);
    }

    // =============================================================
    // REMOVE POOL TESTS
    // =============================================================

    /// @notice Test removing a single pool
    function test_RemoveSinglePool() public {
        assertTrue(registry.isPoolRegistered(pool1));

        removePool(pool1);

        assertPoolRemoved(pool1);
    }

    /// @notice Test removing multiple pools
    function test_RemoveMultiplePools() public {
        assertTrue(registry.isPoolRegistered(pool1));
        assertTrue(registry.isPoolRegistered(pool2));

        removePool(pool1);
        removePool(pool2);

        assertPoolRemoved(pool1);
        assertPoolRemoved(pool2);
        assertTrue(registry.isPoolRegistered(pool3));
    }

    /// @notice Test removing all pools
    function test_RemoveAllPools() public {
        removePool(pool1);
        removePool(pool2);
        removePool(pool3);

        assertPoolRemoved(pool1);
        assertPoolRemoved(pool2);
        assertPoolRemoved(pool3);

        address[] memory pools = registry.poolAddresses();
        assertEq(pools.length, 0);
    }

    /// @notice Test removing pool updates poolAddresses array
    function test_RemovePoolUpdatesPoolAddressesArray() public {
        address[] memory poolsBefore = registry.poolAddresses();
        uint256 lengthBefore = poolsBefore.length;
        assertEq(lengthBefore, 3);

        removePool(pool1);

        address[] memory poolsAfter = registry.poolAddresses();
        assertEq(poolsAfter.length, lengthBefore - 1);

        // Verify pool1 is not in array
        for (uint256 i = 0; i < poolsAfter.length; i++) {
            assertTrue(poolsAfter[i] != pool1);
        }
    }

    /// @notice Test removing pool updates isPoolRegistered
    function test_RemovePoolUpdatesIsPoolRegistered() public {
        assertTrue(registry.isPoolRegistered(pool1));

        removePool(pool1);

        assertFalse(registry.isPoolRegistered(pool1));
    }

    /// @notice Test removing pool clears poolDetails
    function test_RemovePoolClearsPoolDetails() public {
        IPoolRegistry.PoolInfo memory poolInfoBefore = registry.poolDetails(pool1);
        assertTrue(bytes(poolInfoBefore.pairName).length > 0);
        assertTrue(poolInfoBefore.protocolId != bytes32(0));

        removePool(pool1);

        IPoolRegistry.PoolInfo memory poolInfoAfter = registry.poolDetails(pool1);
        assertEq(poolInfoAfter.pairName, "");
        assertEq(poolInfoAfter.protocolId, bytes32(0));
    }

    /// @notice Test removing pool from middle of array
    function test_RemovePoolFromMiddle() public {
        // Add more pools to have a larger array
        addPool(pool4, PAIR_NAME_USDT_USDC, DEX_BALANCER);
        addPool(pool5, PAIR_NAME_ARB_ETH, DEX_UNISWAP);

        address[] memory poolsBefore = registry.poolAddresses();
        assertEq(poolsBefore.length, 5);

        // Remove pool in the middle (pool2)
        removePool(pool2);

        address[] memory poolsAfter = registry.poolAddresses();
        assertEq(poolsAfter.length, 4);

        // Verify pool2 is removed and others remain
        assertFalse(registry.isPoolRegistered(pool2));
        assertTrue(registry.isPoolRegistered(pool1));
        assertTrue(registry.isPoolRegistered(pool3));
        assertTrue(registry.isPoolRegistered(pool4));
        assertTrue(registry.isPoolRegistered(pool5));
    }

    /// @notice Test removing first pool in array
    function test_RemoveFirstPool() public {
        address[] memory poolsBefore = registry.poolAddresses();
        address firstPool = poolsBefore[0];

        removePool(firstPool);

        address[] memory poolsAfter = registry.poolAddresses();
        assertEq(poolsAfter.length, poolsBefore.length - 1);
        assertFalse(registry.isPoolRegistered(firstPool));
    }

    /// @notice Test removing last pool in array
    function test_RemoveLastPool() public {
        address[] memory poolsBefore = registry.poolAddresses();
        address lastPool = poolsBefore[poolsBefore.length - 1];

        removePool(lastPool);

        address[] memory poolsAfter = registry.poolAddresses();
        assertEq(poolsAfter.length, poolsBefore.length - 1);
        assertFalse(registry.isPoolRegistered(lastPool));
    }

    /// @notice Test removing pools in sequence
    function test_RemovePoolsInSequence() public {
        address[] memory initialPools = registry.poolAddresses();
        uint256 initialLength = initialPools.length;

        for (uint256 i = 0; i < initialLength; i++) {
            address poolToRemove = initialPools[i];
            removePool(poolToRemove);

            address[] memory currentPools = registry.poolAddresses();
            assertEq(currentPools.length, initialLength - i - 1);
            assertFalse(registry.isPoolRegistered(poolToRemove));
        }

        address[] memory finalPools = registry.poolAddresses();
        assertEq(finalPools.length, 0);
    }

    /// @notice Test removing pool doesn't affect other pools
    function test_RemovePoolDoesntAffectOtherPools() public {
        IPoolRegistry.PoolInfo memory poolInfo2Before = registry.poolDetails(pool2);
        IPoolRegistry.PoolInfo memory poolInfo3Before = registry.poolDetails(pool3);

        removePool(pool1);

        // Verify pool2 and pool3 are unchanged
        IPoolRegistry.PoolInfo memory poolInfo2After = registry.poolDetails(pool2);
        IPoolRegistry.PoolInfo memory poolInfo3After = registry.poolDetails(pool3);

        assertEq(poolInfo2After.pairName, poolInfo2Before.pairName);
        assertEq(poolInfo2After.protocolId, poolInfo2Before.protocolId);
        assertEq(poolInfo3After.pairName, poolInfo3Before.pairName);
        assertEq(poolInfo3After.protocolId, poolInfo3Before.protocolId);

        assertTrue(registry.isPoolRegistered(pool2));
        assertTrue(registry.isPoolRegistered(pool3));
    }

    /// @notice Test removing and re-adding a pool
    function test_RemoveAndReAddPool() public {
        removePool(pool1);
        assertPoolRemoved(pool1);

        // Re-add the same pool
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        assertPoolAdded(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
    }

    /// @notice Test removing and re-adding with different details
    function test_RemoveAndReAddPoolWithDifferentDetails() public {
        removePool(pool1);
        assertPoolRemoved(pool1);

        // Re-add with different details
        addPool(pool1, PAIR_NAME_WBTC_ETH, DEX_SUSHISWAP);
        assertPoolAdded(pool1, PAIR_NAME_WBTC_ETH, DEX_SUSHISWAP);

        IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(pool1);
        assertEq(poolInfo.pairName, PAIR_NAME_WBTC_ETH);
        assertEq(poolInfo.protocolId, bytes32(bytes(DEX_SUSHISWAP)));
    }

    /// @notice Test multiple remove operations
    function test_MultipleRemoveOperations() public {
        // Add more pools
        addPool(pool4, PAIR_NAME_USDT_USDC, DEX_BALANCER);
        addPool(pool5, PAIR_NAME_ARB_ETH, DEX_UNISWAP);

        address[] memory poolsBefore = registry.poolAddresses();
        assertEq(poolsBefore.length, 5);

        // Remove in random order
        removePool(pool3);
        removePool(pool1);
        removePool(pool5);

        address[] memory poolsAfter = registry.poolAddresses();
        assertEq(poolsAfter.length, 2);

        // Verify remaining pools
        assertTrue(registry.isPoolRegistered(pool2));
        assertTrue(registry.isPoolRegistered(pool4));

        // Verify removed pools
        assertFalse(registry.isPoolRegistered(pool1));
        assertFalse(registry.isPoolRegistered(pool3));
        assertFalse(registry.isPoolRegistered(pool5));
    }

    /// @notice Test swap-and-pop removal pattern preserves pool data
    function test_SwapAndPopPreservesPoolData() public {
        // Add more pools to test swap-and-pop
        addPool(pool4, PAIR_NAME_USDT_USDC, DEX_BALANCER);
        addPool(pool5, PAIR_NAME_ARB_ETH, DEX_UNISWAP);

        // Get all pool details before removal
        IPoolRegistry.PoolInfo memory poolInfo2 = registry.poolDetails(pool2);
        IPoolRegistry.PoolInfo memory poolInfo3 = registry.poolDetails(pool3);
        IPoolRegistry.PoolInfo memory poolInfo4 = registry.poolDetails(pool4);
        IPoolRegistry.PoolInfo memory poolInfo5 = registry.poolDetails(pool5);

        // Remove pool1
        removePool(pool1);

        // Verify all other pools' data is preserved
        IPoolRegistry.PoolInfo memory poolInfo2After = registry.poolDetails(pool2);
        IPoolRegistry.PoolInfo memory poolInfo3After = registry.poolDetails(pool3);
        IPoolRegistry.PoolInfo memory poolInfo4After = registry.poolDetails(pool4);
        IPoolRegistry.PoolInfo memory poolInfo5After = registry.poolDetails(pool5);

        assertEq(poolInfo2After.pairName, poolInfo2.pairName);
        assertEq(poolInfo2After.protocolId, poolInfo2.protocolId);
        assertEq(poolInfo3After.pairName, poolInfo3.pairName);
        assertEq(poolInfo3After.protocolId, poolInfo3.protocolId);
        assertEq(poolInfo4After.pairName, poolInfo4.pairName);
        assertEq(poolInfo4After.protocolId, poolInfo4.protocolId);
        assertEq(poolInfo5After.pairName, poolInfo5.pairName);
        assertEq(poolInfo5After.protocolId, poolInfo5.protocolId);
    }

    /// @notice Test removing pool clears all storage
    function test_RemovePoolClearsAllStorage() public {
        removePool(pool1);

        // Verify pool is not registered
        assertFalse(registry.isPoolRegistered(pool1));

        // Verify details are cleared
        IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(pool1);
        assertEq(bytes(poolInfo.pairName).length, 0);
        assertEq(poolInfo.protocolId, bytes32(0));

        // Verify not in array
        address[] memory pools = registry.poolAddresses();
        for (uint256 i = 0; i < pools.length; i++) {
            assertTrue(pools[i] != pool1);
        }
    }

    // =============================================================
    // REVERT TESTS - REMOVE POOL
    // =============================================================

    /// @notice Test removing pool reverts when not owner
    function test_RevertIf_RemovePoolWhenNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        registry.removePool(pool1);
    }

    /// @notice Test removing non-existent pool reverts
    function test_RevertIf_RemoveNonExistentPool() public {
        address nonExistentPool = makeAddr("nonExistentPool");

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_PoolDoesNotExist(), nonExistentPool));
        registry.removePool(nonExistentPool);
    }

    /// @notice Test removing already removed pool reverts
    function test_RevertIf_RemoveAlreadyRemovedPool() public {
        removePool(pool1);

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_PoolDoesNotExist(), pool1));
        registry.removePool(pool1);
    }

    /// @notice Test removing pool with zero address reverts
    function test_RevertIf_RemoveZeroAddressPool() public {
        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_PoolDoesNotExist(), address(0)));
        registry.removePool(address(0));
    }

    /// @notice Test non-owner cannot remove pool
    function test_RevertIf_NonOwnerRemovesPool() public {
        vm.prank(user1);
        vm.expectRevert();
        registry.removePool(pool1);

        vm.prank(user2);
        vm.expectRevert();
        registry.removePool(pool2);

        // Verify pools still exist
        assertTrue(registry.isPoolRegistered(pool1));
        assertTrue(registry.isPoolRegistered(pool2));
    }

    /// @notice Test that pool is not removed when transaction reverts
    function test_PoolNotRemovedWhenReverts() public {
        address nonExistentPool = makeAddr("nonExistentPool");

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_PoolDoesNotExist(), nonExistentPool));
        registry.removePool(nonExistentPool);

        // Verify existing pools are still there
        assertTrue(registry.isPoolRegistered(pool1));
        assertTrue(registry.isPoolRegistered(pool2));
        assertTrue(registry.isPoolRegistered(pool3));
    }

    /// @notice Test ownership protection
    function test_OnlyOwnerCanRemovePools() public {
        address randomUser = makeAddr("randomUser");

        vm.prank(randomUser);
        vm.expectRevert();
        registry.removePool(pool1);

        // Owner should be able to remove
        removePool(pool1);
        assertFalse(registry.isPoolRegistered(pool1));
    }

    /// @notice Test removing same pool twice fails
    function test_RemovingSamePoolTwiceFails() public {
        removePool(pool1);
        assertFalse(registry.isPoolRegistered(pool1));

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_PoolDoesNotExist(), pool1));
        registry.removePool(pool1);
    }

    // =============================================================
    // FUZZ TESTS
    // =============================================================

    /// @notice Fuzz test removing pools with random addresses
    function testFuzz_RemoveNonExistentPoolReverts(address poolAddress) public {
        // Skip pools that we've added
        vm.assume(poolAddress != pool1);
        vm.assume(poolAddress != pool2);
        vm.assume(poolAddress != pool3);

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_PoolDoesNotExist(), poolAddress));
        registry.removePool(poolAddress);
    }

    /// @notice Fuzz test add and remove operations
    function testFuzz_AddAndRemovePool(address poolAddress) public {
        // Skip zero address and already used pools
        vm.assume(poolAddress != address(0));
        vm.assume(poolAddress != pool1);
        vm.assume(poolAddress != pool2);
        vm.assume(poolAddress != pool3);

        // Add pool
        addPool(poolAddress, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        assertTrue(registry.isPoolRegistered(poolAddress));

        // Remove pool
        removePool(poolAddress);
        assertFalse(registry.isPoolRegistered(poolAddress));
    }
}
