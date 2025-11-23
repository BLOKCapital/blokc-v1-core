// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.20;

import { GardenFactoryTestBase } from "./GardenFactoryTestBase.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Tests for GardenFactory proxy upgrade functionality
contract GardenFactoryUpgradeTest is GardenFactoryTestBase {
    function setUp() public override {
        super.setUp();
    }

    // =============================================================
    // UPGRADE TESTS
    // =============================================================

    /// @notice Test upgrading to a new implementation
    function test_UpgradeToNewImplementation() public {
        // Create some gardens before upgrade
        address garden1 = createGardenForUser(user1, 1);
        address garden2 = createGardenForUser(user2, 1);

        assertTrue(factory.isGardenRegistered(garden1));
        assertTrue(factory.isGardenRegistered(garden2));

        // Deploy new implementation
        GardenFactory newImpl = new GardenFactory();

        // Upgrade
        vm.prank(owner);
        factoryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(factoryProxy))), address(newImpl), bytes("")
        );

        // Verify data persists
        assertTrue(factory.isGardenRegistered(garden1));
        assertTrue(factory.isGardenRegistered(garden2));

        address[] memory user1Gardens = factory.getUserGardens(user1);
        assertEq(user1Gardens.length, 1);
        assertEq(user1Gardens[0], garden1);
    }

    /// @notice Test that non-admin cannot upgrade
    function test_RevertIf_NonAdminUpgrades() public {
        GardenFactory newImpl = new GardenFactory();

        vm.prank(user1);
        vm.expectRevert();
        factoryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(factoryProxy))), address(newImpl), bytes("")
        );
    }

    /// @notice Test upgrade preserves ownership
    function test_UpgradePreservesOwnership() public {
        assertEq(factory.owner(), owner);

        GardenFactory newImpl = new GardenFactory();
        vm.prank(owner);
        factoryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(factoryProxy))), address(newImpl), bytes("")
        );

        assertEq(factory.owner(), owner);
    }

    /// @notice Test upgrade preserves all gardens
    function test_UpgradePreservesAllGardens() public {
        address[] memory gardens = createMultipleGardensForUser(user1, 3);

        address[] memory allGardensBefore = factory.getAllGardens();
        assertEq(allGardensBefore.length, 3);

        GardenFactory newImpl = new GardenFactory();
        vm.prank(owner);
        factoryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(factoryProxy))), address(newImpl), bytes("")
        );

        address[] memory allGardensAfter = factory.getAllGardens();
        assertEq(allGardensAfter.length, allGardensBefore.length);

        for (uint256 i = 0; i < allGardensAfter.length; i++) {
            assertEq(allGardensAfter[i], gardens[i]);
        }
    }

    /// @notice Test operations work after upgrade
    function test_OperationsWorkAfterUpgrade() public {
        address garden1 = createGardenForUser(user1, 1);

        GardenFactory newImpl = new GardenFactory();
        vm.prank(owner);
        factoryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(factoryProxy))), address(newImpl), bytes("")
        );

        // Create more gardens after upgrade
        address garden2 = createGardenForUser(user1, 2);
        address garden3 = createGardenForUser(user2, 1);

        assertTrue(factory.isGardenRegistered(garden1));
        assertTrue(factory.isGardenRegistered(garden2));
        assertTrue(factory.isGardenRegistered(garden3));

        address[] memory user1Gardens = factory.getUserGardens(user1);
        assertEq(user1Gardens.length, 2);
    }

    /// @notice Test multiple upgrades
    function test_MultipleUpgrades() public {
        address garden1 = createGardenForUser(user1, 1);

        // First upgrade
        GardenFactory newImpl1 = new GardenFactory();
        vm.prank(owner);
        factoryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(factoryProxy))), address(newImpl1), bytes("")
        );

        assertTrue(factory.isGardenRegistered(garden1));

        // Second upgrade
        GardenFactory newImpl2 = new GardenFactory();
        vm.prank(owner);
        factoryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(factoryProxy))), address(newImpl2), bytes("")
        );

        assertTrue(factory.isGardenRegistered(garden1));
    }

    /// @notice Test upgrade with complex garden state
    function test_UpgradeWithComplexState() public {
        // Create gardens for multiple users
        createMultipleGardensForUser(user1, 5);
        createMultipleGardensForUser(user2, 3);
        createGardenForUser(user3, 1);

        // Store state before upgrade
        address[] memory allGardensBefore = factory.getAllGardens();
        address[] memory user1GardensBefore = factory.getUserGardens(user1);
        address[] memory user2GardensBefore = factory.getUserGardens(user2);

        // Upgrade
        GardenFactory newImpl = new GardenFactory();
        vm.prank(owner);
        factoryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(factoryProxy))), address(newImpl), bytes("")
        );

        // Verify all state preserved
        address[] memory allGardensAfter = factory.getAllGardens();
        assertEq(allGardensAfter.length, allGardensBefore.length);

        address[] memory user1GardensAfter = factory.getUserGardens(user1);
        assertEq(user1GardensAfter.length, user1GardensBefore.length);

        address[] memory user2GardensAfter = factory.getUserGardens(user2);
        assertEq(user2GardensAfter.length, user2GardensBefore.length);

        // Verify all gardens are still registered
        for (uint256 i = 0; i < allGardensAfter.length; i++) {
            assertTrue(factory.isGardenRegistered(allGardensAfter[i]));
        }
    }

    /// @notice Test proxy admin can change admin
    function test_ProxyAdminCanChangeAdmin() public {
        address newAdmin = makeAddr("newAdmin");

        vm.prank(owner);
        factoryProxyAdmin.transferOwnership(newAdmin);

        assertEq(factoryProxyAdmin.owner(), newAdmin);
    }

    /// @notice Test upgrade and then create new garden
    function test_UpgradeAndCreateNewGarden() public {
        createGardenForUser(user1, 1);
        createGardenForUser(user2, 1);

        // Upgrade
        GardenFactory newImpl = new GardenFactory();
        vm.prank(owner);
        factoryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(factoryProxy))), address(newImpl), bytes("")
        );

        // Create new garden after upgrade
        address garden3 = createGardenForUser(user1, 2);
        assertTrue(factory.isGardenRegistered(garden3));

        address[] memory user1Gardens = factory.getUserGardens(user1);
        assertEq(user1Gardens.length, 2);
    }

    /// @notice Test upgrade preserves user-index mapping
    function test_UpgradePreservesUserIndexMapping() public {
        address garden1 = createGardenForUser(user1, 5);

        assertEq(factory.getGarden(user1, 5), garden1);

        GardenFactory newImpl = new GardenFactory();
        vm.prank(owner);
        factoryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(factoryProxy))), address(newImpl), bytes("")
        );

        assertEq(factory.getGarden(user1, 5), garden1);
    }

    /// @notice Test upgrade prevents reusing indices
    function test_UpgradePreservesIndexProtection() public {
        createGardenForUser(user1, 1);

        GardenFactory newImpl = new GardenFactory();
        vm.prank(owner);
        factoryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(factoryProxy))), address(newImpl), bytes("")
        );

        // Should not be able to reuse index 1
        vm.prank(user1);
        vm.expectRevert();
        factory.createGarden(1);
    }
}
