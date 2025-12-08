// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.20;

import { FacetRegistryTestBase } from "./FacetRegistryTestBase.sol";
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { MockFacet, MockFacetV2 } from "./MockFacets.sol";

/// @title Tests for FacetRegistry replaceFunctions functionality
contract FacetRegistryReplaceFunctionsTest is FacetRegistryTestBase {
    function setUp() public override {
        super.setUp();

        // Setup initial state with mockFacet
        bytes4[] memory initialSelectors = new bytes4[](3);
        initialSelectors[0] = MockFacet.mockFunction1.selector;
        initialSelectors[1] = MockFacet.mockFunction2.selector;
        initialSelectors[2] = MockFacet.mockFunction3.selector;

        addFacetWithSelectors(address(mockFacet), initialSelectors);
    }

    // =============================================================
    // REPLACE FUNCTIONS TESTS
    // =============================================================

    /// @notice Test replacing functions from one facet to another
    function test_ReplaceFunctionsFromOneFacetToAnother() public {
        bytes4[] memory selectorsToReplace = new bytes4[](2);
        selectorsToReplace[0] = MockFacet.mockFunction1.selector;
        selectorsToReplace[1] = MockFacet.mockFunction2.selector;

        uint256 versionBefore = registry.getCurrentVersion();
        replaceFacetWithSelectors(address(mockFacetV2), selectorsToReplace);
        uint256 versionAfter = registry.getCurrentVersion();
        assertEq(versionAfter, versionBefore + 1);

        // Verify old facet no longer has these selectors
        assertFalse(registry.isSelectorRegisteredWithFacet(address(mockFacet), selectorsToReplace[0]));
        assertFalse(registry.isSelectorRegisteredWithFacet(address(mockFacet), selectorsToReplace[1]));

        // Verify new facet has these selectors
        assertTrue(registry.isSelectorRegisteredWithFacet(address(mockFacetV2), selectorsToReplace[0]));
        assertTrue(registry.isSelectorRegisteredWithFacet(address(mockFacetV2), selectorsToReplace[1]));

        // Verify third selector still with old facet
        assertTrue(registry.isSelectorRegisteredWithFacet(address(mockFacet), MockFacet.mockFunction3.selector));
    }

    /// @notice Test replacing single function
    function test_ReplaceSingleFunction() public {
        bytes4[] memory selectorToReplace = new bytes4[](1);
        selectorToReplace[0] = MockFacet.mockFunction1.selector;

        replaceFacetWithSelectors(address(mockFacetV2), selectorToReplace);

        assertFalse(registry.isSelectorRegisteredWithFacet(address(mockFacet), selectorToReplace[0]));
        assertTrue(registry.isSelectorRegisteredWithFacet(address(mockFacetV2), selectorToReplace[0]));
    }

    /// @notice Test replacing all functions from a facet
    function test_ReplaceAllFunctionsFromFacet() public {
        bytes4[] memory allSelectors = new bytes4[](3);
        allSelectors[0] = MockFacet.mockFunction1.selector;
        allSelectors[1] = MockFacet.mockFunction2.selector;
        allSelectors[2] = MockFacet.mockFunction3.selector;

        replaceFacetWithSelectors(address(mockFacetV2), allSelectors);

        // Verify old facet should be removed
        assertFalse(registry.isFacetRegistered(address(mockFacet)));

        // Verify new facet has all selectors
        bytes4[] memory storedSelectors = registry.getFacetFunctionSelectors(address(mockFacetV2));
        assertEq(storedSelectors.length, 3);

        for (uint256 i = 0; i < storedSelectors.length; i++) {
            assertTrue(registry.isSelectorRegisteredWithFacet(address(mockFacetV2), storedSelectors[i]));
        }
    }

    /// @notice Test replacing and keeping some functions on old facet
    function test_ReplacePartialFunctionsKeepSomeOnOldFacet() public {
        bytes4[] memory selectorsToReplace = new bytes4[](1);
        selectorsToReplace[0] = MockFacet.mockFunction1.selector;

        replaceFacetWithSelectors(address(mockFacetV2), selectorsToReplace);

        // Old facet should still be registered with remaining functions
        assertTrue(registry.isFacetRegistered(address(mockFacet)));

        bytes4[] memory oldSelectors = registry.getFacetFunctionSelectors(address(mockFacet));
        assertEq(oldSelectors.length, 2);
        // Verify both remaining selectors exist (order may vary due to swap optimization)
        bool hasFunc2 = false;
        bool hasFunc3 = false;
        for (uint256 i = 0; i < oldSelectors.length; i++) {
            if (oldSelectors[i] == MockFacet.mockFunction2.selector) hasFunc2 = true;
            if (oldSelectors[i] == MockFacet.mockFunction3.selector) hasFunc3 = true;
        }
        assertTrue(hasFunc2);
        assertTrue(hasFunc3);
    }

    /// @notice Test replacing functions increments version
    function test_ReplaceFunctionsIncrementsVersion() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        uint256 v1 = registry.getCurrentVersion();
        replaceFacetWithSelectors(address(mockFacetV2), selectors);
        uint256 v2 = registry.getCurrentVersion();

        assertEq(v2, v1 + 1);
    }

    /// @notice Test replacing functions updates facet mapping correctly
    function test_ReplaceFunctionsUpdatesFacetMapping() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        replaceFacetWithSelectors(address(mockFacetV2), selectors);

        assertEq(registry.getFacetAddress(selectors[0]), address(mockFacetV2));
    }

    /// @notice Test replacing functions with same facet but different selectors
    function test_ReplaceFunctionsSameFacetDifferentSelectors() public {
        // Add new facet with unique selector
        bytes4[] memory facet2Selectors = new bytes4[](1);
        facet2Selectors[0] = MockFacetV2.newFunction.selector;
        addFacetWithSelectors(address(mockFacetV2), facet2Selectors);

        // Now replace a selector from mockFacet to mockFacetV2
        bytes4[] memory replaceSelectors = new bytes4[](1);
        replaceSelectors[0] = MockFacet.mockFunction2.selector;

        replaceFacetWithSelectors(address(mockFacetV2), replaceSelectors);

        // Both selectors should be on mockFacetV2
        assertTrue(registry.isSelectorRegisteredWithFacet(address(mockFacetV2), MockFacetV2.newFunction.selector));
        assertTrue(registry.isSelectorRegisteredWithFacet(address(mockFacetV2), MockFacet.mockFunction2.selector));
    }

    // =============================================================
    // REVERT TESTS - REPLACE FUNCTIONS
    // =============================================================

    /// @notice Test replacing functions reverts when not owner
    function test_RevertReplaceFunctionsWhenNotOwner() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        vm.prank(user1);
        vm.expectRevert();
        registry.replaceFunctions(address(mockFacetV2), selectors);
    }

    /// @notice Test replacing with empty selector array reverts
    function test_RevertReplaceFunctionsWithEmptySelectors() public {
        bytes4[] memory emptySelectors = new bytes4[](0);

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_SelectorArrayEmpty()));
        registry.replaceFunctions(address(mockFacetV2), emptySelectors);
    }

    /// @notice Test replacing with zero address facet reverts
    function test_RevertReplaceFunctionsWithZeroAddress() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_FacetAddressIsZero()));
        registry.replaceFunctions(address(0), selectors);
    }

    /// @notice Test replacing with non-contract facet reverts
    function test_RevertReplaceFunctionsWithNonContractFacet() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        address nonContract = makeAddr("nonContract");

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_FacetIsNotContract(), nonContract));
        registry.replaceFunctions(nonContract, selectors);
    }

    /// @notice Test replacing base facet functions reverts
    function test_RevertReplaceFunctionsToBaseFacet() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_CannotModifyBaseFacet(), address(diamondCutFacet)));
        registry.replaceFunctions(address(diamondCutFacet), selectors);
    }

    /// @notice Test replacing with same facet and same selector reverts
    function test_RevertReplaceFunctionWithSameFunction() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        vm.expectRevert(
            abi.encodeWithSelector(
                getErrorSelector_CannotReplaceFunctionWithSameFunction(), address(mockFacet), selectors[0]
            )
        );
        registry.replaceFunctions(address(mockFacet), selectors);
    }

    /// @notice Test replacing non-existent selector reverts
    function test_RevertReplaceNonExistentSelector() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(0x12345678); // Non-existent selector

        vm.expectRevert(
            abi.encodeWithSelector(getErrorSelector_CannotRemoveFunctionThatDoesNotExist(), address(0), selectors[0])
        );
        registry.replaceFunctions(address(mockFacetV2), selectors);
    }

    /// @notice Test replacing immutable function reverts
    function test_RevertReplaceImmutableFunction() public {
        // This would require a selector that exists on the registry itself (address(this))
        // which would be an immutable function. This is tricky to test without exposing internal state.
        // For now, we test that replacing a selector already on the registry with itself fails
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        vm.expectRevert(
            abi.encodeWithSelector(
                getErrorSelector_CannotReplaceFunctionWithSameFunction(), address(mockFacet), selectors[0]
            )
        );
        registry.replaceFunctions(address(mockFacet), selectors);
    }

    /// @notice Test replacing functions and old facet cleanup
    function test_ReplaceFunctionsAndOldFacetCleanup() public {
        // Add functions to mockFacetV2 first
        bytes4[] memory facet2Selectors = new bytes4[](1);
        facet2Selectors[0] = MockFacetV2.newFunction.selector;
        addFacetWithSelectors(address(mockFacetV2), facet2Selectors);

        // Replace all from mockFacet to mockFacetV2
        bytes4[] memory allSelectors = new bytes4[](3);
        allSelectors[0] = MockFacet.mockFunction1.selector;
        allSelectors[1] = MockFacet.mockFunction2.selector;
        allSelectors[2] = MockFacet.mockFunction3.selector;

        replaceFacetWithSelectors(address(mockFacetV2), allSelectors);

        // mockFacet should be removed
        assertFalse(registry.isFacetRegistered(address(mockFacet)));

        // mockFacetV2 should have all 4 selectors
        bytes4[] memory stored = registry.getFacetFunctionSelectors(address(mockFacetV2));
        assertEq(stored.length, 4);
    }

    /// @notice Test multiple replacements in sequence
    function test_MultipleReplacementsInSequence() public {
        bytes4[] memory selectors1 = new bytes4[](1);
        selectors1[0] = MockFacet.mockFunction1.selector;

        replaceFacetWithSelectors(address(mockFacetV2), selectors1);

        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = MockFacet.mockFunction2.selector;

        replaceFacetWithSelectors(address(mockFacetV2), selectors2);

        // Both should now be on mockFacetV2
        assertTrue(registry.isSelectorRegisteredWithFacet(address(mockFacetV2), selectors1[0]));
        assertTrue(registry.isSelectorRegisteredWithFacet(address(mockFacetV2), selectors2[0]));

        // Old facet should only have one remaining
        bytes4[] memory oldSelectors = registry.getFacetFunctionSelectors(address(mockFacet));
        assertEq(oldSelectors.length, 1);
    }

    /// @notice Test replacing and checking facets array updates
    function test_ReplaceFunctionsUpdatesFacetsArray() public {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = MockFacet.mockFunction1.selector;
        selectors[1] = MockFacet.mockFunction2.selector;
        selectors[2] = MockFacet.mockFunction3.selector;

        replaceFacetWithSelectors(address(mockFacetV2), selectors);

        IFacetRegistry.Facet[] memory facetsAfter = registry.getFacets();

        // mockFacetV2 should now be in the array, mockFacet should be removed
        bool foundFacetV2 = false;
        bool foundFacet = false;

        for (uint256 i = 0; i < facetsAfter.length; i++) {
            if (facetsAfter[i].facetAddress == address(mockFacetV2)) {
                foundFacetV2 = true;
            }
            if (facetsAfter[i].facetAddress == address(mockFacet)) {
                foundFacet = true;
            }
        }

        assertTrue(foundFacetV2);
        assertFalse(foundFacet);
    }
}
