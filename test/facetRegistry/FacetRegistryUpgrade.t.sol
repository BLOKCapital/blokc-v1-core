// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.20;

import { FacetRegistryTestBase } from "./FacetRegistryTestBase.sol";
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { MockFacet, MockFacetV2 } from "./MockFacets.sol";

/// @title Tests for FacetRegistry proxy upgrade functionality
contract FacetRegistryUpgradeTest is FacetRegistryTestBase {
    function setUp() public override {
        super.setUp();
    }

    // =============================================================
    // UPGRADE TESTS
    // =============================================================

    /// @notice Test upgrading to a new implementation
    function test_UpgradeToNewImplementation() public {
        // Add some data before upgrade
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;
        addFacetWithSelectors(address(mockFacet), selectors);

        assertTrue(registry.isFacetRegistered(address(mockFacet)));

        // Deploy new implementation
        FacetRegistry newImpl = new FacetRegistry();

        // Upgrade
        vm.prank(owner);
        registryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(registryProxy))), address(newImpl), bytes("")
        );

        // Verify data persists
        assertTrue(registry.isFacetRegistered(address(mockFacet)));
        bytes4[] memory storedSelectors = registry.getFacetFunctionSelectors(address(mockFacet));
        assertEq(storedSelectors.length, 1);
        assertEq(storedSelectors[0], selectors[0]);
    }

    /// @notice Test that non-admin cannot upgrade
    function test_RevertIf_NonAdminUpgrades() public {
        FacetRegistry newImpl = new FacetRegistry();

        vm.prank(user1);
        vm.expectRevert();
        registryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(registryProxy))), address(newImpl), bytes("")
        );
    }

    /// @notice Test upgrade preserves ownership
    function test_UpgradePreservesOwnership() public {
        assertEq(registry.owner(), owner);

        FacetRegistry newImpl = new FacetRegistry();
        vm.prank(owner);
        registryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(registryProxy))), address(newImpl), bytes("")
        );

        assertEq(registry.owner(), owner);
    }

    /// @notice Test upgrade preserves version
    function test_UpgradePreservesVersion() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;
        addFacetWithSelectors(address(mockFacet), selectors);

        uint256 versionBefore = registry.getCurrentVersion();
        assertTrue(versionBefore > 0);

        FacetRegistry newImpl = new FacetRegistry();
        vm.prank(owner);
        registryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(registryProxy))), address(newImpl), bytes("")
        );

        assertEq(registry.getCurrentVersion(), versionBefore);
    }

    /// @notice Test upgrade preserves base facets
    function test_UpgradePreservesBaseFacets() public {
        address[4] memory baseFacetsBefore = registry.getBaseFacets();

        FacetRegistry newImpl = new FacetRegistry();
        vm.prank(owner);
        registryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(registryProxy))), address(newImpl), bytes("")
        );

        address[4] memory baseFacetsAfter = registry.getBaseFacets();
        for (uint256 i = 0; i < 4; i++) {
            assertEq(baseFacetsAfter[i], baseFacetsBefore[i]);
        }
    }

    /// @notice Test upgrade preserves all facets
    function test_UpgradePreservesAllFacets() public {
        bytes4[] memory selectors1 = new bytes4[](2);
        selectors1[0] = MockFacet.mockFunction1.selector;
        selectors1[1] = MockFacet.mockFunction2.selector;
        addFacetWithSelectors(address(mockFacet), selectors1);

        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = MockFacetV2.newFunction.selector;
        addFacetWithSelectors(address(mockFacetV2), selectors2);

        IFacetRegistry.Facet[] memory facetsBefore = registry.getFacets();

        FacetRegistry newImpl = new FacetRegistry();
        vm.prank(owner);
        registryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(registryProxy))), address(newImpl), bytes("")
        );

        IFacetRegistry.Facet[] memory facetsAfter = registry.getFacets();
        assertEq(facetsAfter.length, facetsBefore.length);
    }

    /// @notice Test operations work after upgrade
    function test_OperationsWorkAfterUpgrade() public {
        bytes4[] memory selectors1 = new bytes4[](1);
        selectors1[0] = MockFacet.mockFunction1.selector;
        addFacetWithSelectors(address(mockFacet), selectors1);

        FacetRegistry newImpl = new FacetRegistry();
        vm.prank(owner);
        registryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(registryProxy))), address(newImpl), bytes("")
        );

        // Add more facets after upgrade
        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = MockFacetV2.newFunction.selector;
        addFacetWithSelectors(address(mockFacetV2), selectors2);

        assertTrue(registry.isFacetRegistered(address(mockFacet)));
        assertTrue(registry.isFacetRegistered(address(mockFacetV2)));
    }

    /// @notice Test multiple upgrades
    function test_MultipleUpgrades() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;
        addFacetWithSelectors(address(mockFacet), selectors);

        // First upgrade
        FacetRegistry newImpl1 = new FacetRegistry();
        vm.prank(owner);
        registryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(registryProxy))), address(newImpl1), bytes("")
        );

        assertTrue(registry.isFacetRegistered(address(mockFacet)));

        // Second upgrade
        FacetRegistry newImpl2 = new FacetRegistry();
        vm.prank(owner);
        registryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(registryProxy))), address(newImpl2), bytes("")
        );

        assertTrue(registry.isFacetRegistered(address(mockFacet)));
    }

    /// @notice Test upgrade with data preservation across complex state
    function test_UpgradeWithComplexState() public {
        // Add multiple facets with multiple selectors
        bytes4[] memory selectors1 = new bytes4[](3);
        selectors1[0] = MockFacet.mockFunction1.selector;
        selectors1[1] = MockFacet.mockFunction2.selector;
        selectors1[2] = MockFacet.mockFunction3.selector;
        addFacetWithSelectors(address(mockFacet), selectors1);

        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = MockFacetV2.newFunction.selector;
        addFacetWithSelectors(address(mockFacetV2), selectors2);

        // Store state before upgrade
        uint256 versionBefore = registry.getCurrentVersion();
        address[] memory addressesBefore = registry.getFacetAddresses();

        // Upgrade
        FacetRegistry newImpl = new FacetRegistry();
        vm.prank(owner);
        registryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(registryProxy))), address(newImpl), bytes("")
        );

        // Verify all state preserved
        assertEq(registry.getCurrentVersion(), versionBefore);
        address[] memory addressesAfter = registry.getFacetAddresses();
        assertEq(addressesAfter.length, addressesBefore.length);

        for (uint256 i = 0; i < addressesAfter.length; i++) {
            assertEq(addressesAfter[i], addressesBefore[i]);
        }
    }

    /// @notice Test proxy admin can change admin
    function test_ProxyAdminCanChangeAdmin() public {
        address newAdmin = makeAddr("newAdmin");

        vm.prank(owner);
        registryProxyAdmin.transferOwnership(newAdmin);

        assertEq(registryProxyAdmin.owner(), newAdmin);
    }
}
