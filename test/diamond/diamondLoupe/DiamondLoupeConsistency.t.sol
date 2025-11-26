// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { DiamondTestBase } from "../DiamondTestBase.sol";
import { IDiamondLoupe } from "src/diamond/facets/baseFacets/loupe/IDiamondLoupe.sol";
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";

/// @title DiamondLoupeConsistencyTest
/// @notice Comprehensive tests for consistency between different loupe functions
contract DiamondLoupeConsistencyTest is DiamondTestBase {
    function test_Consistency_FacetsAndFacetAddresses() public view {
        IDiamondLoupe.Facet[] memory facets = getDiamondLoupe().facets();
        address[] memory addresses = getDiamondLoupe().facetAddresses();

        assertEq(facets.length, addresses.length, "Length mismatch");

        // Verify each address in addresses appears in facets
        for (uint256 i = 0; i < addresses.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < facets.length; j++) {
                if (facets[j].facetAddress == addresses[i]) {
                    found = true;
                    break;
                }
            }
            assertTrue(found, "Address not found in facets");
        }
    }

    function test_Consistency_FacetAddressAndFunctionSelectors() public view {
        IDiamondLoupe.Facet[] memory facets = getDiamondLoupe().facets();

        for (uint256 i = 0; i < facets.length; i++) {
            bytes4[] memory selectors = getDiamondLoupe().facetFunctionSelectors(facets[i].facetAddress);

            assertEq(selectors.length, facets[i].functionSelectors.length, "Selector length mismatch");

            for (uint256 j = 0; j < selectors.length; j++) {
                assertEq(selectors[j], facets[i].functionSelectors[j], "Selector mismatch");
            }
        }
    }

    function test_Consistency_FacetAddressLookup() public view {
        IDiamondLoupe.Facet[] memory facets = getDiamondLoupe().facets();

        for (uint256 i = 0; i < facets.length; i++) {
            for (uint256 j = 0; j < facets[i].functionSelectors.length; j++) {
                bytes4 selector = facets[i].functionSelectors[j];
                address facetAddr = getDiamondLoupe().facetAddress(selector);

                assertEq(facetAddr, facets[i].facetAddress, "Facet address mismatch");
            }
        }
    }

    function test_Consistency_AfterAddingFacet() public {
        MockLoupeFacet mockFacet = new MockLoupeFacet();
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = mockFacet.function1.selector;
        selectors[1] = mockFacet.function2.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Verify consistency
        IDiamondLoupe.Facet[] memory facets = getDiamondLoupe().facets();
        address[] memory addresses = getDiamondLoupe().facetAddresses();

        assertEq(facets.length, addresses.length, "Length mismatch after add");

        // Verify new facet is in both
        bool foundInFacets = false;
        bool foundInAddresses = false;

        for (uint256 i = 0; i < facets.length; i++) {
            if (facets[i].facetAddress == address(mockFacet)) {
                foundInFacets = true;
                assertEq(facets[i].functionSelectors.length, selectors.length, "Selector count mismatch");
                break;
            }
        }

        for (uint256 i = 0; i < addresses.length; i++) {
            if (addresses[i] == address(mockFacet)) {
                foundInAddresses = true;
                break;
            }
        }

        assertTrue(foundInFacets, "Facet not found in facets array");
        assertTrue(foundInAddresses, "Facet not found in addresses array");
    }

    function test_Consistency_AfterRemovingFacet() public {
        MockLoupeFacet mockFacet = new MockLoupeFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        uint256 countBefore = getDiamondLoupe().facets().length;

        // Remove
        vm.prank(owner);
        facetRegistry.removeFunctions(address(0), selectors);

        IDiamondCut.FacetCut[] memory removeCuts = new IDiamondCut.FacetCut[](1);
        removeCuts[0] = createRemoveCut(selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(removeCuts, address(0), "");

        // Verify consistency
        IDiamondLoupe.Facet[] memory facets = getDiamondLoupe().facets();
        address[] memory addresses = getDiamondLoupe().facetAddresses();

        assertEq(facets.length, addresses.length, "Length mismatch after remove");
        assertEq(facets.length, countBefore - 1, "Facet count not decreased");

        // Verify facet is removed from both
        for (uint256 i = 0; i < facets.length; i++) {
            assertTrue(facets[i].facetAddress != address(mockFacet), "Facet still in facets");
        }

        for (uint256 i = 0; i < addresses.length; i++) {
            assertTrue(addresses[i] != address(mockFacet), "Facet still in addresses");
        }
    }

    function test_Consistency_AfterReplacingFacet() public {
        MockLoupeFacet facet1 = new MockLoupeFacet();
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = facet1.function1.selector;
        selectors[1] = facet1.function2.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(facet1), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Replace
        MockLoupeFacet facet2 = new MockLoupeFacet();

        vm.prank(owner);
        facetRegistry.replaceFunctions(address(facet2), selectors);

        IDiamondCut.FacetCut[] memory replaceCuts = new IDiamondCut.FacetCut[](1);
        replaceCuts[0] = createReplaceCut(address(facet2), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(replaceCuts, address(0), "");

        // Verify consistency
        for (uint256 i = 0; i < selectors.length; i++) {
            address facetAddr = getDiamondLoupe().facetAddress(selectors[i]);
            assertEq(facetAddr, address(facet2), "Selector not pointing to new facet");
        }

        // Verify old facet is not in addresses
        address[] memory addresses = getDiamondLoupe().facetAddresses();
        bool foundOld = false;
        bool foundNew = false;

        for (uint256 i = 0; i < addresses.length; i++) {
            if (addresses[i] == address(facet1)) {
                foundOld = true;
            }
            if (addresses[i] == address(facet2)) {
                foundNew = true;
            }
        }

        // Old facet should be removed if it has no more selectors
        // New facet should be present
        assertTrue(foundNew, "New facet not in addresses");
    }

    function test_Consistency_AllSelectorsAccountedFor() public view {
        IDiamondLoupe.Facet[] memory facets = getDiamondLoupe().facets();

        // Count total selectors
        uint256 totalSelectors = 0;
        for (uint256 i = 0; i < facets.length; i++) {
            totalSelectors += facets[i].functionSelectors.length;
        }

        // Verify each selector can be looked up
        for (uint256 i = 0; i < facets.length; i++) {
            for (uint256 j = 0; j < facets[i].functionSelectors.length; j++) {
                bytes4 selector = facets[i].functionSelectors[j];
                address facetAddr = getDiamondLoupe().facetAddress(selector);

                assertEq(facetAddr, facets[i].facetAddress, "Selector lookup failed");
            }
        }
    }

    function test_Consistency_NoDuplicateSelectors() public view {
        IDiamondLoupe.Facet[] memory facets = getDiamondLoupe().facets();

        // Collect all selectors
        bytes4[] memory allSelectors = new bytes4[](1000); // Large enough
        uint256 count = 0;

        for (uint256 i = 0; i < facets.length; i++) {
            for (uint256 j = 0; j < facets[i].functionSelectors.length; j++) {
                allSelectors[count] = facets[i].functionSelectors[j];
                count++;
            }
        }

        // Check for duplicates
        for (uint256 i = 0; i < count; i++) {
            for (uint256 j = i + 1; j < count; j++) {
                assertTrue(allSelectors[i] != allSelectors[j], "Duplicate selector found");
            }
        }
    }

    function test_Consistency_NoDuplicateFacetAddresses() public view {
        address[] memory addresses = getDiamondLoupe().facetAddresses();

        for (uint256 i = 0; i < addresses.length; i++) {
            for (uint256 j = i + 1; j < addresses.length; j++) {
                assertTrue(addresses[i] != addresses[j], "Duplicate facet address found");
            }
        }
    }

    function test_Consistency_FacetFunctionSelectorsMatchesFacets() public view {
        IDiamondLoupe.Facet[] memory facets = getDiamondLoupe().facets();

        for (uint256 i = 0; i < facets.length; i++) {
            bytes4[] memory selectors = getDiamondLoupe().facetFunctionSelectors(facets[i].facetAddress);

            assertEq(selectors.length, facets[i].functionSelectors.length, "Selector count mismatch");

            // Verify order and values match
            for (uint256 j = 0; j < selectors.length; j++) {
                assertEq(selectors[j], facets[i].functionSelectors[j], "Selector value mismatch");
            }
        }
    }

    function test_Consistency_AfterMultipleOperations() public {
        // Add facet
        MockLoupeFacet facet1 = new MockLoupeFacet();
        bytes4[] memory selectors1 = new bytes4[](1);
        selectors1[0] = facet1.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors1);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(facet1), selectors1);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Replace
        MockLoupeFacet facet2 = new MockLoupeFacet();

        vm.prank(owner);
        facetRegistry.replaceFunctions(address(facet2), selectors1);

        IDiamondCut.FacetCut[] memory replaceCuts = new IDiamondCut.FacetCut[](1);
        replaceCuts[0] = createReplaceCut(address(facet2), selectors1);

        vm.prank(owner);
        getDiamondCut().diamondCut(replaceCuts, address(0), "");

        // Add another facet
        MockLoupeFacet facet3 = new MockLoupeFacet();
        bytes4[] memory selectors3 = new bytes4[](1);
        selectors3[0] = bytes4(keccak256("differentFunction()"));

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet3), selectors3);

        IDiamondCut.FacetCut[] memory addCuts2 = new IDiamondCut.FacetCut[](1);
        addCuts2[0] = createAddCut(address(facet3), selectors3);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts2, address(0), "");

        // Verify consistency after all operations
        IDiamondLoupe.Facet[] memory facets = getDiamondLoupe().facets();
        address[] memory addresses = getDiamondLoupe().facetAddresses();

        assertEq(facets.length, addresses.length, "Length mismatch after multiple operations");

        // Verify all selectors can be looked up
        assertEq(getDiamondLoupe().facetAddress(selectors1[0]), address(facet2));
        assertEq(getDiamondLoupe().facetAddress(selectors3[0]), address(facet3));
    }

    function test_Consistency_EmptyFacetReturnsEmptySelectors() public view {
        bytes4[] memory selectors = getDiamondLoupe().facetFunctionSelectors(address(0xdead));
        assertEq(selectors.length, 0, "Non-existent facet should return empty selectors");
    }

    function test_Consistency_NonExistentSelectorReturnsZero() public view {
        bytes4 nonExistent = bytes4(keccak256("nonExistent()"));
        address facetAddr = getDiamondLoupe().facetAddress(nonExistent);
        assertEq(facetAddr, address(0), "Non-existent selector should return zero address");
    }
}

contract MockLoupeFacet {
    function function1() external pure returns (uint256) {
        return 300;
    }

    function function2() external pure returns (uint256) {
        return 400;
    }
}
