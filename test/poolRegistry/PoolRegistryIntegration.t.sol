// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.20;

import { PoolRegistryTestBase } from "./PoolRegistryTestBase.sol";
import { PoolRegistry } from "src/liquidityPoolRegistry/PoolRegistry.sol";
import { IPoolRegistry } from "src/interfaces/IPoolRegistry.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Integration tests for PoolRegistry
/// @notice Tests that verify the registry works correctly in realistic scenarios
contract PoolRegistryIntegrationTest is PoolRegistryTestBase {
    function setUp() public override {
        super.setUp();
    }

    // =============================================================
    // MULTI-DEX SCENARIOS
    // =============================================================

    /// @notice Test managing pools from multiple DEXes
    function test_MultiDexPoolManagement() public {
        // Add pools from different DEXes
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        addPool(pool2, PAIR_NAME_ETH_USDC, DEX_SUSHISWAP);
        addPool(pool3, PAIR_NAME_ETH_USDC, DEX_CURVE);

        // Verify all pools are registered with correct DEX IDs
        IPoolRegistry.PoolInfo memory poolInfo1 = registry.poolDetails(pool1);
        IPoolRegistry.PoolInfo memory poolInfo2 = registry.poolDetails(pool2);
        IPoolRegistry.PoolInfo memory poolInfo3 = registry.poolDetails(pool3);

        assertEq(poolInfo1.pairName, PAIR_NAME_ETH_USDC);
        assertEq(poolInfo2.pairName, PAIR_NAME_ETH_USDC);
        assertEq(poolInfo3.pairName, PAIR_NAME_ETH_USDC);

        assertEq(poolInfo1.protocolId, bytes32(bytes(DEX_UNISWAP)));
        assertEq(poolInfo2.protocolId, bytes32(bytes(DEX_SUSHISWAP)));
        assertEq(poolInfo3.protocolId, bytes32(bytes(DEX_CURVE)));

        // Verify all are registered
        assertTrue(registry.isPoolRegistered(pool1));
        assertTrue(registry.isPoolRegistered(pool2));
        assertTrue(registry.isPoolRegistered(pool3));

        address[] memory pools = registry.poolAddresses();
        assertEq(pools.length, 3);
    }

    /// @notice Test same pair on different DEXes with different pools
    function test_SamePairDifferentDexes() public {
        // Add ETH/USDC pools from multiple DEXes
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        addPool(pool2, PAIR_NAME_ETH_USDC, DEX_SUSHISWAP);
        addPool(pool3, PAIR_NAME_ETH_USDC, DEX_CURVE);
        addPool(pool4, PAIR_NAME_ETH_USDC, DEX_BALANCER);

        address[] memory pools = registry.poolAddresses();
        assertEq(pools.length, 4);

        // Each should maintain its own DEX ID
        for (uint256 i = 0; i < pools.length; i++) {
            IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(pools[i]);
            assertEq(poolInfo.pairName, PAIR_NAME_ETH_USDC);
            assertTrue(poolInfo.protocolId != bytes32(0));
        }
    }

    // =============================================================
    // LIFECYCLE SCENARIOS
    // =============================================================

    /// @notice Test complete lifecycle of a liquidity pool
    function test_PoolLifecycle() public {
        // 1. Add pool
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        assertTrue(registry.isPoolRegistered(pool1));

        // 2. Query pool details
        IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(pool1);
        assertEq(poolInfo.pairName, PAIR_NAME_ETH_USDC);
        assertEq(poolInfo.protocolId, bytes32(bytes(DEX_UNISWAP)));

        // 3. Verify pool is in list
        address[] memory pools = registry.poolAddresses();
        bool found = false;
        for (uint256 i = 0; i < pools.length; i++) {
            if (pools[i] == pool1) {
                found = true;
                break;
            }
        }
        assertTrue(found);

        // 4. Remove pool
        removePool(pool1);
        assertFalse(registry.isPoolRegistered(pool1));

        // 5. Verify pool details are cleared
        IPoolRegistry.PoolInfo memory poolInfoAfter = registry.poolDetails(pool1);
        assertEq(poolInfoAfter.pairName, "");
        assertEq(poolInfoAfter.protocolId, bytes32(0));

        // 6. Verify pool is not in list
        address[] memory poolsAfter = registry.poolAddresses();
        for (uint256 i = 0; i < poolsAfter.length; i++) {
            assertTrue(poolsAfter[i] != pool1);
        }
    }

    /// @notice Test pool migration scenario (remove old, add new)
    function test_PoolMigration() public {
        // Initial pool
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        assertTrue(registry.isPoolRegistered(pool1));

        // Migrate to new pool address
        removePool(pool1);
        addPool(pool2, PAIR_NAME_ETH_USDC, DEX_UNISWAP);

        // Verify old pool is gone
        assertFalse(registry.isPoolRegistered(pool1));

        // Verify new pool is registered
        assertTrue(registry.isPoolRegistered(pool2));
        IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(pool2);
        assertEq(poolInfo.pairName, PAIR_NAME_ETH_USDC);
        assertEq(poolInfo.protocolId, bytes32(bytes(DEX_UNISWAP)));
    }

    /// @notice Test upgrading pool to new version
    function test_PoolUpgrade() public {
        // Add v1 pool
        addPool(pool1, "ETH/USDC-v1", DEX_UNISWAP);
        assertTrue(registry.isPoolRegistered(pool1));

        // Remove v1 and add v2
        removePool(pool1);
        addPool(pool2, "ETH/USDC-v2", DEX_UNISWAP);

        // Verify upgrade
        assertFalse(registry.isPoolRegistered(pool1));
        assertTrue(registry.isPoolRegistered(pool2));

        IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(pool2);
        assertEq(poolInfo.pairName, "ETH/USDC-v2");
        assertEq(poolInfo.protocolId, bytes32(bytes(DEX_UNISWAP)));
    }

    // =============================================================
    // MULTIPLE USER SCENARIOS
    // =============================================================

    /// @notice Test ownership transfer and continued operations
    function test_OwnershipTransferContinuedOperations() public {
        // Original owner adds pool
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        assertTrue(registry.isPoolRegistered(pool1));

        // Transfer ownership
        address newOwner = makeAddr("newOwner");
        vm.prank(owner);
        registry.transferOwnership(newOwner);

        // New owner adds another pool
        vm.prank(newOwner);
        registry.addPool(pool2, bytes32(bytes(DEX_SUSHISWAP)), PAIR_NAME_WBTC_ETH);

        // Verify both pools exist
        assertTrue(registry.isPoolRegistered(pool1));
        assertTrue(registry.isPoolRegistered(pool2));

        // New owner can remove old owner's pool
        vm.prank(newOwner);
        registry.removePool(pool1);
        assertFalse(registry.isPoolRegistered(pool1));
    }

    // =============================================================
    // BULK OPERATIONS
    // =============================================================

    /// @notice Test bulk pool addition
    function test_BulkPoolAddition() public {
        address[5] memory pools = [pool1, pool2, pool3, pool4, pool5];
        string[5] memory pairNames =
            [PAIR_NAME_ETH_USDC, PAIR_NAME_WBTC_ETH, PAIR_NAME_DAI_USDC, PAIR_NAME_USDT_USDC, PAIR_NAME_ARB_ETH];
        string[5] memory dexIds = [DEX_UNISWAP, DEX_SUSHISWAP, DEX_CURVE, DEX_BALANCER, DEX_UNISWAP];

        // Add all pools
        for (uint256 i = 0; i < 5; i++) {
            addPool(pools[i], pairNames[i], dexIds[i]);
        }

        // Verify all pools are registered
        address[] memory registeredPools = registry.poolAddresses();
        assertEq(registeredPools.length, 5);

        for (uint256 i = 0; i < 5; i++) {
            assertTrue(registry.isPoolRegistered(pools[i]));
            IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(pools[i]);
            assertEq(poolInfo.pairName, pairNames[i]);
            assertEq(poolInfo.protocolId, bytes32(bytes(dexIds[i])));
        }
    }

    /// @notice Test bulk pool removal
    function test_BulkPoolRemoval() public {
        // Add multiple pools
        addMultiplePools(5);

        address[] memory poolsToRemove = new address[](3);
        poolsToRemove[0] = pool1;
        poolsToRemove[1] = pool3;
        poolsToRemove[2] = pool5;

        // Remove multiple pools
        for (uint256 i = 0; i < poolsToRemove.length; i++) {
            removePool(poolsToRemove[i]);
        }

        // Verify removed pools are gone
        assertFalse(registry.isPoolRegistered(pool1));
        assertFalse(registry.isPoolRegistered(pool3));
        assertFalse(registry.isPoolRegistered(pool5));

        // Verify remaining pools still exist
        assertTrue(registry.isPoolRegistered(pool2));
        assertTrue(registry.isPoolRegistered(pool4));

        address[] memory remainingPools = registry.poolAddresses();
        assertEq(remainingPools.length, 2);
    }

    /// @notice Test interleaved add and remove operations
    function test_InterleavedOperations() public {
        // Add pool 1
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);

        // Add pool 2
        addPool(pool2, PAIR_NAME_WBTC_ETH, DEX_SUSHISWAP);

        // Remove pool 1
        removePool(pool1);

        // Add pool 3
        addPool(pool3, PAIR_NAME_DAI_USDC, DEX_CURVE);

        // Add pool 4
        addPool(pool4, PAIR_NAME_USDT_USDC, DEX_BALANCER);

        // Remove pool 2
        removePool(pool2);

        // Final state: pools 3 and 4 should exist
        assertFalse(registry.isPoolRegistered(pool1));
        assertFalse(registry.isPoolRegistered(pool2));
        assertTrue(registry.isPoolRegistered(pool3));
        assertTrue(registry.isPoolRegistered(pool4));

        address[] memory pools = registry.poolAddresses();
        assertEq(pools.length, 2);
    }

    // =============================================================
    // REAL-WORLD SCENARIOS
    // =============================================================

    /// @notice Test DEX aggregator scenario with multiple pools
    function test_DexAggregatorScenario() public {
        // Simulate a DEX aggregator managing multiple pools
        // Add ETH/USDC pools from different DEXes
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        addPool(pool2, PAIR_NAME_ETH_USDC, DEX_SUSHISWAP);
        addPool(pool3, PAIR_NAME_ETH_USDC, DEX_CURVE);

        // Add WBTC/ETH pools
        address wbtcPool1 = makeAddr("wbtcPool1");
        address wbtcPool2 = makeAddr("wbtcPool2");
        addPool(wbtcPool1, PAIR_NAME_WBTC_ETH, DEX_UNISWAP);
        addPool(wbtcPool2, PAIR_NAME_WBTC_ETH, DEX_SUSHISWAP);

        // Verify we can query all pools
        address[] memory allPools = registry.poolAddresses();
        assertEq(allPools.length, 5);

        // Verify we can identify pools by pair
        uint256 ethUsdcCount = 0;
        uint256 wbtcEthCount = 0;

        for (uint256 i = 0; i < allPools.length; i++) {
            IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(allPools[i]);
            if (keccak256(bytes(poolInfo.pairName)) == keccak256(bytes(PAIR_NAME_ETH_USDC))) {
                ethUsdcCount++;
            } else if (keccak256(bytes(poolInfo.pairName)) == keccak256(bytes(PAIR_NAME_WBTC_ETH))) {
                wbtcEthCount++;
            }
        }

        assertEq(ethUsdcCount, 3);
        assertEq(wbtcEthCount, 2);
    }

    /// @notice Test pool registry with protocol upgrade
    function test_ProtocolUpgradeScenario() public {
        // Phase 1: Add pools
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        addPool(pool2, PAIR_NAME_WBTC_ETH, DEX_SUSHISWAP);

        address[] memory poolsPhase1 = registry.poolAddresses();
        assertEq(poolsPhase1.length, 2);

        // Phase 3: Continue operations (upgrade testing moved to dedicated file)
        addPool(pool3, PAIR_NAME_DAI_USDC, DEX_CURVE);

        address[] memory poolsPhase3 = registry.poolAddresses();
        assertEq(poolsPhase3.length, 3);
    }

    /// @notice Test emergency pool removal scenario
    function test_EmergencyPoolRemovalScenario() public {
        // Add multiple pools
        addMultiplePools(5);

        // Emergency: Remove all pools from a specific DEX
        address[] memory allPools = registry.poolAddresses();
        for (uint256 i = 0; i < allPools.length; i++) {
            IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(allPools[i]);
            if (poolInfo.protocolId == bytes32(bytes(DEX_UNISWAP))) {
                removePool(allPools[i]);
            }
        }

        // Verify all Uniswap pools are removed
        address[] memory remainingPools = registry.poolAddresses();
        for (uint256 i = 0; i < remainingPools.length; i++) {
            IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(remainingPools[i]);
            assertTrue(poolInfo.protocolId != bytes32(bytes(DEX_UNISWAP)));
        }
    }

    // =============================================================
    // COMPLEX STATE MANAGEMENT
    // =============================================================

    /// @notice Test registry with continuous churn
    function test_ContinuousChurn() public {
        // Simulate continuous pool additions and removals
        for (uint256 cycle = 0; cycle < 3; cycle++) {
            // Add pools
            for (uint256 i = 0; i < 5; i++) {
                address newPool = address(uint160(1000 + cycle * 10 + i));
                vm.prank(owner);
                registry.addPool(newPool, bytes32(bytes(DEX_UNISWAP)), PAIR_NAME_ETH_USDC);
            }

            // Remove some pools
            for (uint256 i = 0; i < 2; i++) {
                address poolToRemove = address(uint160(1000 + cycle * 10 + i));
                vm.prank(owner);
                registry.removePool(poolToRemove);
            }
        }

        // Verify final state is consistent
        address[] memory finalPools = registry.poolAddresses();

        // Should have 9 pools (3 cycles * 3 net additions per cycle)
        assertEq(finalPools.length, 9);

        // All pools should be registered and have valid data
        for (uint256 i = 0; i < finalPools.length; i++) {
            assertTrue(registry.isPoolRegistered(finalPools[i]));
            IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(finalPools[i]);
            assertTrue(bytes(poolInfo.pairName).length > 0);
            assertTrue(poolInfo.protocolId != bytes32(0));
        }
    }

    /// @notice Test large-scale pool management
    function test_LargeScalePoolManagement() public {
        // Add 50 pools
        for (uint256 i = 0; i < 50; i++) {
            address newPool = address(uint160(2000 + i));
            string memory pairName = i % 2 == 0 ? PAIR_NAME_ETH_USDC : PAIR_NAME_WBTC_ETH;
            string memory dexId = i % 3 == 0 ? DEX_UNISWAP : i % 3 == 1 ? DEX_SUSHISWAP : DEX_CURVE;

            vm.prank(owner);
            registry.addPool(newPool, bytes32(bytes(dexId)), pairName);
        }

        address[] memory allPools = registry.poolAddresses();
        assertEq(allPools.length, 50);

        // Verify all pools are properly registered
        for (uint256 i = 0; i < allPools.length; i++) {
            assertTrue(registry.isPoolRegistered(allPools[i]));
        }

        // Remove half of them
        for (uint256 i = 0; i < 25; i++) {
            address poolToRemove = address(uint160(2000 + i * 2));
            vm.prank(owner);
            registry.removePool(poolToRemove);
        }

        address[] memory remainingPools = registry.poolAddresses();
        assertEq(remainingPools.length, 25);
    }

    // =============================================================
    // QUERY PATTERN TESTS
    // =============================================================

    /// @notice Test common query patterns
    function test_CommonQueryPatterns() public {
        // Setup diverse pool set
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        addPool(pool2, PAIR_NAME_ETH_USDC, DEX_SUSHISWAP);
        addPool(pool3, PAIR_NAME_WBTC_ETH, DEX_UNISWAP);
        addPool(pool4, PAIR_NAME_DAI_USDC, DEX_CURVE);

        address[] memory allPools = registry.poolAddresses();

        // Pattern 1: Find all pools for a specific pair
        uint256 ethUsdcCount = 0;
        for (uint256 i = 0; i < allPools.length; i++) {
            IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(allPools[i]);
            if (keccak256(bytes(poolInfo.pairName)) == keccak256(bytes(PAIR_NAME_ETH_USDC))) {
                ethUsdcCount++;
            }
        }
        assertEq(ethUsdcCount, 2);

        // Pattern 2: Find all pools for a specific DEX
        uint256 uniswapCount = 0;
        for (uint256 i = 0; i < allPools.length; i++) {
            IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(allPools[i]);
            if (poolInfo.protocolId == bytes32(bytes(DEX_UNISWAP))) {
                uniswapCount++;
            }
        }
        assertEq(uniswapCount, 2);

        // Pattern 3: Check if specific pool exists
        assertTrue(registry.isPoolRegistered(pool1));
        assertTrue(registry.isPoolRegistered(pool2));
        assertTrue(registry.isPoolRegistered(pool3));
        assertTrue(registry.isPoolRegistered(pool4));
    }

    /// @notice Test integration with proxy admin
    /// Note: Upgrade functionality moved to PoolRegistryUpgrade.t.sol
    function test_ProxyAdminIntegration() public {
        // Add pool through normal owner
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);

        // Verify proxy admin is separate from registry owner
        assertTrue(address(registryProxyAdmin) != owner);

        // Registry owner can manage pools
        assertTrue(registry.isPoolRegistered(pool1));

        // Verify pool operations work correctly
        addPool(pool2, PAIR_NAME_WBTC_ETH, DEX_SUSHISWAP);
        assertTrue(registry.isPoolRegistered(pool2));
    }
}
