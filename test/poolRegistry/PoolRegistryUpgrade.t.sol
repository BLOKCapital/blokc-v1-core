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

/// @title Tests for PoolRegistry proxy upgrade functionality
contract PoolRegistryUpgradeTest is PoolRegistryTestBase {
    function setUp() public override {
        super.setUp();
    }

    // =============================================================
    // UPGRADE TESTS
    // =============================================================

    /// @notice Test upgrading to a new implementation
    function test_UpgradeToNewImplementation() public {
        // Add some pools before upgrade
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        addPool(pool2, PAIR_NAME_WBTC_ETH, DEX_SUSHISWAP);

        assertTrue(registry.isPoolRegistered(pool1));
        assertTrue(registry.isPoolRegistered(pool2));

        // Deploy new implementation
        PoolRegistry newImpl = new PoolRegistry();

        // Upgrade - owner is the ProxyAdmin owner
        vm.prank(owner);
        registryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(registryProxy))), address(newImpl), bytes("")
        );

        // Verify data persists
        assertTrue(registry.isPoolRegistered(pool1));
        assertTrue(registry.isPoolRegistered(pool2));

        IPoolRegistry.PoolInfo memory poolInfo1 = registry.poolDetails(pool1);
        assertEq(poolInfo1.pairName, PAIR_NAME_ETH_USDC);
        assertEq(poolInfo1.protocolId, bytes32(bytes(DEX_UNISWAP)));
    }

    /// @notice Test that non-admin cannot upgrade
    function test_RevertIf_NonAdminUpgrades() public {
        PoolRegistry newImpl = new PoolRegistry();

        vm.prank(user1);
        vm.expectRevert();
        registryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(registryProxy))), address(newImpl), bytes("")
        );
    }

    /// @notice Test upgrade preserves ownership
    function test_UpgradePreservesOwnership() public {
        assertEq(registry.owner(), owner);

        PoolRegistry newImpl = new PoolRegistry();
        vm.prank(owner);
        registryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(registryProxy))), address(newImpl), bytes("")
        );

        assertEq(registry.owner(), owner);
    }

    /// @notice Test upgrade preserves all pools
    function test_UpgradePreservesAllPools() public {
        addMultiplePools(5);

        address[] memory poolsBefore = registry.poolAddresses();
        assertEq(poolsBefore.length, 5);

        PoolRegistry newImpl = new PoolRegistry();
        vm.prank(owner);
        registryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(registryProxy))), address(newImpl), bytes("")
        );

        address[] memory poolsAfter = registry.poolAddresses();
        assertEq(poolsAfter.length, poolsBefore.length);

        for (uint256 i = 0; i < poolsAfter.length; i++) {
            assertEq(poolsAfter[i], poolsBefore[i]);
        }
    }

    /// @notice Test operations work after upgrade
    function test_OperationsWorkAfterUpgrade() public {
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);

        PoolRegistry newImpl = new PoolRegistry();
        vm.prank(owner);
        registryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(registryProxy))), address(newImpl), bytes("")
        );

        // Add more pools after upgrade
        addPool(pool2, PAIR_NAME_WBTC_ETH, DEX_SUSHISWAP);

        assertTrue(registry.isPoolRegistered(pool1));
        assertTrue(registry.isPoolRegistered(pool2));

        // Remove pool after upgrade
        removePool(pool1);
        assertFalse(registry.isPoolRegistered(pool1));
    }

    /// @notice Test multiple upgrades
    function test_MultipleUpgrades() public {
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);

        // First upgrade
        PoolRegistry newImpl1 = new PoolRegistry();
        vm.prank(owner);
        registryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(registryProxy))), address(newImpl1), bytes("")
        );

        assertTrue(registry.isPoolRegistered(pool1));

        // Second upgrade
        PoolRegistry newImpl2 = new PoolRegistry();
        vm.prank(owner);
        registryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(registryProxy))), address(newImpl2), bytes("")
        );

        assertTrue(registry.isPoolRegistered(pool1));
    }

    /// @notice Test upgrade with complex pool state
    function test_UpgradeWithComplexState() public {
        // Add many pools
        addMultiplePools(5);

        // Store state before upgrade
        address[] memory addressesBefore = registry.poolAddresses();

        // Upgrade
        PoolRegistry newImpl = new PoolRegistry();
        vm.prank(owner);
        registryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(registryProxy))), address(newImpl), bytes("")
        );

        // Verify all state preserved
        address[] memory addressesAfter = registry.poolAddresses();
        assertEq(addressesAfter.length, addressesBefore.length);

        for (uint256 i = 0; i < addressesAfter.length; i++) {
            assertEq(addressesAfter[i], addressesBefore[i]);

            IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(addressesAfter[i]);
            assertTrue(bytes(poolInfo.pairName).length > 0);
            assertTrue(poolInfo.protocolId != bytes32(0));
        }
    }

    /// @notice Test proxy admin can change admin
    function test_ProxyAdminCanChangeAdmin() public {
        address newAdmin = makeAddr("newAdmin");

        vm.prank(owner);
        registryProxyAdmin.transferOwnership(newAdmin);

        assertEq(registryProxyAdmin.owner(), newAdmin);
    }

    /// @notice Test upgrade and then modify
    function test_UpgradeAndModify() public {
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        addPool(pool2, PAIR_NAME_WBTC_ETH, DEX_SUSHISWAP);

        // Upgrade
        PoolRegistry newImpl = new PoolRegistry();
        vm.prank(owner);
        registryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(registryProxy))), address(newImpl), bytes("")
        );

        // Remove one pool
        removePool(pool1);
        assertFalse(registry.isPoolRegistered(pool1));
        assertTrue(registry.isPoolRegistered(pool2));

        // Add new pools
        addPool(pool3, PAIR_NAME_DAI_USDC, DEX_CURVE);
        assertTrue(registry.isPoolRegistered(pool3));

        address[] memory pools = registry.poolAddresses();
        assertEq(pools.length, 2);
    }

    /// @notice Test upgrade preserves pool metadata
    function test_UpgradePreservesPoolMetadata() public {
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);

        IPoolRegistry.PoolInfo memory poolInfoBefore = registry.poolDetails(pool1);

        PoolRegistry newImpl = new PoolRegistry();
        vm.prank(owner);
        registryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(registryProxy))), address(newImpl), bytes("")
        );

        IPoolRegistry.PoolInfo memory poolInfoAfter = registry.poolDetails(pool1);
        assertEq(poolInfoAfter.pairName, poolInfoBefore.pairName);
        assertEq(poolInfoAfter.protocolId, poolInfoBefore.protocolId);
    }
}
