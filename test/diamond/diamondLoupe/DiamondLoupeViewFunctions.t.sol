// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { DiamondTestBase } from "../DiamondTestBase.sol";
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";
import { IDiamondLoupe } from "src/diamond/facets/baseFacets/loupe/IDiamondLoupe.sol";
import { Diamond } from "src/diamond/Diamond.sol";

/// @title DiamondLoupeFacetTest
/// @notice Tests for DiamondLoupeFacet functionality (introspection)
contract DiamondLoupeFacetTest is DiamondTestBase {
    function test_Facets_ReturnsAllFacets() public view {
        IDiamondLoupe.Facet[] memory facets = getDiamondLoupe().facets();

        // Should have 4 base facets
        assertEq(facets.length, 4);

        // Verify all facets have selectors
        for (uint256 i = 0; i < facets.length; i++) {
            assertTrue(facets[i].facetAddress != address(0));
            assertTrue(facets[i].functionSelectors.length > 0);
        }
    }

    function test_FacetFunctionSelectors_ReturnsCorrectSelectors() public view {
        bytes4[] memory cutSels = getDiamondLoupe().facetFunctionSelectors(address(cutFacet));
        assertEq(cutSels.length, cutSelectors.length);
        assertEq(cutSels[0], cutSelectors[0]);
    }

    function test_FacetFunctionSelectors_ReturnsEmptyForNonExistent() public view {
        bytes4[] memory sels = getDiamondLoupe().facetFunctionSelectors(address(0xdead));
        assertEq(sels.length, 0);
    }

    function test_FacetAddresses_ReturnsAllAddresses() public view {
        address[] memory addresses = getDiamondLoupe().facetAddresses();

        // Should have 4 base facet addresses
        assertEq(addresses.length, 4);

        // Verify all addresses are non-zero
        for (uint256 i = 0; i < addresses.length; i++) {
            assertTrue(addresses[i] != address(0));
        }
    }

    function test_FacetAddress_ReturnsCorrectFacet() public view {
        assertEq(getDiamondLoupe().facetAddress(cutSelectors[0]), address(cutFacet));
        assertEq(getDiamondLoupe().facetAddress(loupeSelectors[0]), address(loupeFacet));
        assertEq(getDiamondLoupe().facetAddress(ownershipSelectors[0]), address(ownershipFacet));
        assertEq(getDiamondLoupe().facetAddress(upgradeSelectors[0]), address(upgradeFacet));
    }

    function test_FacetAddress_ReturnsZeroForNonExistent() public view {
        bytes4 nonExistentSelector = bytes4(keccak256("nonExistent()"));
        assertEq(getDiamondLoupe().facetAddress(nonExistentSelector), address(0));
    }

    function test_ConsistencyBetweenFacetsAndFacetAddresses() public view {
        IDiamondLoupe.Facet[] memory facets = getDiamondLoupe().facets();
        address[] memory addresses = getDiamondLoupe().facetAddresses();

        assertEq(facets.length, addresses.length);

        // Verify each address in addresses array appears in facets array
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

    function test_ConsistencyBetweenFacetAddressAndFunctionSelectors() public view {
        IDiamondLoupe.Facet[] memory facets = getDiamondLoupe().facets();

        for (uint256 i = 0; i < facets.length; i++) {
            bytes4[] memory selectors = getDiamondLoupe().facetFunctionSelectors(facets[i].facetAddress);

            // Selectors from facets() should match facetFunctionSelectors()
            assertEq(selectors.length, facets[i].functionSelectors.length);

            for (uint256 j = 0; j < selectors.length; j++) {
                assertEq(selectors[j], facets[i].functionSelectors[j]);
            }
        }
    }

    function test_FacetAddress_ForAllRegisteredSelectors() public view {
        IDiamondLoupe.Facet[] memory facets = getDiamondLoupe().facets();

        for (uint256 i = 0; i < facets.length; i++) {
            for (uint256 j = 0; j < facets[i].functionSelectors.length; j++) {
                bytes4 selector = facets[i].functionSelectors[j];
                assertEq(
                    getDiamondLoupe().facetAddress(selector), facets[i].facetAddress, "Selector maps to wrong facet"
                );
            }
        }
    }

    function test_LoupeAfterAddingFacet() public {
        // Deploy mock facet
        MockLoupeFacet mockFacet = new MockLoupeFacet();
        bytes4[] memory mockSelectors = new bytes4[](1);
        mockSelectors[0] = mockFacet.mockFunction.selector;

        // Register in registry
        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), mockSelectors);

        // Add to diamond
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), mockSelectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Verify loupe reflects the change
        assertEq(getDiamondLoupe().facetAddress(mockSelectors[0]), address(mockFacet));

        address[] memory addresses = getDiamondLoupe().facetAddresses();
        assertEq(addresses.length, 5); // 4 base + 1 new
    }

    function test_LoupeAfterRemovingFacet() public {
        // First add a facet
        MockLoupeFacet mockFacet = new MockLoupeFacet();
        bytes4[] memory mockSelectors = new bytes4[](1);
        mockSelectors[0] = mockFacet.mockFunction.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), mockSelectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(mockFacet), mockSelectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Now remove it
        vm.prank(owner);
        facetRegistry.removeFunctions(address(0), mockSelectors);

        IDiamondCut.FacetCut[] memory removeCuts = new IDiamondCut.FacetCut[](1);
        removeCuts[0] = createRemoveCut(mockSelectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(removeCuts, address(0), "");

        // Verify loupe reflects the removal
        assertEq(getDiamondLoupe().facetAddress(mockSelectors[0]), address(0));
    }

    function test_ViewFunctionsWorkWithEmptyDiamond() public {
        // Create empty diamond
        IDiamondCut.FacetCut[] memory emptyCuts = new IDiamondCut.FacetCut[](0);
        Diamond emptyDiamond = new Diamond(emptyCuts, owner, address(facetRegistry), address(protocolStatus));

        // Note: We cannot call loupe functions on empty diamond because there's no loupe facet
        // This test just verifies empty diamond can be created
        assertTrue(address(emptyDiamond) != address(0));
    }
}

contract MockLoupeFacet {
    function mockFunction() external pure returns (uint256) {
        return 42;
    }
}
