// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { GardenFactoryTestBase } from "./GardenFactoryTestBase.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// Import errors from GardenFactory
error GardenFactory_FacetRegistryNotSet();
error GardenFactory_ProtocolStatusNotSet();
error GardenFactory_LiquidityPoolRegistryNotSet();

/// @title Tests for GardenFactory initialization
contract GardenFactoryInitTest is GardenFactoryTestBase {
    function setUp() public override {
        super.setUp();
    }

    // =============================================================
    // INITIALIZATION TESTS
    // =============================================================

    /// @notice Test that factory initializes correctly
    function test_InitializeSuccessfully() public {
        assertEq(factory.owner(), owner);
        assertTrue(factory.isGardenRegistered(address(0)) == false);

        address[] memory allGardens = factory.getAllGardens();
        assertEq(allGardens.length, 0);
    }

    /// @notice Test initialization with different owner
    function test_InitializeWithDifferentOwner() public {
        address newOwner = makeAddr("newOwner");

        GardenFactory newImpl = new GardenFactory();
        ProxyAdmin newAdmin = new ProxyAdmin(address(this));

        bytes memory factoryInitData = abi.encodeWithSelector(
            GardenFactory.initialize.selector,
            newOwner,
            address(protocolStatus),
            address(facetRegistry),
            address(poolRegistry)
        );

        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImpl), address(newAdmin), factoryInitData);

        GardenFactory newFactory = GardenFactory(payable(address(newProxy)));
        assertEq(newFactory.owner(), newOwner);
    }

    /// @notice Test that initialization reverts if facet registry is zero
    function test_RevertIf_FacetRegistryIsZero() public {
        GardenFactory newImpl = new GardenFactory();
        ProxyAdmin newAdmin = new ProxyAdmin(address(this));

        bytes memory factoryInitData = abi.encodeWithSelector(
            GardenFactory.initialize.selector,
            owner,
            address(protocolStatus),
            address(0), // Zero facet registry
            address(poolRegistry)
        );

        vm.expectRevert(GardenFactory_FacetRegistryNotSet.selector);
        new TransparentUpgradeableProxy(address(newImpl), address(newAdmin), factoryInitData);
    }

    /// @notice Test that initialization reverts if protocol status is zero
    function test_RevertIf_ProtocolStatusIsZero() public {
        GardenFactory newImpl = new GardenFactory();
        ProxyAdmin newAdmin = new ProxyAdmin(address(this));

        bytes memory factoryInitData = abi.encodeWithSelector(
            GardenFactory.initialize.selector,
            owner,
            address(0), // Zero protocol status
            address(facetRegistry),
            address(poolRegistry)
        );

        vm.expectRevert(GardenFactory_ProtocolStatusNotSet.selector);
        new TransparentUpgradeableProxy(address(newImpl), address(newAdmin), factoryInitData);
    }

    /// @notice Test that initialization reverts if liquidity pool registry is zero
    function test_RevertIf_LiquidityPoolRegistryIsZero() public {
        GardenFactory newImpl = new GardenFactory();
        ProxyAdmin newAdmin = new ProxyAdmin(address(this));

        bytes memory factoryInitData = abi.encodeWithSelector(
            GardenFactory.initialize.selector,
            owner,
            address(protocolStatus),
            address(facetRegistry),
            address(0) // Zero pool registry
        );

        vm.expectRevert(GardenFactory_LiquidityPoolRegistryNotSet.selector);
        new TransparentUpgradeableProxy(address(newImpl), address(newAdmin), factoryInitData);
    }

    /// @notice Test that implementation cannot be initialized directly
    function test_RevertIf_InitializeImplementationDirectly() public {
        GardenFactory impl = new GardenFactory();

        vm.expectRevert();
        impl.initialize(owner, address(protocolStatus), address(facetRegistry), address(poolRegistry));
    }

    /// @notice Test that initialization can only be called once
    function test_RevertIf_InitializeTwice() public {
        GardenFactory newImpl = new GardenFactory();
        ProxyAdmin newAdmin = new ProxyAdmin(address(this));

        bytes memory factoryInitData = abi.encodeWithSelector(
            GardenFactory.initialize.selector,
            owner,
            address(protocolStatus),
            address(facetRegistry),
            address(poolRegistry)
        );

        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImpl), address(newAdmin), factoryInitData);

        GardenFactory newFactory = GardenFactory(payable(address(newProxy)));

        // Try to initialize again
        vm.expectRevert();
        newFactory.initialize(owner, address(protocolStatus), address(facetRegistry), address(poolRegistry));
    }

    /// @notice Test that FactoryInitialized event is emitted
    function test_Emit_FactoryInitialized() public {
        GardenFactory newImpl = new GardenFactory();
        ProxyAdmin newAdmin = new ProxyAdmin(address(this));

        bytes memory factoryInitData = abi.encodeWithSelector(
            GardenFactory.initialize.selector,
            owner,
            address(protocolStatus),
            address(facetRegistry),
            address(poolRegistry)
        );

        vm.expectEmit(true, true, true, true);
        emit FactoryInitialized(owner, address(protocolStatus), address(facetRegistry), address(poolRegistry));

        new TransparentUpgradeableProxy(address(newImpl), address(newAdmin), factoryInitData);
    }
}
