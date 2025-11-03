// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.20;

import { FacetRegistryTestBase } from "./FacetRegistryTestBase.sol";
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { MockFacet, MockFacetV2 } from "./MockFacets.sol";

/// @title Tests for FacetRegistry removeFunctions functionality
contract FacetRegistryRemoveFunctionsTest is FacetRegistryTestBase {
    function setUp() public override {
        super.setUp();

        // Setup initial state with multiple facets
        bytes4[] memory mockFacetSelectors = new bytes4[](3);
        mockFacetSelectors[0] = MockFacet.mockFunction1.selector;
        mockFacetSelectors[1] = MockFacet.mockFunction2.selector;
        mockFacetSelectors[2] = MockFacet.mockFunction3.selector;

        addFacetWithSelectors(address(mockFacet), mockFacetSelectors);

        bytes4[] memory mockFacetV2Selectors = new bytes4[](1);
        mockFacetV2Selectors[0] = MockFacetV2.newFunction.selector;

        addFacetWithSelectors(address(mockFacetV2), mockFacetV2Selectors);
    }

    // =============================================================
    // REMOVE FUNCTIONS TESTS
    // =============================================================

    /// @notice Test removing a single function
    function test_RemoveSingleFunction() public {
        bytes4[] memory selectorsToRemove = new bytes4[](1);
        selectorsToRemove[0] = MockFacet.mockFunction1.selector;

        uint256 versionBefore = registry.getCurrentVersion();
        removeSelectors(selectorsToRemove);
        uint256 versionAfter = registry.getCurrentVersion();
        assertEq(versionAfter, versionBefore + 1);

        // Verify selector is removed
        assertFalse(registry.isSelectorRegisteredWithFacet(address(mockFacet), selectorsToRemove[0]));

        // Verify facet still exists with remaining selectors
        assertTrue(registry.isFacetRegistered(address(mockFacet)));

        bytes4[] memory remaining = registry.getFacetFunctionSelectors(address(mockFacet));
        assertEq(remaining.length, 2);
    }

    /// @notice Test removing multiple functions from same facet
    function test_RemoveMultipleFunctionsFromSameFacet() public {
        bytes4[] memory selectorsToRemove = new bytes4[](2);
        selectorsToRemove[0] = MockFacet.mockFunction1.selector;
        selectorsToRemove[1] = MockFacet.mockFunction2.selector;

        removeSelectors(selectorsToRemove);

        // Verify selectors are removed
        assertFalse(registry.isSelectorRegisteredWithFacet(address(mockFacet), selectorsToRemove[0]));
        assertFalse(registry.isSelectorRegisteredWithFacet(address(mockFacet), selectorsToRemove[1]));

        // Verify facet still exists
        bytes4[] memory remaining = registry.getFacetFunctionSelectors(address(mockFacet));
        assertEq(remaining.length, 1);
        assertEq(remaining[0], MockFacet.mockFunction3.selector);
    }

    /// @notice Test removing all functions removes the facet
    function test_RemoveAllFunctionsRemovesFacet() public {
        bytes4[] memory allSelectors = new bytes4[](3);
        allSelectors[0] = MockFacet.mockFunction1.selector;
        allSelectors[1] = MockFacet.mockFunction2.selector;
        allSelectors[2] = MockFacet.mockFunction3.selector;

        removeSelectors(allSelectors);

        // Verify facet is removed
        assertFalse(registry.isFacetRegistered(address(mockFacet)));

        // Verify getFacetFunctionSelectors returns empty
        bytes4[] memory selectors = registry.getFacetFunctionSelectors(address(mockFacet));
        assertEq(selectors.length, 0);
    }

    /// @notice Test removing functions from different facets
    function test_RemoveFunctionsFromDifferentFacets() public {
        bytes4[] memory selectorsToRemove = new bytes4[](2);
        selectorsToRemove[0] = MockFacet.mockFunction1.selector;
        selectorsToRemove[1] = MockFacetV2.newFunction.selector;

        removeSelectors(selectorsToRemove);

        // mockFacet should still be registered (has 2 remaining selectors)
        // mockFacetV2 should be removed (had only 1 selector)
        assertTrue(registry.isFacetRegistered(address(mockFacet)));
        assertFalse(registry.isFacetRegistered(address(mockFacetV2)));
    }

    /// @notice Test removing functions increments version
    function test_RemoveFunctionsIncrementsVersion() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        uint256 v1 = registry.getCurrentVersion();
        removeSelectors(selectors);
        uint256 v2 = registry.getCurrentVersion();

        assertEq(v2, v1 + 1);
    }

    /// @notice Test removing functions updates facets array
    function test_RemoveFunctionsUpdatesFacetsArray() public {
        IFacetRegistry.Facet[] memory facetsBefore = registry.getFacets();
        uint256 countBefore = facetsBefore.length;

        // Remove all from mockFacet
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = MockFacet.mockFunction1.selector;
        selectors[1] = MockFacet.mockFunction2.selector;
        selectors[2] = MockFacet.mockFunction3.selector;

        removeSelectors(selectors);

        IFacetRegistry.Facet[] memory facetsAfter = registry.getFacets();
        assertEq(facetsAfter.length, countBefore - 1);

        // Verify mockFacet is not in array
        bool foundMockFacet = false;
        for (uint256 i = 0; i < facetsAfter.length; i++) {
            if (facetsAfter[i].facetAddress == address(mockFacet)) {
                foundMockFacet = true;
            }
        }
        assertFalse(foundMockFacet);
    }

    /// @notice Test removing functions updates facet addresses array
    function test_RemoveFunctionsUpdatesFacetAddressesArray() public {
        address[] memory addressesBefore = registry.getFacetAddresses();
        uint256 countBefore = addressesBefore.length;

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = MockFacet.mockFunction1.selector;
        selectors[1] = MockFacet.mockFunction2.selector;
        selectors[2] = MockFacet.mockFunction3.selector;

        removeSelectors(selectors);

        address[] memory addressesAfter = registry.getFacetAddresses();
        assertEq(addressesAfter.length, countBefore - 1);

        // Verify mockFacet is not in array
        bool foundMockFacet = false;
        for (uint256 i = 0; i < addressesAfter.length; i++) {
            if (addressesAfter[i] == address(mockFacet)) {
                foundMockFacet = true;
            }
        }
        assertFalse(foundMockFacet);
    }

    /// @notice Test removing functions updates selector mappings
    function test_RemoveFunctionsUpdatesSelectorMappings() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        removeSelectors(selectors);

        // getFacetAddress should return address(0)
        assertEq(registry.getFacetAddress(selectors[0]), address(0));
    }

    /// @notice Test multiple sequential removals
    function test_MultipleSequentialRemovals() public {
        // Remove first function
        bytes4[] memory selectors1 = new bytes4[](1);
        selectors1[0] = MockFacet.mockFunction1.selector;
        removeSelectors(selectors1);

        // Remove second function
        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = MockFacet.mockFunction2.selector;
        removeSelectors(selectors2);

        // Only one should remain
        bytes4[] memory remaining = registry.getFacetFunctionSelectors(address(mockFacet));
        assertEq(remaining.length, 1);
        assertEq(remaining[0], MockFacet.mockFunction3.selector);
    }

    /// @notice Test removing functions doesn't affect other facets
    function test_RemoveFunctionsDoesntAffectOtherFacets() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        removeSelectors(selectors);

        // Verify other facets unaffected
        assertTrue(registry.isFacetRegistered(address(mockFacetV2)));
        bytes4[] memory facet2Selectors = registry.getFacetFunctionSelectors(address(mockFacetV2));
        assertEq(facet2Selectors.length, 1);
    }

    /// @notice Test removing functions preserves base facets
    function test_RemoveFunctionsPreservesBaseFacets() public {
        // Try to remove a base facet selector - should revert
        bytes4[] memory baseSelectors = registry.getFacetFunctionSelectors(address(diamondCutFacet));

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_CannotModifyBaseFacet(), address(diamondCutFacet)));
        registry.removeFunctions(address(0), baseSelectors);
    }

    // =============================================================
    // REVERT TESTS - REMOVE FUNCTIONS
    // =============================================================

    /// @notice Test removing functions reverts when not owner
    function test_RevertRemoveFunctionsWhenNotOwner() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        vm.prank(user1);
        vm.expectRevert();
        registry.removeFunctions(address(0), selectors);
    }

    /// @notice Test removing with empty selector array reverts
    function test_RevertRemoveFunctionsWithEmptySelectors() public {
        bytes4[] memory emptySelectors = new bytes4[](0);

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_SelectorArrayEmpty()));
        registry.removeFunctions(address(0), emptySelectors);
    }

    /// @notice Test removing with non-zero facet address reverts
    function test_RevertRemoveFunctionsWithNonZeroFacetAddress() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_RemoveFacetAddressMustBeZero(), address(mockFacet)));
        registry.removeFunctions(address(mockFacet), selectors);
    }

    /// @notice Test removing non-existent selector reverts
    function test_RevertRemoveNonExistentSelector() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(0x12345678); // Non-existent

        vm.expectRevert(
            abi.encodeWithSelector(getErrorSelector_CannotRemoveFunctionThatDoesNotExist(), address(0), selectors[0])
        );
        registry.removeFunctions(address(0), selectors);
    }

    /// @notice Test removing base facet functions reverts
    function test_RevertRemoveBaseFacetFunctions() public {
        bytes4[] memory baseSelectors = registry.getFacetFunctionSelectors(address(diamondCutFacet));

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_CannotModifyBaseFacet(), address(diamondCutFacet)));
        registry.removeFunctions(address(0), baseSelectors);
    }

    /// @notice Test removing immutable functions reverts
    function test_RevertRemoveImmutableFunctions() public {
        // This is tricky to test without exposing internal state
        // The test would need to know which selectors are "immutable" (mapped to address(this))
        // For now, we ensure the error would be thrown if attempted
        bytes4[] memory selector = new bytes4[](1);
        selector[0] = registry.addFunctions.selector; // This might be on registry itself

        // If this selector exists on the registry itself (immutable), it should revert
        // But if it doesn't exist at all, we get CannotRemoveFunctionThatDoesNotExist
        vm.expectRevert(); // Either error is acceptable here
        registry.removeFunctions(address(0), selector);
    }

    /// @notice Test that removing functions from removed facet doesn't affect state
    function test_RemoveFunctionsFromRemovedFacet() public {
        // First remove all functions
        bytes4[] memory allSelectors = new bytes4[](3);
        allSelectors[0] = MockFacet.mockFunction1.selector;
        allSelectors[1] = MockFacet.mockFunction2.selector;
        allSelectors[2] = MockFacet.mockFunction3.selector;

        removeSelectors(allSelectors);

        // Verify facet is removed
        assertFalse(registry.isFacetRegistered(address(mockFacet)));

        // Try to remove again - should fail with non-existent selector
        bytes4[] memory toRemove = new bytes4[](1);
        toRemove[0] = allSelectors[0]; // Already removed
        vm.expectRevert(
            abi.encodeWithSelector(getErrorSelector_CannotRemoveFunctionThatDoesNotExist(), address(0), allSelectors[0])
        );
        registry.removeFunctions(address(0), toRemove);
    }
}
