// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { GardenFactoryTestBase } from "./GardenFactoryTestBase.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// Import errors from GardenFactory
error GardenFactory_IndexOutOfRange(uint256 index);
error GardenFactory_IndexAlreadyUsed(address user, uint256 index);
error GardenFactory_DefaultFacetNotRegistered();

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

        bytes memory factoryInitData = abi.encodeWithSelector(GardenFactory.initialize.selector, newOwner);

        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImpl), address(newAdmin), factoryInitData);

        GardenFactory newFactory = GardenFactory(payable(address(newProxy)));
        assertEq(newFactory.owner(), newOwner);
    }

    /// @notice Test initialization with zero address owner reverts
    function test_RevertIf_InitializeWithZeroOwner() public {
        GardenFactory newImpl = new GardenFactory();
        ProxyAdmin newAdmin = new ProxyAdmin(address(this));

        bytes memory factoryInitData = abi.encodeWithSelector(GardenFactory.initialize.selector, address(0));

        vm.expectRevert();
        new TransparentUpgradeableProxy(address(newImpl), address(newAdmin), factoryInitData);
    }

    /// @notice Test that implementation cannot be initialized directly
    function test_RevertIf_InitializeImplementationDirectly() public {
        GardenFactory impl = new GardenFactory();

        vm.expectRevert();
        impl.initialize(owner, address(facetRegistry), address(protocolStatus));
    }

    /// @notice Test that initialization can only be called once
    function test_RevertIf_InitializeTwice() public {
        GardenFactory newImpl = new GardenFactory();
        ProxyAdmin newAdmin = new ProxyAdmin(address(this));

        bytes memory factoryInitData = abi.encodeWithSelector(
            GardenFactory.initialize.selector, owner, address(facetRegistry), address(protocolStatus)
        );

        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImpl), address(newAdmin), factoryInitData);

        GardenFactory newFactory = GardenFactory(payable(address(newProxy)));

        // Try to initialize again
        vm.expectRevert();
        newFactory.initialize(owner, address(facetRegistry), address(protocolStatus));
    }

    /// @notice Test that FactoryInitialized event is emitted
    function test_Emit_FactoryInitialized() public {
        GardenFactory newImpl = new GardenFactory();
        ProxyAdmin newAdmin = new ProxyAdmin(address(this));

        bytes memory factoryInitData = abi.encodeWithSelector(
            GardenFactory.initialize.selector, owner, address(facetRegistry), address(protocolStatus)
        );

        vm.expectEmit(true, false, false, false);
        emit FactoryInitialized(owner);

        new TransparentUpgradeableProxy(address(newImpl), address(newAdmin), factoryInitData);
    }
}
