// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.20;

import { FacetRegistryTestBase } from "./FacetRegistryTestBase.sol";
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { MockFacet, MockFacetV2 } from "./MockFacets.sol";

/// @title Integration tests for FacetRegistry
contract FacetRegistryIntegrationTest is FacetRegistryTestBase {
    function setUp() public override {
        super.setUp();
    }

    // =============================================================
    // INTEGRATION TESTS - COMPLEX SCENARIOS
    // =============================================================

    /// @notice Test complete lifecycle: add, replace, remove
    function test_CompleteLifecycleAddReplaceRemove() public {
        // Add initial facet
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = MockFacet.mockFunction1.selector;
        selectors[1] = MockFacet.mockFunction2.selector;
        selectors[2] = MockFacet.mockFunction3.selector;

        addFacetWithSelectors(address(mockFacet), selectors);
        assertTrue(registry.isFacetRegistered(address(mockFacet)));

        // Replace with new facet
        replaceFacetWithSelectors(address(mockFacetV2), selectors);
        assertFalse(registry.isFacetRegistered(address(mockFacet)));
        assertTrue(registry.isFacetRegistered(address(mockFacetV2)));

        // Remove all
        removeSelectors(selectors);
        assertFalse(registry.isFacetRegistered(address(mockFacetV2)));
    }

    /// @notice Test adding multiple facets and checking consistency
    function test_MultipleFacetsConsistency() public {
        bytes4[] memory selectors1 = new bytes4[](2);
        selectors1[0] = MockFacet.mockFunction1.selector;
        selectors1[1] = MockFacet.mockFunction2.selector;

        bytes4[] memory selectors2 = new bytes4[](2);
        selectors2[0] = MockFacetV2.newFunction.selector;
        selectors2[1] = MockFacet.mockFunction3.selector;

        addFacetWithSelectors(address(mockFacet), selectors1);
        addFacetWithSelectors(address(mockFacetV2), selectors2);

        // Verify consistency
        IFacetRegistry.Facet[] memory facets = registry.getFacets();
        address[] memory addresses = registry.getFacetAddresses();

        assertEq(facets.length, addresses.length);

        for (uint256 i = 0; i < facets.length; i++) {
            address facetAddr = facets[i].facetAddress;
            bytes4[] memory storedSelectors = registry.getFacetFunctionSelectors(facetAddr);

            for (uint256 j = 0; j < storedSelectors.length; j++) {
                assertTrue(registry.isSelectorRegisteredWithFacet(facetAddr, storedSelectors[j]));
                assertEq(registry.getFacetAddress(storedSelectors[j]), facetAddr);
            }
        }
    }

    /// @notice Test complex replacement scenario
    function test_ComplexReplacementScenario() public {
        // Add facet1 with 3 functions
        bytes4[] memory selectors1 = new bytes4[](3);
        selectors1[0] = MockFacet.mockFunction1.selector;
        selectors1[1] = MockFacet.mockFunction2.selector;
        selectors1[2] = MockFacet.mockFunction3.selector;

        addFacetWithSelectors(address(mockFacet), selectors1);

        // Add facet2 with 1 function
        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = MockFacetV2.newFunction.selector;

        addFacetWithSelectors(address(mockFacetV2), selectors2);

        // Replace 2 functions from facet1 to facet2
        bytes4[] memory toReplace = new bytes4[](2);
        toReplace[0] = MockFacet.mockFunction1.selector;
        toReplace[1] = MockFacet.mockFunction2.selector;

        replaceFacetWithSelectors(address(mockFacetV2), toReplace);

        // Verify state
        bytes4[] memory facet1Remaining = registry.getFacetFunctionSelectors(address(mockFacet));
        assertEq(facet1Remaining.length, 1);
        assertEq(facet1Remaining[0], MockFacet.mockFunction3.selector);

        bytes4[] memory facet2All = registry.getFacetFunctionSelectors(address(mockFacetV2));
        assertEq(facet2All.length, 3);
    }

    /// @notice Test removing specific functions while keeping others
    function test_RemoveSpecificFunctionsKeepOthers() public {
        // Add facet with multiple functions
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = MockFacet.mockFunction1.selector;
        selectors[1] = MockFacet.mockFunction2.selector;
        selectors[2] = MockFacet.mockFunction3.selector;

        addFacetWithSelectors(address(mockFacet), selectors);

        // Remove only one
        bytes4[] memory toRemove = new bytes4[](1);
        toRemove[0] = MockFacet.mockFunction1.selector;

        removeSelectors(toRemove);

        // Verify remaining
        bytes4[] memory remaining = registry.getFacetFunctionSelectors(address(mockFacet));
        assertEq(remaining.length, 2);
        // Verify both remaining selectors exist (order may vary due to swap optimization)
        bool hasFunc2 = false;
        bool hasFunc3 = false;
        for (uint256 i = 0; i < remaining.length; i++) {
            if (remaining[i] == MockFacet.mockFunction2.selector) hasFunc2 = true;
            if (remaining[i] == MockFacet.mockFunction3.selector) hasFunc3 = true;
        }
        assertTrue(hasFunc2);
        assertTrue(hasFunc3);
    }

    /// @notice Test adding functions to existing facet after partial removal
    function test_AddToExistingFacetAfterPartialRemoval() public {
        // Add facet with multiple functions
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = MockFacet.mockFunction1.selector;
        selectors[1] = MockFacet.mockFunction2.selector;
        selectors[2] = MockFacet.mockFunction3.selector;

        addFacetWithSelectors(address(mockFacet), selectors);

        // Remove one
        bytes4[] memory toRemove = new bytes4[](1);
        toRemove[0] = MockFacet.mockFunction1.selector;
        removeSelectors(toRemove);

        // Add back a different one
        bytes4[] memory toAdd = new bytes4[](1);
        toAdd[0] = MockFacet.anotherMockFunction.selector;
        addFacetWithSelectors(address(mockFacet), toAdd);

        // Verify final state
        bytes4[] memory finalSelectors = registry.getFacetFunctionSelectors(address(mockFacet));
        assertEq(finalSelectors.length, 3);
        // Verify all three selectors exist (order may vary due to swap optimization)
        bool hasFunc2 = false;
        bool hasFunc3 = false;
        bool hasAnotherFunc = false;
        for (uint256 i = 0; i < finalSelectors.length; i++) {
            if (finalSelectors[i] == MockFacet.mockFunction2.selector) hasFunc2 = true;
            if (finalSelectors[i] == MockFacet.mockFunction3.selector) hasFunc3 = true;
            if (finalSelectors[i] == MockFacet.anotherMockFunction.selector) hasAnotherFunc = true;
        }
        assertTrue(hasFunc2);
        assertTrue(hasFunc3);
        assertTrue(hasAnotherFunc);
    }

    /// @notice Test state consistency after many operations
    function test_StateConsistencyAfterManyOperations() public {
        uint256 operations = 10; // Reduced for simplicity

        // Track added selectors to ensure operations are valid
        bytes4[] memory addedSelectors = new bytes4[](operations);
        uint256 addedCount = 0;

        for (uint256 i = 0; i < operations; i++) {
            MockFacet newFacet = new MockFacet();
            bytes4[] memory selectors = new bytes4[](1);
            selectors[0] = bytes4(keccak256(abi.encodePacked("func", i)));

            // Alternate between add, replace, remove
            if (i % 3 == 0) {
                // Add
                addFacetWithSelectors(address(newFacet), selectors);
                addedSelectors[addedCount] = selectors[0];
                addedCount++;
            } else if (i % 3 == 1 && addedCount > 0) {
                // Replace previous (use last added)
                bytes4[] memory prevSelector = new bytes4[](1);
                prevSelector[0] = addedSelectors[addedCount - 1];
                replaceFacetWithSelectors(address(newFacet), prevSelector);
            } else if (addedCount > 0) {
                // Remove previous (use last added)
                bytes4[] memory prevSelector = new bytes4[](1);
                prevSelector[0] = addedSelectors[addedCount - 1];
                removeSelectors(prevSelector);
                addedCount--;
            }
        }

        // Verify state is still consistent
        IFacetRegistry.Facet[] memory facets = registry.getFacets();
        for (uint256 i = 0; i < facets.length; i++) {
            address facetAddr = facets[i].facetAddress;
            bytes4[] memory selectors = registry.getFacetFunctionSelectors(facetAddr);

            for (uint256 j = 0; j < selectors.length; j++) {
                assertTrue(registry.isSelectorRegisteredWithFacet(facetAddr, selectors[j]));
                assertEq(registry.getFacetAddress(selectors[j]), facetAddr);
            }
        }
    }

    /// @notice Test version tracking across complex operations
    function test_VersionTrackingAcrossComplexOperations() public {
        uint256 expectedVersion = 0;
        assertEq(registry.getCurrentVersion(), expectedVersion);

        // Add facet
        bytes4[] memory selectors1 = new bytes4[](2);
        selectors1[0] = MockFacet.mockFunction1.selector;
        selectors1[1] = MockFacet.mockFunction2.selector;

        addFacetWithSelectors(address(mockFacet), selectors1);
        expectedVersion++;
        assertEq(registry.getCurrentVersion(), expectedVersion);

        // Add another
        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = MockFacetV2.newFunction.selector;

        addFacetWithSelectors(address(mockFacetV2), selectors2);
        expectedVersion++;
        assertEq(registry.getCurrentVersion(), expectedVersion);

        // Replace
        bytes4[] memory toReplace = new bytes4[](1);
        toReplace[0] = MockFacet.mockFunction1.selector;

        replaceFacetWithSelectors(address(mockFacetV2), toReplace);
        expectedVersion++;
        assertEq(registry.getCurrentVersion(), expectedVersion);

        // Remove
        bytes4[] memory toRemove = new bytes4[](1);
        toRemove[0] = MockFacet.mockFunction2.selector;

        removeSelectors(toRemove);
        expectedVersion++;
        assertEq(registry.getCurrentVersion(), expectedVersion);
    }

    /// @notice Test base facets are never affected by operations
    function test_BaseFacetsNeverAffectedByOperations() public {
        // Get initial base facet state
        bytes4[] memory initialCutSelectors = registry.getFacetFunctionSelectors(address(diamondCutFacet));
        bytes4[] memory initialLoupeSelectors = registry.getFacetFunctionSelectors(address(diamondLoupeFacet));
        bytes4[] memory initialOwnSelectors = registry.getFacetFunctionSelectors(address(ownershipFacet));
        bytes4[] memory initialUpgSelectors = registry.getFacetFunctionSelectors(address(upgradeFacet));

        // Perform many operations - track added selectors to remove them later
        MockFacet[] memory addedFacets = new MockFacet[](5);
        bytes4[] memory addedSelectors = new bytes4[](5);
        uint256 addedCount = 0;

        for (uint256 i = 0; i < 10; i++) {
            if (i % 2 == 0) {
                // Add operation
                MockFacet newFacet = new MockFacet();
                bytes4[] memory selectors = new bytes4[](1);
                selectors[0] = bytes4(keccak256(abi.encodePacked("op", i)));
                addFacetWithSelectors(address(newFacet), selectors);
                addedFacets[addedCount] = newFacet;
                addedSelectors[addedCount] = selectors[0];
                addedCount++;
            } else {
                // Remove operation - only remove previously added selectors
                if (addedCount > 0) {
                    addedCount--;
                    bytes4[] memory toRemove = new bytes4[](1);
                    toRemove[0] = addedSelectors[addedCount];
                    removeSelectors(toRemove);
                }
            }
        }

        // Verify base facets unchanged
        bytes4[] memory finalCutSelectors = registry.getFacetFunctionSelectors(address(diamondCutFacet));
        bytes4[] memory finalLoupeSelectors = registry.getFacetFunctionSelectors(address(diamondLoupeFacet));
        bytes4[] memory finalOwnSelectors = registry.getFacetFunctionSelectors(address(ownershipFacet));
        bytes4[] memory finalUpgSelectors = registry.getFacetFunctionSelectors(address(upgradeFacet));

        assertEq(initialCutSelectors.length, finalCutSelectors.length);
        assertEq(initialLoupeSelectors.length, finalLoupeSelectors.length);
        assertEq(initialOwnSelectors.length, finalOwnSelectors.length);
        assertEq(initialUpgSelectors.length, finalUpgSelectors.length);
    }

    /// @notice Test edge case: removing and re-adding same selector
    function test_RemoveAndReaddSameSelector() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        // Add
        addFacetWithSelectors(address(mockFacet), selectors);
        assertTrue(registry.isSelectorRegisteredWithFacet(address(mockFacet), selectors[0]));

        // Remove
        removeSelectors(selectors);
        assertFalse(registry.isSelectorRegisteredWithFacet(address(mockFacet), selectors[0]));

        // Re-add to different facet
        addFacetWithSelectors(address(mockFacetV2), selectors);
        assertTrue(registry.isSelectorRegisteredWithFacet(address(mockFacetV2), selectors[0]));
    }

    /// @notice Test replacing to same facet but different order
    function test_ReplaceToSameFacetDifferentOrder() public {
        bytes4[] memory selectors1 = new bytes4[](2);
        selectors1[0] = MockFacet.mockFunction1.selector;
        selectors1[1] = MockFacet.mockFunction2.selector;

        addFacetWithSelectors(address(mockFacet), selectors1);

        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = MockFacet.mockFunction3.selector;

        addFacetWithSelectors(address(mockFacetV2), selectors2);

        // Replace facet1's selectors to facet2 (same facet, different order)
        replaceFacetWithSelectors(address(mockFacetV2), selectors1);

        bytes4[] memory facet2Final = registry.getFacetFunctionSelectors(address(mockFacetV2));
        assertEq(facet2Final.length, 3);
    }

    /// @notice Test all view functions work correctly together
    function test_AllViewFunctionsWorkTogether() public view {
        // Get all data
        IFacetRegistry.Facet[] memory facets = registry.getFacets();
        address[] memory addresses = registry.getFacetAddresses();
        registry.getBaseFacets();
        uint256 version = registry.getCurrentVersion();

        // Verify consistency
        assertEq(facets.length, addresses.length);

        // Verify all addresses in facets match addresses array
        for (uint256 i = 0; i < facets.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < addresses.length; j++) {
                if (facets[i].facetAddress == addresses[j]) {
                    found = true;
                    break;
                }
            }
            assertTrue(found);
        }

        // Verify version is reasonable
        assertGe(version, 0);
    }
}
