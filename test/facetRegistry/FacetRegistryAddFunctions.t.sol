// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.20;

import { FacetRegistryTestBase } from "./FacetRegistryTestBase.sol";
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { MockFacet, MockFacetV2 } from "./MockFacets.sol";

/// @title Tests for FacetRegistry addFunctions functionality
contract FacetRegistryAddFunctionsTest is FacetRegistryTestBase {
    function setUp() public override {
        super.setUp();
    }

    // =============================================================
    // ADD FUNCTIONS TESTS
    // =============================================================

    /// @notice Test adding functions to a new facet
    function test_AddFunctionsToNewFacet() public {
        bytes4[] memory mockSelectors = new bytes4[](2);
        mockSelectors[0] = MockFacet.mockFunction1.selector;
        mockSelectors[1] = MockFacet.mockFunction2.selector;

        uint256 versionBefore = registry.getCurrentVersion();
        addFacetWithSelectors(address(mockFacet), mockSelectors);

        uint256 versionAfter = registry.getCurrentVersion();
        assertEq(versionAfter, versionBefore + 1);

        // Verify facet is registered
        assertTrue(registry.isFacetRegistered(address(mockFacet)));

        // Verify selectors are registered
        assertTrue(registry.isSelectorRegisteredWithFacet(address(mockFacet), mockSelectors[0]));
        assertTrue(registry.isSelectorRegisteredWithFacet(address(mockFacet), mockSelectors[1]));

        // Verify getters return correct values
        bytes4[] memory storedSelectors = registry.getFacetFunctionSelectors(address(mockFacet));
        assertEq(storedSelectors.length, 2);
        assertEq(storedSelectors[0], mockSelectors[0]);
        assertEq(storedSelectors[1], mockSelectors[1]);

        address facetAddress = registry.getFacetAddress(mockSelectors[0]);
        assertEq(facetAddress, address(mockFacet));
    }

    /// @notice Test adding single function to new facet
    function test_AddSingleFunction() public {
        bytes4[] memory singleSelector = new bytes4[](1);
        singleSelector[0] = MockFacet.mockFunction1.selector;

        addFacetWithSelectors(address(mockFacet), singleSelector);

        assertTrue(registry.isFacetRegistered(address(mockFacet)));
        assertTrue(registry.isSelectorRegisteredWithFacet(address(mockFacet), singleSelector[0]));

        bytes4[] memory selectors = registry.getFacetFunctionSelectors(address(mockFacet));
        assertEq(selectors.length, 1);
    }

    /// @notice Test adding functions to existing facet
    function test_AddFunctionsToExistingFacet() public {
        // Add initial functions
        bytes4[] memory initialSelectors = new bytes4[](2);
        initialSelectors[0] = MockFacet.mockFunction1.selector;
        initialSelectors[1] = MockFacet.mockFunction2.selector;

        addFacetWithSelectors(address(mockFacet), initialSelectors);

        // Add more functions to the same facet
        bytes4[] memory additionalSelectors = new bytes4[](2);
        additionalSelectors[0] = MockFacet.mockFunction3.selector;
        additionalSelectors[1] = MockFacet.anotherMockFunction.selector;

        uint256 versionBefore = registry.getCurrentVersion();
        addFacetWithSelectors(address(mockFacet), additionalSelectors);
        uint256 versionAfter = registry.getCurrentVersion();
        assertEq(versionAfter, versionBefore + 1);

        // Verify all selectors are registered
        bytes4[] memory allSelectors = registry.getFacetFunctionSelectors(address(mockFacet));
        assertEq(allSelectors.length, 4);
        assertEq(allSelectors[0], initialSelectors[0]);
        assertEq(allSelectors[1], initialSelectors[1]);
        assertEq(allSelectors[2], additionalSelectors[0]);
        assertEq(allSelectors[3], additionalSelectors[1]);
    }

    /// @notice Test adding multiple facets
    function test_AddMultipleFacets() public {
        // Add first facet
        bytes4[] memory facet1Selectors = new bytes4[](1);
        facet1Selectors[0] = MockFacet.mockFunction1.selector;

        addFacetWithSelectors(address(mockFacet), facet1Selectors);

        // Add second facet
        bytes4[] memory facet2Selectors = new bytes4[](1);
        facet2Selectors[0] = MockFacetV2.newFunction.selector;

        addFacetWithSelectors(address(mockFacetV2), facet2Selectors);

        // Verify both are registered
        assertTrue(registry.isFacetRegistered(address(mockFacet)));
        assertTrue(registry.isFacetRegistered(address(mockFacetV2)));

        // Verify correct selectors mapped
        assertEq(registry.getFacetAddress(facet1Selectors[0]), address(mockFacet));
        assertEq(registry.getFacetAddress(facet2Selectors[0]), address(mockFacetV2));
    }

    /// @notice Test version increments on each add
    function test_VersionIncrementsOnAdd() public {
        bytes4[] memory selectors1 = new bytes4[](1);
        selectors1[0] = MockFacet.mockFunction1.selector;

        uint256 v1 = registry.getCurrentVersion();
        addFacetWithSelectors(address(mockFacet), selectors1);
        uint256 v2 = registry.getCurrentVersion();

        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = MockFacetV2.newFunction.selector;
        addFacetWithSelectors(address(mockFacetV2), selectors2);
        uint256 v3 = registry.getCurrentVersion();

        assertEq(v2, v1 + 1);
        assertEq(v3, v2 + 1);
    }

    /// @notice Test facets array grows correctly
    function test_FacetsArrayGrowsCorrectly() public {
        IFacetRegistry.Facet[] memory facetsBefore = registry.getFacets();
        uint256 countBefore = facetsBefore.length;

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        addFacetWithSelectors(address(mockFacet), selectors);

        IFacetRegistry.Facet[] memory facetsAfter = registry.getFacets();
        assertEq(facetsAfter.length, countBefore + 1);
        assertEq(facetsAfter[countBefore].facetAddress, address(mockFacet));
    }

    /// @notice Test facet addresses array grows correctly
    function test_FacetAddressesArrayGrowsCorrectly() public {
        address[] memory addressesBefore = registry.getFacetAddresses();
        uint256 countBefore = addressesBefore.length;

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        addFacetWithSelectors(address(mockFacet), selectors);

        address[] memory addressesAfter = registry.getFacetAddresses();
        assertEq(addressesAfter.length, countBefore + 1);
        assertEq(addressesAfter[countBefore], address(mockFacet));
    }

    // =============================================================
    // REVERT TESTS - ADD FUNCTIONS
    // =============================================================

    /// @notice Test adding functions reverts when not owner
    function test_RevertAddFunctionsWhenNotOwner() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        vm.prank(user1);
        vm.expectRevert();
        registry.addFunctions(address(mockFacet), selectors);
    }

    /// @notice Test adding empty selector array reverts
    function test_RevertAddFunctionsWithEmptySelectors() public {
        bytes4[] memory emptySelectors = new bytes4[](0);

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_SelectorArrayEmpty()));
        registry.addFunctions(address(mockFacet), emptySelectors);
    }

    /// @notice Test adding functions with zero address facet reverts
    function test_RevertAddFunctionsWithZeroAddress() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_FacetAddressIsZero()));
        registry.addFunctions(address(0), selectors);
    }

    /// @notice Test adding functions with non-contract facet reverts
    function test_RevertAddFunctionsWithNonContractFacet() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        address nonContract = makeAddr("nonContract");

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_FacetIsNotContract(), nonContract));
        registry.addFunctions(nonContract, selectors);
    }

    /// @notice Test adding already registered selector reverts
    function test_RevertAddFunctionsWithExistingSelector() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        addFacetWithSelectors(address(mockFacet), selectors);

        // Try to add the same selector again
        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_CannotAddFunctionThatAlreadyExists(), selectors[0]));
        registry.addFunctions(address(mockFacetV2), selectors);
    }

    /// @notice Test adding already registered selector from different facet reverts
    function test_RevertAddFunctionsWithExistingSelectorDifferentFacet() public {
        bytes4[] memory selectors1 = new bytes4[](1);
        selectors1[0] = MockFacet.mockFunction1.selector;

        addFacetWithSelectors(address(mockFacet), selectors1);

        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = MockFacet.mockFunction1.selector; // Same selector

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_CannotAddFunctionThatAlreadyExists(), selectors2[0]));
        registry.addFunctions(address(mockFacetV2), selectors2);
    }

    /// @notice Test adding base facet functions reverts
    function test_RevertAddFunctionsToBaseFacet() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_CannotModifyBaseFacet(), address(diamondCutFacet)));
        registry.addFunctions(address(diamondCutFacet), selectors);
    }

    /// @notice Test that getFacetAddress returns address(0) for non-existent selector
    function test_GetFacetAddressReturnsZeroForNonExistentSelector() public view {
        bytes4 nonExistentSelector = bytes4(0x12345678);
        address facet = registry.getFacetAddress(nonExistentSelector);
        assertEq(facet, address(0));
    }

    /// @notice Test that isFacetRegistered returns false for non-existent facet
    function test_IsFacetRegisteredReturnsFalseForNonExistent() public view {
        assertFalse(registry.isFacetRegistered(address(mockFacet)));
    }

    /// @notice Test that isSelectorRegistered returns false for non-existent selector
    function test_IsSelectorRegisteredReturnsFalseForNonExistent() public view {
        bytes4 nonExistentSelector = bytes4(0x12345678);
        assertFalse(registry.isSelectorRegisteredWithFacet(address(mockFacet), nonExistentSelector));
    }

    /// @notice Test adding large number of selectors
    function test_AddLargeNumberOfSelectors() public {
        // Create array with many selectors (limited by gas)
        bytes4[] memory manySelectors = new bytes4[](10);
        for (uint256 i = 0; i < 10; i++) {
            manySelectors[i] = bytes4(keccak256(abi.encodePacked("function", i)));
        }

        addFacetWithSelectors(address(mockFacet), manySelectors);

        bytes4[] memory stored = registry.getFacetFunctionSelectors(address(mockFacet));
        assertEq(stored.length, 10);
    }

    /// @notice Test order of selectors is preserved
    function test_SelectorOrderPreserved() public {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = MockFacet.mockFunction1.selector;
        selectors[1] = MockFacet.mockFunction2.selector;
        selectors[2] = MockFacet.mockFunction3.selector;
        selectors[3] = MockFacet.anotherMockFunction.selector;

        addFacetWithSelectors(address(mockFacet), selectors);

        bytes4[] memory stored = registry.getFacetFunctionSelectors(address(mockFacet));
        for (uint256 i = 0; i < selectors.length; i++) {
            assertEq(stored[i], selectors[i]);
        }
    }
}
