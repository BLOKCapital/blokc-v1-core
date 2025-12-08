// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.20;

import { FacetRegistryTestBase } from "./FacetRegistryTestBase.sol";
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
import { MockFacet, MockFacetV2 } from "./MockFacets.sol";

/// @title Tests for FacetRegistry base facet protection
contract FacetRegistryBaseFacetProtectionTest is FacetRegistryTestBase {
    function setUp() public override {
        super.setUp();
    }

    // =============================================================
    // BASE FACET PROTECTION TESTS - ADD
    // =============================================================

    /// @notice Test cannot add functions to DiamondCutFacet
    function test_RevertAddFunctionsToDiamondCutFacet() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_CannotModifyBaseFacet(), address(diamondCutFacet)));
        registry.addFunctions(address(diamondCutFacet), selectors);
    }

    /// @notice Test cannot add functions to DiamondLoupeFacet
    function test_RevertAddFunctionsToDiamondLoupeFacet() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_CannotModifyBaseFacet(), address(diamondLoupeFacet)));
        registry.addFunctions(address(diamondLoupeFacet), selectors);
    }

    /// @notice Test cannot add functions to OwnershipFacet
    function test_RevertAddFunctionsToOwnershipFacet() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_CannotModifyBaseFacet(), address(ownershipFacet)));
        registry.addFunctions(address(ownershipFacet), selectors);
    }

    /// @notice Test cannot add functions to UpgradeFacet
    function test_RevertAddFunctionsToUpgradeFacet() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_CannotModifyBaseFacet(), address(upgradeFacet)));
        registry.addFunctions(address(upgradeFacet), selectors);
    }

    /// @notice Test cannot add functions to any base facet
    function test_RevertAddFunctionsToAnyBaseFacet() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        address[4] memory baseFacets =
            [address(diamondCutFacet), address(diamondLoupeFacet), address(ownershipFacet), address(upgradeFacet)];

        for (uint256 i = 0; i < baseFacets.length; i++) {
            vm.expectRevert(abi.encodeWithSelector(getErrorSelector_CannotModifyBaseFacet(), baseFacets[i]));
            registry.addFunctions(baseFacets[i], selectors);
        }
    }

    // =============================================================
    // BASE FACET PROTECTION TESTS - REPLACE
    // =============================================================

    /// @notice Test cannot replace functions on DiamondCutFacet
    function test_RevertReplaceFunctionsOnDiamondCutFacet() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = diamondCutSelectors[0];

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_CannotModifyBaseFacet(), address(diamondCutFacet)));
        registry.replaceFunctions(address(mockFacet), selectors);
    }

    /// @notice Test cannot replace functions on DiamondLoupeFacet
    function test_RevertReplaceFunctionsOnDiamondLoupeFacet() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = diamondLoupeSelectors[0];

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_CannotModifyBaseFacet(), address(diamondLoupeFacet)));
        registry.replaceFunctions(address(mockFacet), selectors);
    }

    /// @notice Test cannot replace functions on OwnershipFacet
    function test_RevertReplaceFunctionsOnOwnershipFacet() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = ownershipSelectors[0];

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_CannotModifyBaseFacet(), address(ownershipFacet)));
        registry.replaceFunctions(address(mockFacet), selectors);
    }

    /// @notice Test cannot replace functions on UpgradeFacet
    function test_RevertReplaceFunctionsOnUpgradeFacet() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = upgradeSelectors[0];

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_CannotModifyBaseFacet(), address(upgradeFacet)));
        registry.replaceFunctions(address(mockFacet), selectors);
    }

    /// @notice Test cannot replace base facet selector to non-base facet
    function test_RevertReplaceBaseFacetSelectorToNonBaseFacet() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = diamondCutSelectors[0];

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_CannotModifyBaseFacet(), address(diamondCutFacet)));
        registry.replaceFunctions(address(mockFacet), selectors);
    }

    /// @notice Test cannot replace functions with any base facet as target
    function test_RevertReplaceFunctionsWithAnyBaseFacet() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        address[4] memory baseFacets =
            [address(diamondCutFacet), address(diamondLoupeFacet), address(ownershipFacet), address(upgradeFacet)];

        for (uint256 i = 0; i < baseFacets.length; i++) {
            vm.expectRevert(abi.encodeWithSelector(getErrorSelector_CannotModifyBaseFacet(), baseFacets[i]));
            registry.replaceFunctions(baseFacets[i], selectors);
        }
    }

    // =============================================================
    // BASE FACET PROTECTION TESTS - REMOVE
    // =============================================================

    /// @notice Test cannot remove functions from DiamondCutFacet
    function test_RevertRemoveFunctionsFromDiamondCutFacet() public {
        bytes4[] memory baseSelectors = registry.getFacetFunctionSelectors(address(diamondCutFacet));

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_CannotModifyBaseFacet(), address(diamondCutFacet)));
        registry.removeFunctions(address(0), baseSelectors);
    }

    /// @notice Test cannot remove functions from DiamondLoupeFacet
    function test_RevertRemoveFunctionsFromDiamondLoupeFacet() public {
        bytes4[] memory baseSelectors = registry.getFacetFunctionSelectors(address(diamondLoupeFacet));

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_CannotModifyBaseFacet(), address(diamondLoupeFacet)));
        registry.removeFunctions(address(0), baseSelectors);
    }

    /// @notice Test cannot remove functions from OwnershipFacet
    function test_RevertRemoveFunctionsFromOwnershipFacet() public {
        bytes4[] memory baseSelectors = registry.getFacetFunctionSelectors(address(ownershipFacet));

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_CannotModifyBaseFacet(), address(ownershipFacet)));
        registry.removeFunctions(address(0), baseSelectors);
    }

    /// @notice Test cannot remove functions from UpgradeFacet
    function test_RevertRemoveFunctionsFromUpgradeFacet() public {
        bytes4[] memory baseSelectors = registry.getFacetFunctionSelectors(address(upgradeFacet));

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_CannotModifyBaseFacet(), address(upgradeFacet)));
        registry.removeFunctions(address(0), baseSelectors);
    }

    /// @notice Test cannot remove functions from any base facet
    function test_RevertRemoveFunctionsFromAnyBaseFacet() public {
        address[4] memory baseFacets =
            [address(diamondCutFacet), address(diamondLoupeFacet), address(ownershipFacet), address(upgradeFacet)];

        for (uint256 i = 0; i < baseFacets.length; i++) {
            bytes4[] memory baseSelectors = registry.getFacetFunctionSelectors(baseFacets[i]);
            vm.expectRevert(abi.encodeWithSelector(getErrorSelector_CannotModifyBaseFacet(), baseFacets[i]));
            registry.removeFunctions(address(0), baseSelectors);
        }
    }

    /// @notice Test cannot remove partial functions from any base facet
    function test_RevertRemovePartialFunctionsFromBaseFacet() public {
        bytes4[] memory partialSelectors = new bytes4[](1);
        partialSelectors[0] = diamondCutSelectors[0];

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_CannotModifyBaseFacet(), address(diamondCutFacet)));
        registry.removeFunctions(address(0), partialSelectors);
    }

    // =============================================================
    // BASE FACET PROTECTION TESTS - IMMUTABILITY
    // =============================================================

    /// @notice Test base facets remain unchanged after operations
    function test_BaseFacetsRemainUnchangedAfterOperations() public {
        // Add some facets
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = MockFacet.mockFunction1.selector;

        addFacetWithSelectors(address(mockFacet), selectors);

        // Replace some facets
        bytes4[] memory replaceSelectors = new bytes4[](1);
        replaceSelectors[0] = selectors[0];

        replaceFacetWithSelectors(address(mockFacetV2), replaceSelectors);

        // Remove some facets
        removeSelectors(replaceSelectors);

        // Verify base facets unchanged
        address[4] memory baseFacets = registry.getBaseFacets();
        assertEq(baseFacets[0], address(diamondCutFacet));
        assertEq(baseFacets[1], address(diamondLoupeFacet));
        assertEq(baseFacets[2], address(ownershipFacet));
        assertEq(baseFacets[3], address(upgradeFacet));

        // Verify base facet selectors unchanged
        bytes4[] memory cutSelectors = registry.getFacetFunctionSelectors(address(diamondCutFacet));
        assertEq(cutSelectors.length, 1);

        bytes4[] memory loupeSelectors = registry.getFacetFunctionSelectors(address(diamondLoupeFacet));
        assertEq(loupeSelectors.length, 5);

        bytes4[] memory ownSelectors = registry.getFacetFunctionSelectors(address(ownershipFacet));
        assertEq(ownSelectors.length, 2);

        bytes4[] memory upgSelectors = registry.getFacetFunctionSelectors(address(upgradeFacet));
        assertEq(upgSelectors.length, 3);
    }

    /// @notice Test base facets are always present
    function test_BaseFacetsAlwaysPresent() public view {
        address[4] memory baseFacets = registry.getBaseFacets();

        for (uint256 i = 0; i < baseFacets.length; i++) {
            assertNotEq(baseFacets[i], address(0));
        }
    }

    /// @notice Test base facets cannot be unregistered
    function test_BaseFacetsCannotBeUnregistered() public view {
        assertTrue(registry.isFacetRegistered(address(diamondCutFacet)));
        assertTrue(registry.isFacetRegistered(address(diamondLoupeFacet)));
        assertTrue(registry.isFacetRegistered(address(ownershipFacet)));
        assertTrue(registry.isFacetRegistered(address(upgradeFacet)));
    }

    /// @notice Test base facet selectors cannot be modified
    function test_BaseFacetSelectorsCannotBeModified() public {
        bytes4[] memory allCutSelectors = registry.getFacetFunctionSelectors(address(diamondCutFacet));
        bytes4[] memory allLoupeSelectors = registry.getFacetFunctionSelectors(address(diamondLoupeFacet));
        bytes4[] memory allOwnSelectors = registry.getFacetFunctionSelectors(address(ownershipFacet));
        bytes4[] memory allUpgSelectors = registry.getFacetFunctionSelectors(address(upgradeFacet));

        // Verify all selectors are still registered to base facets
        for (uint256 i = 0; i < allCutSelectors.length; i++) {
            assertEq(registry.getFacetAddress(allCutSelectors[i]), address(diamondCutFacet));
        }

        for (uint256 i = 0; i < allLoupeSelectors.length; i++) {
            assertEq(registry.getFacetAddress(allLoupeSelectors[i]), address(diamondLoupeFacet));
        }

        for (uint256 i = 0; i < allOwnSelectors.length; i++) {
            assertEq(registry.getFacetAddress(allOwnSelectors[i]), address(ownershipFacet));
        }

        for (uint256 i = 0; i < allUpgSelectors.length; i++) {
            assertEq(registry.getFacetAddress(allUpgSelectors[i]), address(upgradeFacet));
        }
    }

    /// @notice Test getBaseFacets always returns the same base facets
    function test_GetBaseFacetsAlwaysReturnsSame() public view {
        address[4] memory baseFacets1 = registry.getBaseFacets();
        address[4] memory baseFacets2 = registry.getBaseFacets();

        for (uint256 i = 0; i < 4; i++) {
            assertEq(baseFacets1[i], baseFacets2[i]);
        }
    }
}
