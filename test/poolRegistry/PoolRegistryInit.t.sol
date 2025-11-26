// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.20;

import { PoolRegistryTestBase } from "./PoolRegistryTestBase.sol";
import { PoolRegistry } from "src/liquidityPoolRegistry/PoolRegistry.sol";
import { IPoolRegistry } from "src/interfaces/IPoolRegistry.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Tests for PoolRegistry initialization
contract PoolRegistryInitTest is PoolRegistryTestBase {
    function setUp() public override {
        super.setUp();
    }

    // =============================================================
    // INITIALIZATION TESTS
    // =============================================================

    /// @notice Test that registry initializes correctly
    function test_InitializeSuccessfully() public view {
        assertEq(registry.owner(), owner);
        assertFalse(registry.isPoolRegistered(address(1)));

        address[] memory pools = registry.poolAddresses();
        assertEq(pools.length, 0);
    }

    /// @notice Test initialization with different owner
    function test_InitializeWithDifferentOwner() public {
        address newOwner = makeAddr("newOwner");

        PoolRegistry newImpl = new PoolRegistry();
        ProxyAdmin newAdmin = new ProxyAdmin(address(this));

        bytes memory initData = abi.encodeWithSelector(PoolRegistry.initialize.selector, newOwner);

        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImpl), address(newAdmin), initData);

        PoolRegistry newRegistry = PoolRegistry(payable(address(newProxy)));
        assertEq(newRegistry.owner(), newOwner);
    }

    /// @notice Test that owner is set correctly on initialization
    function test_OwnerSetOnInitialization() public view {
        assertEq(registry.owner(), owner);
    }

    /// @notice Test that pool array is empty on initialization
    function test_PoolArrayEmptyOnInitialization() public view {
        address[] memory pools = registry.poolAddresses();
        assertEq(pools.length, 0);
    }

    /// @notice Test that implementation cannot be initialized directly
    function test_RevertIf_InitializeImplementationDirectly() public {
        PoolRegistry impl = new PoolRegistry();

        vm.expectRevert();
        impl.initialize(owner);
    }

    /// @notice Test that initialization can only be called once
    function test_RevertIf_InitializeTwice() public {
        PoolRegistry newImpl = new PoolRegistry();
        ProxyAdmin newAdmin = new ProxyAdmin(address(this));

        bytes memory initData = abi.encodeWithSelector(PoolRegistry.initialize.selector, owner);

        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImpl), address(newAdmin), initData);

        PoolRegistry newRegistry = PoolRegistry(payable(address(newProxy)));

        // Try to initialize again - should fail
        vm.expectRevert();
        newRegistry.initialize(owner);
    }

    /// @notice Test that isPoolRegistered returns false for any address initially
    function test_IsPoolRegisteredReturnsFalseInitially() public view {
        assertFalse(registry.isPoolRegistered(pool1));
        assertFalse(registry.isPoolRegistered(pool2));
        assertFalse(registry.isPoolRegistered(address(0)));
        assertFalse(registry.isPoolRegistered(owner));
    }

    /// @notice Test that poolDetails returns empty strings initially
    function test_PoolDetailsReturnsEmptyInitially() public view {
        IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(pool1);
        assertEq(poolInfo.pairName, "");
        assertEq(poolInfo.protocolId, bytes32(0));
    }

    /// @notice Test that poolAddresses returns empty array initially
    function test_PoolAddressesReturnsEmptyInitially() public view {
        address[] memory pools = registry.poolAddresses();
        assertEq(pools.length, 0);
    }

    /// @notice Test initialization with zero address owner
    function test_InitializeWithZeroAddressOwner() public {
        PoolRegistry newImpl = new PoolRegistry();
        ProxyAdmin newAdmin = new ProxyAdmin(address(this));

        bytes memory initData = abi.encodeWithSelector(PoolRegistry.initialize.selector, address(0));

        // OpenZeppelin's Ownable should revert on zero address
        vm.expectRevert();
        new TransparentUpgradeableProxy(address(newImpl), address(newAdmin), initData);
    }

    /// @notice Test that proxy is properly initialized
    function test_ProxyIsProperlyInitialized() public view {
        // Verify that the proxy has the implementation set
        assertTrue(address(registry) != address(0));
        assertTrue(address(registryImpl) != address(0));
        assertTrue(address(registryProxyAdmin) != address(0));
    }

    /// @notice Test that the implementation is disabled
    function test_ImplementationIsDisabled() public {
        PoolRegistry impl = new PoolRegistry();

        // Should not be able to initialize the implementation
        vm.expectRevert();
        impl.initialize(owner);
    }

    /// @notice Test initialization preserves ownership
    function test_InitializationPreservesOwnership() public {
        address testOwner = makeAddr("testOwner");

        PoolRegistry newImpl = new PoolRegistry();
        ProxyAdmin newAdmin = new ProxyAdmin(address(this));

        bytes memory initData = abi.encodeWithSelector(PoolRegistry.initialize.selector, testOwner);

        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImpl), address(newAdmin), initData);

        PoolRegistry newRegistry = PoolRegistry(payable(address(newProxy)));

        // Verify ownership is preserved
        assertEq(newRegistry.owner(), testOwner);

        // Test owner can perform owner-only actions
        address testPool = makeAddr("testPool");
        vm.prank(testOwner);
        newRegistry.addPool(testPool, bytes32(bytes("TestDex")), "TEST/POOL");

        assertTrue(newRegistry.isPoolRegistered(testPool));
    }

    /// @notice Test multiple registry deployments with different owners
    function test_MultipleRegistryDeployments() public {
        address owner1 = makeAddr("owner1");
        address owner2 = makeAddr("owner2");

        // Deploy first registry
        PoolRegistry impl1 = new PoolRegistry();
        ProxyAdmin admin1 = new ProxyAdmin(address(this));
        bytes memory initData1 = abi.encodeWithSelector(PoolRegistry.initialize.selector, owner1);
        TransparentUpgradeableProxy proxy1 = new TransparentUpgradeableProxy(address(impl1), address(admin1), initData1);
        PoolRegistry registry1 = PoolRegistry(payable(address(proxy1)));

        // Deploy second registry
        PoolRegistry impl2 = new PoolRegistry();
        ProxyAdmin admin2 = new ProxyAdmin(address(this));
        bytes memory initData2 = abi.encodeWithSelector(PoolRegistry.initialize.selector, owner2);
        TransparentUpgradeableProxy proxy2 = new TransparentUpgradeableProxy(address(impl2), address(admin2), initData2);
        PoolRegistry registry2 = PoolRegistry(payable(address(proxy2)));

        // Verify both registries have correct owners
        assertEq(registry1.owner(), owner1);
        assertEq(registry2.owner(), owner2);

        // Verify they are independent
        address testPool = makeAddr("testPool");
        vm.prank(owner1);
        registry1.addPool(testPool, bytes32(bytes("TestDex")), "TEST/POOL");

        assertTrue(registry1.isPoolRegistered(testPool));
        assertFalse(registry2.isPoolRegistered(testPool));
    }

    /// @notice Test that initialization sets up the proxy correctly
    function test_InitializationSetsUpProxyCorrectly() public view {
        // The proxy should forward calls to the implementation
        // We can test this by calling owner() which is in the implementation
        assertEq(registry.owner(), owner);

        // The proxy address should not be zero
        assertTrue(address(registry) != address(0));
    }
}
