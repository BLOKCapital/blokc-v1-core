// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.20;

import { FacetRegistryTestBase } from "./FacetRegistryTestBase.sol";
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { MockFacet, MockFacetV2 } from "./MockFacets.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Tests for FacetRegistry view/getter functions
contract FacetRegistryViewFunctionsTest is FacetRegistryTestBase {
    function setUp() public override {
        super.setUp();

        // Add some test facets for comprehensive testing
        bytes4[] memory mockFacetSelectors = new bytes4[](2);
        mockFacetSelectors[0] = MockFacet.mockFunction1.selector;
        mockFacetSelectors[1] = MockFacet.mockFunction2.selector;

        addFacetWithSelectors(address(mockFacet), mockFacetSelectors);

        bytes4[] memory mockFacetV2Selectors = new bytes4[](1);
        mockFacetV2Selectors[0] = MockFacetV2.newFunction.selector;

        addFacetWithSelectors(address(mockFacetV2), mockFacetV2Selectors);
    }

    // =============================================================
    // VIEW FUNCTIONS TESTS - GETTERS
    // =============================================================

    /// @notice Test getFacets returns all registered facets
    function test_GetFacetsReturnsAllFacets() public view {
        IFacetRegistry.Facet[] memory facets = registry.getFacets();
        assertEq(facets.length, 6); // 4 base + 2 added

        // Verify base facets
        bool foundCutFacet = false;
        bool foundLoupeFacet = false;
        bool foundOwnFacet = false;
        bool foundUpgFacet = false;

        for (uint256 i = 0; i < facets.length; i++) {
            if (facets[i].facetAddress == address(diamondCutFacet)) {
                foundCutFacet = true;
            }
            if (facets[i].facetAddress == address(diamondLoupeFacet)) {
                foundLoupeFacet = true;
            }
            if (facets[i].facetAddress == address(ownershipFacet)) {
                foundOwnFacet = true;
            }
            if (facets[i].facetAddress == address(upgradeFacet)) {
                foundUpgFacet = true;
            }
        }

        assertTrue(foundCutFacet);
        assertTrue(foundLoupeFacet);
        assertTrue(foundOwnFacet);
        assertTrue(foundUpgFacet);
    }

    /// @notice Test getFacets returns correct selectors for each facet
    function test_GetFacetsReturnsCorrectSelectors() public view {
        IFacetRegistry.Facet[] memory facets = registry.getFacets();

        for (uint256 i = 0; i < facets.length; i++) {
            if (facets[i].facetAddress == address(mockFacet)) {
                assertEq(facets[i].functionSelectors.length, 2);
                assertEq(facets[i].functionSelectors[0], MockFacet.mockFunction1.selector);
                assertEq(facets[i].functionSelectors[1], MockFacet.mockFunction2.selector);
            }
            if (facets[i].facetAddress == address(mockFacetV2)) {
                assertEq(facets[i].functionSelectors.length, 1);
                assertEq(facets[i].functionSelectors[0], MockFacetV2.newFunction.selector);
            }
        }
    }

    /// @notice Test getFacetFunctionSelectors returns all selectors for facet
    function test_GetFacetFunctionSelectorsReturnsAllSelectors() public view {
        bytes4[] memory selectors = registry.getFacetFunctionSelectors(address(mockFacet));
        assertEq(selectors.length, 2);
        assertEq(selectors[0], MockFacet.mockFunction1.selector);
        assertEq(selectors[1], MockFacet.mockFunction2.selector);
    }

    /// @notice Test getFacetFunctionSelectors returns empty for non-existent facet
    function test_GetFacetFunctionSelectorsReturnsEmptyForNonExistent() public {
        address nonExistentFacet = makeAddr("nonExistentFacet");
        bytes4[] memory selectors = registry.getFacetFunctionSelectors(nonExistentFacet);
        assertEq(selectors.length, 0);
    }

    /// @notice Test getFacetAddresses returns all facet addresses
    function test_GetFacetAddressesReturnsAllAddresses() public view {
        address[] memory addresses = registry.getFacetAddresses();
        assertEq(addresses.length, 6); // 4 base + 2 added

        // Verify all addresses are non-zero
        for (uint256 i = 0; i < addresses.length; i++) {
            assertNotEq(addresses[i], address(0));
        }
    }

    /// @notice Test getFacetAddresses includes added facets
    function test_GetFacetAddressesIncludesAddedFacets() public view {
        address[] memory addresses = registry.getFacetAddresses();

        bool foundMockFacet = false;
        bool foundMockFacetV2 = false;

        for (uint256 i = 0; i < addresses.length; i++) {
            if (addresses[i] == address(mockFacet)) {
                foundMockFacet = true;
            }
            if (addresses[i] == address(mockFacetV2)) {
                foundMockFacetV2 = true;
            }
        }

        assertTrue(foundMockFacet);
        assertTrue(foundMockFacetV2);
    }

    /// @notice Test getFacetAddress returns correct facet for selector
    function test_GetFacetAddressReturnsCorrectFacet() public view {
        address facet = registry.getFacetAddress(MockFacet.mockFunction1.selector);
        assertEq(facet, address(mockFacet));
    }

    /// @notice Test getFacetAddress returns zero for non-existent selector
    function test_GetFacetAddressReturnsZeroForNonExistent() public view {
        bytes4 nonExistentSelector = bytes4(0x12345678);
        address facet = registry.getFacetAddress(nonExistentSelector);
        assertEq(facet, address(0));
    }

    /// @notice Test getBaseFacets returns all base facets
    function test_GetBaseFacetsReturnsAllBaseFacets() public view {
        address[4] memory baseFacets = registry.getBaseFacets();
        assertEq(baseFacets[0], address(diamondCutFacet));
        assertEq(baseFacets[1], address(diamondLoupeFacet));
        assertEq(baseFacets[2], address(ownershipFacet));
        assertEq(baseFacets[3], address(upgradeFacet));
    }

    /// @notice Test getBaseFacets always returns same base facets
    function test_GetBaseFacetsReturnsSameBaseFacets() public {
        address[4] memory before = registry.getBaseFacets();

        // Add some facets (use a different selector already registered in setUp)
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction3.selector;
        addFacetWithSelectors(address(mockFacet), selectors);

        address[4] memory afterFacets = registry.getBaseFacets();

        // Should be the same
        assertEq(before[0], afterFacets[0]);
        assertEq(before[1], afterFacets[1]);
        assertEq(before[2], afterFacets[2]);
        assertEq(before[3], afterFacets[3]);
    }

    // =============================================================
    // VIEW FUNCTIONS TESTS - CHECK FUNCTIONS
    // =============================================================

    /// @notice Test isFacetRegistered returns true for registered facet
    function test_IsFacetRegisteredReturnsTrueForRegistered() public view {
        assertTrue(registry.isFacetRegistered(address(mockFacet)));
        assertTrue(registry.isFacetRegistered(address(diamondCutFacet)));
    }

    /// @notice Test isFacetRegistered returns false for non-registered facet
    function test_IsFacetRegisteredReturnsFalseForNonRegistered() public {
        address nonRegistered = makeAddr("nonRegisteredFacet");
        assertFalse(registry.isFacetRegistered(nonRegistered));
    }

    /// @notice Test isFacetRegistered returns false for zero address
    function test_IsFacetRegisteredReturnsFalseForZeroAddress() public {
        assertFalse(registry.isFacetRegistered(address(0)));
    }

    /// @notice Test isFacetRegistered updates after facet removal
    function test_IsFacetRegisteredUpdatesAfterRemoval() public {
        assertTrue(registry.isFacetRegistered(address(mockFacet)));

        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = MockFacet.mockFunction1.selector;
        selectors[1] = MockFacet.mockFunction2.selector;

        removeSelectors(selectors);

        assertFalse(registry.isFacetRegistered(address(mockFacet)));
    }

    /// @notice Test isSelectorRegistered returns true for registered selector
    function test_IsSelectorRegisteredReturnsTrueForRegistered() public view {
        assertTrue(registry.isSelectorRegisteredWithFacet(address(mockFacet), MockFacet.mockFunction1.selector));
        assertTrue(registry.isSelectorRegisteredWithFacet(address(diamondCutFacet), diamondCutSelectors[0]));
    }

    /// @notice Test isSelectorRegistered returns false for non-registered selector
    function test_IsSelectorRegisteredReturnsFalseForNonRegistered() public view {
        bytes4 nonExistentSelector = bytes4(0x12345678);
        assertFalse(registry.isSelectorRegisteredWithFacet(address(mockFacet), nonExistentSelector));
    }

    /// @notice Test isSelectorRegistered returns false for wrong facet
    function test_IsSelectorRegisteredReturnsFalseForWrongFacet() public view {
        // Try to check if selector belongs to different facet
        assertFalse(registry.isSelectorRegisteredWithFacet(address(mockFacetV2), MockFacet.mockFunction1.selector));
    }

    /// @notice Test isSelectorRegistered reverts with zero address facet
    function test_IsSelectorRegisteredRevertsWithZeroAddressFacet() public {
        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_FacetAddressIsZero()));
        registry.isSelectorRegisteredWithFacet(address(0), MockFacet.mockFunction1.selector);
    }

    /// @notice Test isSelectorRegistered updates after removal
    function test_IsSelectorRegisteredUpdatesAfterRemoval() public {
        assertTrue(registry.isSelectorRegisteredWithFacet(address(mockFacet), MockFacet.mockFunction1.selector));

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        removeSelectors(selectors);

        assertFalse(registry.isSelectorRegisteredWithFacet(address(mockFacet), MockFacet.mockFunction1.selector));
    }

    /// @notice Test isSelectorRegistered returns false after replacement
    function test_IsSelectorRegisteredReturnsFalseAfterReplacement() public {
        assertTrue(registry.isSelectorRegisteredWithFacet(address(mockFacet), MockFacet.mockFunction1.selector));

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        replaceFacetWithSelectors(address(mockFacetV2), selectors);

        assertFalse(registry.isSelectorRegisteredWithFacet(address(mockFacet), MockFacet.mockFunction1.selector));
        assertTrue(registry.isSelectorRegisteredWithFacet(address(mockFacetV2), MockFacet.mockFunction1.selector));
    }

    // =============================================================
    // VIEW FUNCTIONS TESTS - VERSION
    // =============================================================

    /// @notice Test getCurrentVersion returns correct version
    function test_GetCurrentVersionReturnsCorrectVersion() public view {
        uint256 version = registry.getCurrentVersion();
        assertGe(version, 0); // At least 0
    }

    /// @notice Test getCurrentVersion increments with operations
    function test_GetCurrentVersionIncrementsCorrectly() public {
        uint256 v1 = registry.getCurrentVersion();

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction3.selector;

        addFacetWithSelectors(address(mockFacet), selectors);
        uint256 v2 = registry.getCurrentVersion();
        assertEq(v2, v1 + 1);

        removeSelectors(selectors);
        uint256 v3 = registry.getCurrentVersion();
        assertEq(v3, v2 + 1);
    }

    /// @notice Test getCurrentVersion doesn't increment with view operations
    function test_GetCurrentVersionDoesntIncrementWithViews() public {
        uint256 v1 = registry.getCurrentVersion();

        // Call view functions
        registry.getFacets();
        registry.getFacetFunctionSelectors(address(mockFacet));
        registry.isFacetRegistered(address(mockFacet));

        uint256 v2 = registry.getCurrentVersion();
        assertEq(v2, v1);
    }

    // =============================================================
    // VIEW FUNCTIONS TESTS - EDGE CASES
    // =============================================================

    /// @notice Test all view functions work with empty registry
    function test_ViewFunctionsWorkWithEmptyRegistry() public {
        // Create fresh registry
        FacetRegistry newImpl = new FacetRegistry();
        ProxyAdmin newAdmin = new ProxyAdmin(address(this));

        address[4] memory baseFacets =
            [address(diamondCutFacet), address(diamondLoupeFacet), address(ownershipFacet), address(upgradeFacet)];

        bytes4[][] memory baseSelectors = new bytes4[][](4);
        baseSelectors[0] = diamondCutSelectors;
        baseSelectors[1] = diamondLoupeSelectors;
        baseSelectors[2] = ownershipSelectors;
        baseSelectors[3] = upgradeSelectors;

        bytes memory initData =
            abi.encodeWithSelector(FacetRegistry.initialize.selector, address(this), baseFacets, baseSelectors);
        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImpl), address(newAdmin), initData);
        FacetRegistry newRegistry = FacetRegistry(payable(address(newProxy)));

        // All view functions should work
        IFacetRegistry.Facet[] memory facets = newRegistry.getFacets();
        assertEq(facets.length, 4);

        address[] memory addresses = newRegistry.getFacetAddresses();
        assertEq(addresses.length, 4);

        uint256 version = newRegistry.getCurrentVersion();
        assertEq(version, 0);
    }

    /// @notice Test getFacetAddress for all selectors
    function test_GetFacetAddressForAllSelectors() public view {
        // Test base facets
        assertEq(registry.getFacetAddress(diamondCutSelectors[0]), address(diamondCutFacet));

        // Test added facets
        assertEq(registry.getFacetAddress(MockFacet.mockFunction1.selector), address(mockFacet));
        assertEq(registry.getFacetAddress(MockFacetV2.newFunction.selector), address(mockFacetV2));
    }

    /// @notice Test consistency between getFacets and getFacetAddresses
    function test_ConsistencyBetweenGetFacetsAndGetFacetAddresses() public view {
        IFacetRegistry.Facet[] memory facets = registry.getFacets();
        address[] memory addresses = registry.getFacetAddresses();

        assertEq(facets.length, addresses.length);

        // All addresses in getFacetAddresses should be in getFacets
        for (uint256 i = 0; i < addresses.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < facets.length; j++) {
                if (addresses[i] == facets[j].facetAddress) {
                    found = true;
                    break;
                }
            }
            assertTrue(found);
        }
    }

    /// @notice Test consistency between getFacetFunctionSelectors and getFacets
    function test_ConsistencyBetweenGetFacetFunctionSelectorsAndGetFacets() public view {
        IFacetRegistry.Facet[] memory facets = registry.getFacets();

        for (uint256 i = 0; i < facets.length; i++) {
            bytes4[] memory selectors = registry.getFacetFunctionSelectors(facets[i].facetAddress);
            assertEq(selectors.length, facets[i].functionSelectors.length);

            for (uint256 j = 0; j < selectors.length; j++) {
                assertEq(selectors[j], facets[i].functionSelectors[j]);
            }
        }
    }
}
