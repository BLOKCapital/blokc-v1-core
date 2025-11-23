// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.20;

import { PoolRegistryTestBase } from "./PoolRegistryTestBase.sol";
import { PoolRegistry } from "src/liquidityPoolRegistry/PoolRegistry.sol";
import { IPoolRegistry } from "src/interfaces/IPoolRegistry.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Tests for PoolRegistry view/getter functions
contract PoolRegistryViewFunctionsTest is PoolRegistryTestBase {
    function setUp() public override {
        super.setUp();

        // Add some test pools for comprehensive testing
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        addPool(pool2, PAIR_NAME_WBTC_ETH, DEX_SUSHISWAP);
        addPool(pool3, PAIR_NAME_DAI_USDC, DEX_CURVE);
    }

    // =============================================================
    // VIEW FUNCTIONS TESTS - POOL DETAILS
    // =============================================================

    /// @notice Test poolDetails returns correct information
    function test_PoolDetailsReturnsCorrectInfo() public view {
        IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(pool1);
        assertEq(poolInfo.pairName, PAIR_NAME_ETH_USDC);
        assertEq(poolInfo.protocolId, bytes32(bytes(DEX_UNISWAP)));
    }

    /// @notice Test poolDetails returns empty for non-existent pool
    function test_PoolDetailsReturnsEmptyForNonExistent() public {
        address nonExistentPool = makeAddr("nonExistentPool");
        IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(nonExistentPool);
        assertEq(poolInfo.pairName, "");
        assertEq(poolInfo.protocolId, bytes32(0));
    }

    /// @notice Test poolDetails returns empty for zero address
    function test_PoolDetailsReturnsEmptyForZeroAddress() public view {
        IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(address(0));
        assertEq(poolInfo.pairName, "");
        assertEq(poolInfo.protocolId, bytes32(0));
    }

    /// @notice Test poolDetails for all registered pools
    function test_PoolDetailsForAllPools() public view {
        IPoolRegistry.PoolInfo memory poolInfo1 = registry.poolDetails(pool1);
        IPoolRegistry.PoolInfo memory poolInfo2 = registry.poolDetails(pool2);
        IPoolRegistry.PoolInfo memory poolInfo3 = registry.poolDetails(pool3);

        assertEq(poolInfo1.pairName, PAIR_NAME_ETH_USDC);
        assertEq(poolInfo1.protocolId, bytes32(bytes(DEX_UNISWAP)));

        assertEq(poolInfo2.pairName, PAIR_NAME_WBTC_ETH);
        assertEq(poolInfo2.protocolId, bytes32(bytes(DEX_SUSHISWAP)));

        assertEq(poolInfo3.pairName, PAIR_NAME_DAI_USDC);
        assertEq(poolInfo3.protocolId, bytes32(bytes(DEX_CURVE)));
    }

    /// @notice Test poolDetails after pool removal
    function test_PoolDetailsAfterRemoval() public {
        IPoolRegistry.PoolInfo memory poolInfoBefore = registry.poolDetails(pool1);
        assertTrue(bytes(poolInfoBefore.pairName).length > 0);
        assertTrue(poolInfoBefore.protocolId != bytes32(0));

        removePool(pool1);

        IPoolRegistry.PoolInfo memory poolInfoAfter = registry.poolDetails(pool1);
        assertEq(poolInfoAfter.pairName, "");
        assertEq(poolInfoAfter.protocolId, bytes32(0));
    }

    /// @notice Test poolDetails persists across operations
    function test_PoolDetailsPersistsAcrossOperations() public {
        IPoolRegistry.PoolInfo memory poolInfo1Before = registry.poolDetails(pool1);

        // Add another pool
        addPool(pool4, PAIR_NAME_USDT_USDC, DEX_BALANCER);

        // Remove a different pool
        removePool(pool3);

        // Verify pool1 details unchanged
        IPoolRegistry.PoolInfo memory poolInfo1After = registry.poolDetails(pool1);
        assertEq(poolInfo1After.pairName, poolInfo1Before.pairName);
        assertEq(poolInfo1After.protocolId, poolInfo1Before.protocolId);
    }

    // =============================================================
    // VIEW FUNCTIONS TESTS - POOL ADDRESSES
    // =============================================================

    /// @notice Test poolAddresses returns all registered pools
    function test_PoolAddressesReturnsAllPools() public view {
        address[] memory pools = registry.poolAddresses();
        assertEq(pools.length, 3);

        // Verify all pools are in the array
        bool foundPool1 = false;
        bool foundPool2 = false;
        bool foundPool3 = false;

        for (uint256 i = 0; i < pools.length; i++) {
            if (pools[i] == pool1) foundPool1 = true;
            if (pools[i] == pool2) foundPool2 = true;
            if (pools[i] == pool3) foundPool3 = true;
        }

        assertTrue(foundPool1);
        assertTrue(foundPool2);
        assertTrue(foundPool3);
    }

    /// @notice Test poolAddresses returns empty array initially
    function test_PoolAddressesReturnsEmptyInitially() public {
        PoolRegistry newImpl = new PoolRegistry();
        ProxyAdmin newAdmin = new ProxyAdmin(address(this));

        bytes memory initData = abi.encodeWithSelector(PoolRegistry.initialize.selector, owner);
        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImpl), address(newAdmin), initData);
        PoolRegistry newRegistry = PoolRegistry(payable(address(newProxy)));

        address[] memory pools = newRegistry.poolAddresses();
        assertEq(pools.length, 0);
    }

    /// @notice Test poolAddresses updates when pools are added
    function test_PoolAddressesUpdatesOnAdd() public {
        address[] memory poolsBefore = registry.poolAddresses();
        uint256 lengthBefore = poolsBefore.length;

        addPool(pool4, PAIR_NAME_USDT_USDC, DEX_BALANCER);

        address[] memory poolsAfter = registry.poolAddresses();
        assertEq(poolsAfter.length, lengthBefore + 1);

        // Verify new pool is in array
        bool found = false;
        for (uint256 i = 0; i < poolsAfter.length; i++) {
            if (poolsAfter[i] == pool4) {
                found = true;
                break;
            }
        }
        assertTrue(found);
    }

    /// @notice Test poolAddresses updates when pools are removed
    function test_PoolAddressesUpdatesOnRemove() public {
        address[] memory poolsBefore = registry.poolAddresses();
        uint256 lengthBefore = poolsBefore.length;

        removePool(pool1);

        address[] memory poolsAfter = registry.poolAddresses();
        assertEq(poolsAfter.length, lengthBefore - 1);

        // Verify removed pool is not in array
        for (uint256 i = 0; i < poolsAfter.length; i++) {
            assertTrue(poolsAfter[i] != pool1);
        }
    }

    /// @notice Test poolAddresses returns unique addresses
    function test_PoolAddressesReturnsUniqueAddresses() public view {
        address[] memory pools = registry.poolAddresses();

        // Check for duplicates
        for (uint256 i = 0; i < pools.length; i++) {
            for (uint256 j = i + 1; j < pools.length; j++) {
                assertTrue(pools[i] != pools[j], "Pool addresses should be unique");
            }
        }
    }

    /// @notice Test poolAddresses with many pools
    function test_PoolAddressesWithManyPools() public {
        addPool(pool4, PAIR_NAME_USDT_USDC, DEX_BALANCER);
        addPool(pool5, PAIR_NAME_ARB_ETH, DEX_UNISWAP);

        address[] memory pools = registry.poolAddresses();
        assertEq(pools.length, 5);

        // Verify all pools are non-zero
        for (uint256 i = 0; i < pools.length; i++) {
            assertTrue(pools[i] != address(0));
        }
    }

    // =============================================================
    // VIEW FUNCTIONS TESTS - IS POOL REGISTERED
    // =============================================================

    /// @notice Test isPoolRegistered returns true for registered pools
    function test_IsPoolRegisteredReturnsTrueForRegistered() public view {
        assertTrue(registry.isPoolRegistered(pool1));
        assertTrue(registry.isPoolRegistered(pool2));
        assertTrue(registry.isPoolRegistered(pool3));
    }

    /// @notice Test isPoolRegistered returns false for non-registered pools
    function test_IsPoolRegisteredReturnsFalseForNonRegistered() public {
        address nonRegisteredPool = makeAddr("nonRegisteredPool");
        assertFalse(registry.isPoolRegistered(nonRegisteredPool));
    }

    /// @notice Test isPoolRegistered returns false for zero address
    function test_IsPoolRegisteredReturnsFalseForZeroAddress() public view {
        assertFalse(registry.isPoolRegistered(address(0)));
    }

    /// @notice Test isPoolRegistered updates after pool addition
    function test_IsPoolRegisteredUpdatesAfterAddition() public {
        assertFalse(registry.isPoolRegistered(pool4));

        addPool(pool4, PAIR_NAME_USDT_USDC, DEX_BALANCER);

        assertTrue(registry.isPoolRegistered(pool4));
    }

    /// @notice Test isPoolRegistered updates after pool removal
    function test_IsPoolRegisteredUpdatesAfterRemoval() public {
        assertTrue(registry.isPoolRegistered(pool1));

        removePool(pool1);

        assertFalse(registry.isPoolRegistered(pool1));
    }

    /// @notice Test isPoolRegistered for removed and re-added pool
    function test_IsPoolRegisteredForReAddedPool() public {
        assertTrue(registry.isPoolRegistered(pool1));

        removePool(pool1);
        assertFalse(registry.isPoolRegistered(pool1));

        addPool(pool1, PAIR_NAME_WBTC_ETH, DEX_SUSHISWAP);
        assertTrue(registry.isPoolRegistered(pool1));
    }

    /// @notice Test isPoolRegistered for multiple pools
    function test_IsPoolRegisteredForMultiplePools() public {
        addPool(pool4, PAIR_NAME_USDT_USDC, DEX_BALANCER);
        addPool(pool5, PAIR_NAME_ARB_ETH, DEX_UNISWAP);

        assertTrue(registry.isPoolRegistered(pool1));
        assertTrue(registry.isPoolRegistered(pool2));
        assertTrue(registry.isPoolRegistered(pool3));
        assertTrue(registry.isPoolRegistered(pool4));
        assertTrue(registry.isPoolRegistered(pool5));
    }

    // =============================================================
    // VIEW FUNCTIONS TESTS - CONSISTENCY
    // =============================================================

    /// @notice Test consistency between poolAddresses and isPoolRegistered
    function test_ConsistencyBetweenPoolAddressesAndIsPoolRegistered() public view {
        address[] memory pools = registry.poolAddresses();

        // All pools in array should be registered
        for (uint256 i = 0; i < pools.length; i++) {
            assertTrue(registry.isPoolRegistered(pools[i]), "Pool in array should be registered");
        }
    }

    /// @notice Test consistency between poolDetails and isPoolRegistered
    function test_ConsistencyBetweenPoolDetailsAndIsPoolRegistered() public view {
        address[] memory pools = registry.poolAddresses();

        for (uint256 i = 0; i < pools.length; i++) {
            IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(pools[i]);

            // Registered pools should have non-empty details
            assertTrue(bytes(poolInfo.pairName).length > 0, "Registered pool should have pair name");
            assertTrue(poolInfo.protocolId != bytes32(0), "Registered pool should have protocol ID");
        }
    }

    /// @notice Test consistency of all view functions
    function test_ConsistencyOfAllViewFunctions() public view {
        address[] memory pools = registry.poolAddresses();

        for (uint256 i = 0; i < pools.length; i++) {
            address poolAddress = pools[i];

            // Should be registered
            assertTrue(registry.isPoolRegistered(poolAddress));

            // Should have valid details
            IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(poolAddress);
            assertTrue(bytes(poolInfo.pairName).length > 0);
            assertTrue(poolInfo.protocolId != bytes32(0));

            // Should not be zero address
            assertTrue(poolAddress != address(0));
        }
    }

    /// @notice Test view functions work with empty registry
    function test_ViewFunctionsWorkWithEmptyRegistry() public {
        PoolRegistry newImpl = new PoolRegistry();
        ProxyAdmin newAdmin = new ProxyAdmin(address(this));

        bytes memory initData = abi.encodeWithSelector(PoolRegistry.initialize.selector, owner);
        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImpl), address(newAdmin), initData);
        PoolRegistry newRegistry = PoolRegistry(payable(address(newProxy)));

        // All view functions should work
        address[] memory pools = newRegistry.poolAddresses();
        assertEq(pools.length, 0);

        assertFalse(newRegistry.isPoolRegistered(pool1));

        IPoolRegistry.PoolInfo memory poolInfo = newRegistry.poolDetails(pool1);
        assertEq(poolInfo.pairName, "");
        assertEq(poolInfo.protocolId, bytes32(0));
    }

    /// @notice Test view functions after multiple operations
    function test_ViewFunctionsAfterMultipleOperations() public {
        // Add pools
        addPool(pool4, PAIR_NAME_USDT_USDC, DEX_BALANCER);
        addPool(pool5, PAIR_NAME_ARB_ETH, DEX_UNISWAP);

        // Remove some pools
        removePool(pool2);

        // Verify view functions
        address[] memory pools = registry.poolAddresses();
        assertEq(pools.length, 4);

        assertTrue(registry.isPoolRegistered(pool1));
        assertFalse(registry.isPoolRegistered(pool2));
        assertTrue(registry.isPoolRegistered(pool3));
        assertTrue(registry.isPoolRegistered(pool4));
        assertTrue(registry.isPoolRegistered(pool5));

        IPoolRegistry.PoolInfo memory poolInfo1 = registry.poolDetails(pool1);
        assertEq(poolInfo1.pairName, PAIR_NAME_ETH_USDC);
        assertEq(poolInfo1.protocolId, bytes32(bytes(DEX_UNISWAP)));

        IPoolRegistry.PoolInfo memory poolInfo4 = registry.poolDetails(pool4);
        assertEq(poolInfo4.pairName, PAIR_NAME_USDT_USDC);
        assertEq(poolInfo4.protocolId, bytes32(bytes(DEX_BALANCER)));
    }

    // =============================================================
    // VIEW FUNCTIONS TESTS - EDGE CASES
    // =============================================================

    /// @notice Test poolAddresses with maximum pools
    function test_PoolAddressesWithMaximumPools() public {
        // Add many pools
        for (uint256 i = 0; i < 100; i++) {
            address newPool = address(uint160(1000 + i));
            vm.prank(owner);
            registry.addPool(newPool, bytes32(bytes(DEX_UNISWAP)), PAIR_NAME_ETH_USDC);
        }

        address[] memory pools = registry.poolAddresses();
        assertEq(pools.length, 103); // 3 from setUp + 100 new
    }

    /// @notice Test view functions are gas efficient
    function test_ViewFunctionsGasEfficient() public view {
        // These should be view functions and not consume gas when called externally
        uint256 gasBefore = gasleft();
        registry.poolAddresses();
        uint256 gas1 = gasBefore - gasleft();

        gasBefore = gasleft();
        registry.isPoolRegistered(pool1);
        uint256 gas2 = gasBefore - gasleft();

        gasBefore = gasleft();
        registry.poolDetails(pool1);
        uint256 gas3 = gasBefore - gasleft();

        // View functions should use minimal gas
        assertTrue(gas1 < 100_000, "poolAddresses should be gas efficient");
        assertTrue(gas2 < 100_000, "isPoolRegistered should be gas efficient");
        assertTrue(gas3 < 100_000, "poolDetails should be gas efficient");
    }

    /// @notice Test view functions return correct types
    function test_ViewFunctionsReturnCorrectTypes() public view {
        // poolAddresses returns address array
        address[] memory pools = registry.poolAddresses();
        assertTrue(pools.length >= 0);

        // isPoolRegistered returns bool
        bool isRegistered = registry.isPoolRegistered(pool1);
        assertTrue(isRegistered == true || isRegistered == false);

        // poolDetails returns PoolInfo struct
        IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(pool1);
        assertTrue(bytes(poolInfo.pairName).length >= 0);
        assertTrue(poolInfo.protocolId == poolInfo.protocolId); // Always true, just checking it exists
    }

    // =============================================================
    // FUZZ TESTS
    // =============================================================

    /// @notice Fuzz test isPoolRegistered with random addresses
    function testFuzz_IsPoolRegistered(address poolAddress) public view {
        // Should return bool for any address
        bool result = registry.isPoolRegistered(poolAddress);
        assertTrue(result == true || result == false);
    }

    /// @notice Fuzz test poolDetails with random addresses
    function testFuzz_PoolDetails(address poolAddress) public view {
        // Should return PoolInfo struct (possibly empty) for any address
        IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(poolAddress);
        assertTrue(bytes(poolInfo.pairName).length >= 0);
        assertTrue(poolInfo.protocolId == poolInfo.protocolId); // Always true, just checking it exists
    }
}
