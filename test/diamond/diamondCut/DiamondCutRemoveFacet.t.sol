// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { DiamondTestBase } from "../DiamondTestBase.sol";
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";
import { IDiamondLoupe } from "src/diamond/facets/baseFacets/loupe/IDiamondLoupe.sol";

/// @title DiamondCutRemoveFacetTest
/// @notice Comprehensive tests for removing facets via diamondCut
contract DiamondCutRemoveFacetTest is DiamondTestBase {
    function test_RemoveSingleFacet() public {
        // Add facet first
        MockRemoveFacet mockFacet = new MockRemoveFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Verify facet is added
        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(mockFacet));

        // Remove from registry first
        vm.prank(owner);
        facetRegistry.removeFunctions(address(0), selectors);

        // Remove from diamond
        IDiamondCut.FacetCut[] memory removeCuts = new IDiamondCut.FacetCut[](1);
        removeCuts[0] = createRemoveCut(selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(removeCuts, address(0), "");

        // Verify facet is removed
        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(0));
    }

    function test_RemoveFacetWithMultipleSelectors() public {
        MockRemoveFacet mockFacet = new MockRemoveFacet();
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = mockFacet.function1.selector;
        selectors[1] = mockFacet.function2.selector;
        selectors[2] = mockFacet.function3.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Remove all selectors
        vm.prank(owner);
        facetRegistry.removeFunctions(address(0), selectors);

        IDiamondCut.FacetCut[] memory removeCuts = new IDiamondCut.FacetCut[](1);
        removeCuts[0] = createRemoveCut(selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(removeCuts, address(0), "");

        // Verify all selectors are removed
        for (uint256 i = 0; i < selectors.length; i++) {
            assertEq(getDiamondLoupe().facetAddress(selectors[i]), address(0));
        }
    }

    function test_RemovePartialSelectors() public {
        MockRemoveFacet mockFacet = new MockRemoveFacet();
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = mockFacet.function1.selector;
        selectors[1] = mockFacet.function2.selector;
        selectors[2] = mockFacet.function3.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Remove only first two selectors
        bytes4[] memory removeSelectors = new bytes4[](2);
        removeSelectors[0] = selectors[0];
        removeSelectors[1] = selectors[1];

        vm.prank(owner);
        facetRegistry.removeFunctions(address(0), removeSelectors);

        IDiamondCut.FacetCut[] memory removeCuts = new IDiamondCut.FacetCut[](1);
        removeCuts[0] = createRemoveCut(removeSelectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(removeCuts, address(0), "");

        // First two should be removed, third should remain
        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(0));
        assertEq(getDiamondLoupe().facetAddress(selectors[1]), address(0));
        assertEq(getDiamondLoupe().facetAddress(selectors[2]), address(mockFacet));
    }

    function test_RemoveFacetFromMultipleFacets() public {
        MockRemoveFacet facet1 = new MockRemoveFacet();
        MockRemoveFacet facet2 = new MockRemoveFacet();

        bytes4[] memory selectors1 = new bytes4[](1);
        selectors1[0] = facet1.function1.selector;

        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = bytes4(keccak256("differentFunction()"));

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors1);

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet2), selectors2);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](2);
        addCuts[0] = createAddCut(address(facet1), selectors1);
        addCuts[1] = createAddCut(address(facet2), selectors2);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Remove both
        vm.prank(owner);
        facetRegistry.removeFunctions(address(0), selectors1);

        vm.prank(owner);
        facetRegistry.removeFunctions(address(0), selectors2);

        IDiamondCut.FacetCut[] memory removeCuts = new IDiamondCut.FacetCut[](2);
        removeCuts[0] = createRemoveCut(selectors1);
        removeCuts[1] = createRemoveCut(selectors2);

        vm.prank(owner);
        getDiamondCut().diamondCut(removeCuts, address(0), "");

        assertEq(getDiamondLoupe().facetAddress(selectors1[0]), address(0));
        assertEq(getDiamondLoupe().facetAddress(selectors2[0]), address(0));
    }

    function test_RemoveFacetUpdatesFacetAddresses() public {
        MockRemoveFacet mockFacet = new MockRemoveFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        uint256 facetCountBefore = getDiamondLoupe().facetAddresses().length;

        // Remove
        vm.prank(owner);
        facetRegistry.removeFunctions(address(0), selectors);

        IDiamondCut.FacetCut[] memory removeCuts = new IDiamondCut.FacetCut[](1);
        removeCuts[0] = createRemoveCut(selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(removeCuts, address(0), "");

        uint256 facetCountAfter = getDiamondLoupe().facetAddresses().length;
        assertEq(facetCountAfter, facetCountBefore - 1);
    }

    function test_RemoveFacetRemovesFromFacetsArray() public {
        MockRemoveFacet mockFacet = new MockRemoveFacet();
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = mockFacet.function1.selector;
        selectors[1] = mockFacet.function2.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        uint256 facetsCountBefore = getDiamondLoupe().facets().length;

        // Remove all selectors (which removes the facet)
        vm.prank(owner);
        facetRegistry.removeFunctions(address(0), selectors);

        IDiamondCut.FacetCut[] memory removeCuts = new IDiamondCut.FacetCut[](1);
        removeCuts[0] = createRemoveCut(selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(removeCuts, address(0), "");

        uint256 facetsCountAfter = getDiamondLoupe().facets().length;
        assertEq(facetsCountAfter, facetsCountBefore - 1);
    }

    function test_RemoveFacetDoesntAffectOtherFacets() public {
        MockRemoveFacet facet1 = new MockRemoveFacet();
        MockRemoveFacet facet2 = new MockRemoveFacet();

        bytes4[] memory selectors1 = new bytes4[](1);
        selectors1[0] = facet1.function1.selector;

        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = bytes4(keccak256("differentFunction()"));

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors1);

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet2), selectors2);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](2);
        addCuts[0] = createAddCut(address(facet1), selectors1);
        addCuts[1] = createAddCut(address(facet2), selectors2);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Remove only facet1
        vm.prank(owner);
        facetRegistry.removeFunctions(address(0), selectors1);

        IDiamondCut.FacetCut[] memory removeCuts = new IDiamondCut.FacetCut[](1);
        removeCuts[0] = createRemoveCut(selectors1);

        vm.prank(owner);
        getDiamondCut().diamondCut(removeCuts, address(0), "");

        // facet1 should be removed
        assertEq(getDiamondLoupe().facetAddress(selectors1[0]), address(0));

        // facet2 should still exist
        assertEq(getDiamondLoupe().facetAddress(selectors2[0]), address(facet2));
    }

    function test_RevertIf_RemoveNonExistentSelector() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(keccak256("nonExistent()"));

        IDiamondCut.FacetCut[] memory removeCuts = new IDiamondCut.FacetCut[](1);
        removeCuts[0] = createRemoveCut(selectors);

        vm.prank(owner);
        vm.expectRevert();
        getDiamondCut().diamondCut(removeCuts, address(0), "");
    }

    function test_RevertIf_RemoveSelectorStillInRegistry() public {
        MockRemoveFacet mockFacet = new MockRemoveFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Try to remove without removing from registry first
        IDiamondCut.FacetCut[] memory removeCuts = new IDiamondCut.FacetCut[](1);
        removeCuts[0] = createRemoveCut(selectors);

        vm.prank(owner);
        vm.expectRevert();
        getDiamondCut().diamondCut(removeCuts, address(0), "");
    }

    function test_RevertIf_NonOwnerRemovesFacet() public {
        MockRemoveFacet mockFacet = new MockRemoveFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        vm.prank(owner);
        facetRegistry.removeFunctions(address(0), selectors);

        IDiamondCut.FacetCut[] memory removeCuts = new IDiamondCut.FacetCut[](1);
        removeCuts[0] = createRemoveCut(selectors);

        vm.prank(nonOwner);
        vm.expectRevert();
        getDiamondCut().diamondCut(removeCuts, address(0), "");
    }

    function test_RemoveAndReaddFacet() public {
        MockRemoveFacet mockFacet = new MockRemoveFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        // Add
        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Remove
        vm.prank(owner);
        facetRegistry.removeFunctions(address(0), selectors);

        IDiamondCut.FacetCut[] memory removeCuts = new IDiamondCut.FacetCut[](1);
        removeCuts[0] = createRemoveCut(selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(removeCuts, address(0), "");

        // Readd
        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory readdCuts = new IDiamondCut.FacetCut[](1);
        readdCuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(readdCuts, address(0), "");

        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(mockFacet));
    }

    function test_RemoveAllSelectorsFromFacet() public {
        MockRemoveFacet mockFacet = new MockRemoveFacet();
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = mockFacet.function1.selector;
        selectors[1] = mockFacet.function2.selector;
        selectors[2] = mockFacet.function3.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Verify facet exists
        bytes4[] memory facetSelectors = getDiamondLoupe().facetFunctionSelectors(address(mockFacet));
        assertEq(facetSelectors.length, 3);

        // Remove all selectors
        vm.prank(owner);
        facetRegistry.removeFunctions(address(0), selectors);

        IDiamondCut.FacetCut[] memory removeCuts = new IDiamondCut.FacetCut[](1);
        removeCuts[0] = createRemoveCut(selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(removeCuts, address(0), "");

        // Facet should no longer have selectors
        bytes4[] memory remainingSelectors = getDiamondLoupe().facetFunctionSelectors(address(mockFacet));
        assertEq(remainingSelectors.length, 0);

        // Facet should be removed from addresses
        address[] memory addresses = getDiamondLoupe().facetAddresses();
        bool found = false;
        for (uint256 i = 0; i < addresses.length; i++) {
            if (addresses[i] == address(mockFacet)) {
                found = true;
                break;
            }
        }
        assertFalse(found, "Facet should be removed from addresses");
    }

    function test_RemoveFacetPreservesBaseFacets() public {
        // Get base facets
        IDiamondLoupe.Facet[] memory baseFacets = getDiamondLoupe().facets();
        uint256 baseFacetCount = baseFacets.length;

        // Add a facet
        MockRemoveFacet mockFacet = new MockRemoveFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Remove the added facet
        vm.prank(owner);
        facetRegistry.removeFunctions(address(0), selectors);

        IDiamondCut.FacetCut[] memory removeCuts = new IDiamondCut.FacetCut[](1);
        removeCuts[0] = createRemoveCut(selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(removeCuts, address(0), "");

        // Base facets should still be present
        IDiamondLoupe.Facet[] memory facetsAfter = getDiamondLoupe().facets();
        assertEq(facetsAfter.length, baseFacetCount);
    }

    function test_RemoveMultipleFacetsSequentially() public {
        uint256 count = 5;
        bytes4[][] memory allSelectors = new bytes4[][](count);
        MockRemoveFacet[] memory facets = new MockRemoveFacet[](count);

        // Add multiple facets
        for (uint256 i = 0; i < count; i++) {
            facets[i] = new MockRemoveFacet();
            bytes4[] memory selectors = new bytes4[](1);
            selectors[0] = bytes4(keccak256(abi.encodePacked("function", i)));
            allSelectors[i] = selectors;

            vm.prank(owner);
            facetRegistry.addFunctions(address(facets[i]), selectors);
        }

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](count);
        for (uint256 i = 0; i < count; i++) {
            addCuts[i] = createAddCut(address(facets[i]), allSelectors[i]);
        }

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Remove them one by one
        for (uint256 i = 0; i < count; i++) {
            vm.prank(owner);
            facetRegistry.removeFunctions(address(0), allSelectors[i]);

            IDiamondCut.FacetCut[] memory removeCuts = new IDiamondCut.FacetCut[](1);
            removeCuts[0] = createRemoveCut(allSelectors[i]);

            vm.prank(owner);
            getDiamondCut().diamondCut(removeCuts, address(0), "");

            assertEq(getDiamondLoupe().facetAddress(allSelectors[i][0]), address(0));
        }

        // Should be back to base facets
        address[] memory addresses = getDiamondLoupe().facetAddresses();
        assertEq(addresses.length, 4); // 4 base facets
    }

    function testFuzz_RemoveFacet(bytes4 selector) public {
        vm.assume(selector != bytes4(0));
        vm.assume(getDiamondLoupe().facetAddress(selector) == address(0));

        MockRemoveFacet mockFacet = new MockRemoveFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Remove
        vm.prank(owner);
        facetRegistry.removeFunctions(address(0), selectors);

        IDiamondCut.FacetCut[] memory removeCuts = new IDiamondCut.FacetCut[](1);
        removeCuts[0] = createRemoveCut(selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(removeCuts, address(0), "");

        assertEq(getDiamondLoupe().facetAddress(selector), address(0));
    }
}

contract MockRemoveFacet {
    function function1() external pure returns (uint256) {
        return 10;
    }

    function function2() external pure returns (uint256) {
        return 20;
    }

    function function3() external pure returns (uint256) {
        return 30;
    }
}
