// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.20;

import { FacetRegistryTestBase } from "./FacetRegistryTestBase.sol";
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";
import { IDiamondLoupe } from "src/diamond/facets/baseFacets/loupe/IDiamondLoupe.sol";
import { MockFacet, MockFacetV2 } from "./MockFacets.sol";

/// @title Tests for FacetRegistry version management
contract FacetRegistryVersionManagementTest is FacetRegistryTestBase {
    function setUp() public override {
        super.setUp();
    }

    // =============================================================
    // VERSION MANAGEMENT TESTS
    // =============================================================

    /// @notice Test initial version is zero
    function test_InitialVersionIsZero() public view {
        assertEq(registry.getCurrentVersion(), 0);
    }

    /// @notice Test version increments on add
    function test_VersionIncrementsOnAdd() public {
        uint256 v0 = registry.getCurrentVersion();
        assertEq(v0, 0);

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        addFacetWithSelectors(address(mockFacet), selectors);

        uint256 v1 = registry.getCurrentVersion();
        assertEq(v1, 1);
    }

    /// @notice Test version increments on replace
    function test_VersionIncrementsOnReplace() public {
        // First add
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        addFacetWithSelectors(address(mockFacet), selectors);
        uint256 v1 = registry.getCurrentVersion();

        // Then replace
        replaceFacetWithSelectors(address(mockFacetV2), selectors);
        uint256 v2 = registry.getCurrentVersion();

        assertEq(v2, v1 + 1);
    }

    /// @notice Test version increments on remove
    function test_VersionIncrementsOnRemove() public {
        // First add
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        addFacetWithSelectors(address(mockFacet), selectors);
        uint256 v1 = registry.getCurrentVersion();

        // Then remove
        removeSelectors(selectors);
        uint256 v2 = registry.getCurrentVersion();

        assertEq(v2, v1 + 1);
    }

    /// @notice Test version increments sequentially
    function test_VersionIncrementsSequentially() public {
        uint256 v0 = registry.getCurrentVersion();
        assertEq(v0, 0);

        bytes4[] memory selectors1 = new bytes4[](1);
        selectors1[0] = MockFacet.mockFunction1.selector;

        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = MockFacet.mockFunction2.selector;

        addFacetWithSelectors(address(mockFacet), selectors1);
        uint256 v1 = registry.getCurrentVersion();
        assertEq(v1, 1);

        addFacetWithSelectors(address(mockFacetV2), selectors2);
        uint256 v2 = registry.getCurrentVersion();
        assertEq(v2, 2);

        replaceFacetWithSelectors(address(mockFacetV2), selectors1);
        uint256 v3 = registry.getCurrentVersion();
        assertEq(v3, 3);

        removeSelectors(selectors2);
        uint256 v4 = registry.getCurrentVersion();
        assertEq(v4, 4);
    }

    /// @notice Test version increments by one each operation
    function test_VersionIncrementsByOneEachOperation() public {
        uint256 version = registry.getCurrentVersion();

        bytes4[] memory selectors1 = new bytes4[](1);
        selectors1[0] = MockFacet.mockFunction1.selector;

        // First add
        addFacetWithSelectors(address(mockFacet), selectors1);
        uint256 v1 = registry.getCurrentVersion();
        assertEq(v1, version + 1);

        // Second add
        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = MockFacetV2.newFunction.selector;
        addFacetWithSelectors(address(mockFacetV2), selectors2);
        uint256 v2 = registry.getCurrentVersion();
        assertEq(v2, v1 + 1);

        // Replace selectors1 from mockFacet to mockFacetV2
        bytes4[] memory selectors3 = new bytes4[](1);
        selectors3[0] = MockFacet.mockFunction1.selector;
        replaceFacetWithSelectors(address(mockFacetV2), selectors3);
        uint256 v3 = registry.getCurrentVersion();
        assertEq(v3, v2 + 1);

        // Remove different selector
        removeSelectors(selectors2);
        uint256 v4 = registry.getCurrentVersion();
        assertEq(v4, v3 + 1);
    }

    /// @notice Test version doesn't increment on view calls
    function test_VersionDoesntIncrementOnViewCalls() public {
        uint256 version = registry.getCurrentVersion();

        // Call various view functions
        registry.getFacets();
        registry.getFacetFunctionSelectors(address(mockFacet));
        registry.getFacetAddresses();
        registry.getFacetAddress(MockFacet.mockFunction1.selector);
        registry.isFacetRegistered(address(mockFacet));
        registry.isSelectorRegisteredWithFacet(address(mockFacet), MockFacet.mockFunction1.selector);
        registry.getBaseFacets();
        registry.owner();

        uint256 versionAfter = registry.getCurrentVersion();
        assertEq(versionAfter, version);
    }

    /// @notice Test version increments with multiple selectors in one operation
    function test_VersionIncrementsOncePerOperationNotPerSelector() public {
        uint256 v0 = registry.getCurrentVersion();

        // Add multiple selectors in one operation
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = MockFacet.mockFunction1.selector;
        selectors[1] = MockFacet.mockFunction2.selector;
        selectors[2] = MockFacet.mockFunction3.selector;
        selectors[3] = MockFacet.anotherMockFunction.selector;
        selectors[4] = bytes4(keccak256(abi.encodePacked("function5")));

        addFacetWithSelectors(address(mockFacet), selectors);
        uint256 v1 = registry.getCurrentVersion();

        // Should only increment by 1 despite multiple selectors
        assertEq(v1, v0 + 1);
    }

    /// @notice Test version increments on replace with multiple selectors
    function test_VersionIncrementsOnceOnMultiSelectorReplace() public {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = MockFacet.mockFunction1.selector;
        selectors[1] = MockFacet.mockFunction2.selector;
        selectors[2] = MockFacet.mockFunction3.selector;

        addFacetWithSelectors(address(mockFacet), selectors);
        uint256 v1 = registry.getCurrentVersion();

        replaceFacetWithSelectors(address(mockFacetV2), selectors);
        uint256 v2 = registry.getCurrentVersion();

        // Should only increment by 1
        assertEq(v2, v1 + 1);
    }

    /// @notice Test version increments on remove with multiple selectors
    function test_VersionIncrementsOnceOnMultiSelectorRemove() public {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = MockFacet.mockFunction1.selector;
        selectors[1] = MockFacet.mockFunction2.selector;
        selectors[2] = MockFacet.mockFunction3.selector;

        addFacetWithSelectors(address(mockFacet), selectors);
        uint256 v1 = registry.getCurrentVersion();

        removeSelectors(selectors);
        uint256 v2 = registry.getCurrentVersion();

        // Should only increment by 1
        assertEq(v2, v1 + 1);
    }

    /// @notice Test version is monotonic
    function test_VersionIsMonotonic() public {
        uint256 lastVersion = registry.getCurrentVersion();

        // Create new mock contracts for this test
        for (uint256 i = 0; i < 10; i++) {
            MockFacet newFacet = new MockFacet();
            bytes4[] memory selectors = new bytes4[](1);
            selectors[0] = bytes4(keccak256(abi.encodePacked("function", i)));

            addFacetWithSelectors(address(newFacet), selectors);

            uint256 currentVersion = registry.getCurrentVersion();
            assertGt(currentVersion, lastVersion);
            lastVersion = currentVersion;
        }
    }

    /// @notice Test version tracks changes correctly
    function test_VersionTracksChangesCorrectly() public {
        assertEq(registry.getCurrentVersion(), 0);

        // Add facet
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;
        addFacetWithSelectors(address(mockFacet), selectors);
        assertEq(registry.getCurrentVersion(), 1);

        // Add another
        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = MockFacet.mockFunction2.selector;
        addFacetWithSelectors(address(mockFacet), selectors2);
        assertEq(registry.getCurrentVersion(), 2);

        // Replace
        replaceFacetWithSelectors(address(mockFacetV2), selectors);
        assertEq(registry.getCurrentVersion(), 3);

        // Remove
        removeSelectors(selectors2);
        assertEq(registry.getCurrentVersion(), 4);
    }

    /// @notice Test version persists across transactions
    function test_VersionPersistsAcrossTransactions() public {
        assertEq(registry.getCurrentVersion(), 0);

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        addFacetWithSelectors(address(mockFacet), selectors);
        assertEq(registry.getCurrentVersion(), 1);

        // In a real scenario, this would be a new transaction
        // In test, we verify the version persists
        assertEq(registry.getCurrentVersion(), 1);

        removeSelectors(selectors);
        assertEq(registry.getCurrentVersion(), 2);
    }

    /// @notice Test large number of operations don't break versioning
    function test_LargeNumberOfOperationsVersioning() public {
        uint256 operations = 20; // Reduced from 50 to avoid excessive gas
        uint256 expectedVersion = 0;

        for (uint256 i = 0; i < operations; i++) {
            MockFacet newFacet = new MockFacet();
            bytes4[] memory selectors = new bytes4[](1);
            selectors[0] = bytes4(keccak256(abi.encodePacked("function", i)));

            addFacetWithSelectors(address(newFacet), selectors);
            expectedVersion++;

            uint256 currentVersion = registry.getCurrentVersion();
            assertEq(currentVersion, expectedVersion);
        }

        assertEq(registry.getCurrentVersion(), operations);
    }

    /// @notice Test version doesn't overflow
    function test_VersionDoesNotOverflow() public view {
        uint256 currentVersion = registry.getCurrentVersion();
        assertLt(currentVersion, type(uint256).max);

        // Version should be able to go very high without issues
        // This is more of a theoretical test since we can't run to max
    }

    /// @notice Test getCurrentVersion works from different accounts
    function test_GetCurrentVersionWorksFromDifferentAccounts() public {
        uint256 versionAsOwner = registry.getCurrentVersion();

        vm.prank(user1);
        uint256 versionAsUser1 = registry.getCurrentVersion();

        vm.prank(user2);
        uint256 versionAsUser2 = registry.getCurrentVersion();

        assertEq(versionAsOwner, versionAsUser1);
        assertEq(versionAsUser1, versionAsUser2);
    }

    /// @notice Test facet cuts history can be fetched across multiple versions
    function test_GetFacetCutsByVersionRange_ReturnsHistory() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        addFacetWithSelectors(address(mockFacet), selectors);

        bytes4[] memory replaceSelectors = new bytes4[](1);
        replaceSelectors[0] = selectors[0];

        replaceFacetWithSelectors(address(mockFacetV2), replaceSelectors);
        removeSelectors(replaceSelectors);

        uint256 latestVersion = registry.getCurrentVersion();
        assertEq(latestVersion, 3);

        IDiamondCut.FacetCut[] memory history = registry.getFacetCutsByVersionRange(1, latestVersion);

        assertEq(history.length, latestVersion);

        // Version 1 - Add
        assertEq(history[0].facetAddress, address(mockFacet));
        assertEq(uint8(history[0].action), uint8(IDiamondCut.FacetCutAction.Add));
        assertEq(history[0].functionSelectors.length, 1);
        assertEq(history[0].functionSelectors[0], selectors[0]);

        // Version 2 - Replace
        assertEq(history[1].facetAddress, address(mockFacetV2));
        assertEq(uint8(history[1].action), uint8(IDiamondCut.FacetCutAction.Replace));
        assertEq(history[1].functionSelectors.length, 1);
        assertEq(history[1].functionSelectors[0], selectors[0]);

        // Version 3 - Remove
        assertEq(history[2].facetAddress, address(0));
        assertEq(uint8(history[2].action), uint8(IDiamondCut.FacetCutAction.Remove));
        assertEq(history[2].functionSelectors.length, 1);
        assertEq(history[2].functionSelectors[0], selectors[0]);
    }

    /// @notice Test facet cuts history supports multi-selector operations
    function test_GetFacetCutsByVersionRange_MultiSelectorOperation() public {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = MockFacet.mockFunction1.selector;
        selectors[1] = MockFacet.mockFunction2.selector;

        addFacetWithSelectors(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory history = registry.getFacetCutsByVersionRange(1, 1);

        assertEq(history.length, 1);
        assertEq(history[0].facetAddress, address(mockFacet));
        assertEq(uint8(history[0].action), uint8(IDiamondCut.FacetCutAction.Add));
        assertEq(history[0].functionSelectors.length, selectors.length);
        assertEq(history[0].functionSelectors[0], selectors[0]);
        assertEq(history[0].functionSelectors[1], selectors[1]);
    }
}
