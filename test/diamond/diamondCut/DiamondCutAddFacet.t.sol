// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { DiamondTestBase } from "../DiamondTestBase.sol";
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";
import { IDiamondLoupe } from "src/diamond/facets/baseFacets/loupe/IDiamondLoupe.sol";

/// @title DiamondCutAddFacetTest
/// @notice Comprehensive tests for adding facets via diamondCut
contract DiamondCutAddFacetTest is DiamondTestBase {
    function test_AddSingleFacet() public {
        MockAddFacet mockFacet = new MockAddFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(mockFacet));
    }

    function test_AddFacetWithMultipleSelectors() public {
        MockAddFacet mockFacet = new MockAddFacet();
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = mockFacet.function1.selector;
        selectors[1] = mockFacet.function2.selector;
        selectors[2] = mockFacet.function3.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        for (uint256 i = 0; i < selectors.length; i++) {
            assertEq(getDiamondLoupe().facetAddress(selectors[i]), address(mockFacet));
        }
    }

    function test_AddMultipleFacetsInSingleCut() public {
        MockAddFacet facet1 = new MockAddFacet();
        MockAddFacet facet2 = new MockAddFacet();

        bytes4[] memory selectors1 = new bytes4[](1);
        selectors1[0] = facet1.function1.selector;

        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = bytes4(keccak256("differentFunction()"));

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors1);

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet2), selectors2);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](2);
        cuts[0] = createAddCut(address(facet1), selectors1);
        cuts[1] = createAddCut(address(facet2), selectors2);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        assertEq(getDiamondLoupe().facetAddress(selectors1[0]), address(facet1));
        assertEq(getDiamondLoupe().facetAddress(selectors2[0]), address(facet2));
    }

    function test_AddFacetUpdatesFacetAddresses() public {
        MockAddFacet mockFacet = new MockAddFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        uint256 initialCount = getDiamondLoupe().facetAddresses().length;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        assertEq(getDiamondLoupe().facetAddresses().length, initialCount + 1);
    }

    function test_AddFacetUpdatesFacetsArray() public {
        MockAddFacet mockFacet = new MockAddFacet();
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = mockFacet.function1.selector;
        selectors[1] = mockFacet.function2.selector;

        uint256 initialCount = getDiamondLoupe().facets().length;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        IDiamondLoupe.Facet[] memory facets = getDiamondLoupe().facets();
        assertEq(facets.length, initialCount + 1);
    }

    function test_AddFacetSucceeds() public {
        MockAddFacet mockFacet = new MockAddFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Verify facet was added
        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(mockFacet));
    }

    function test_RevertIf_AddFacetNotRegistered() public {
        MockAddFacet unregisteredFacet = new MockAddFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = unregisteredFacet.function1.selector;

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(unregisteredFacet), selectors);

        vm.prank(owner);
        vm.expectRevert();
        getDiamondCut().diamondCut(cuts, address(0), "");
    }

    function test_RevertIf_AddDuplicateSelector() public {
        MockAddFacet mockFacet = new MockAddFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Try to add again
        vm.prank(owner);
        vm.expectRevert();
        getDiamondCut().diamondCut(cuts, address(0), "");
    }

    function test_RevertIf_NonOwnerAddsFacet() public {
        MockAddFacet mockFacet = new MockAddFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(nonOwner);
        vm.expectRevert();
        getDiamondCut().diamondCut(cuts, address(0), "");
    }

    function test_RevertIf_AddFacetWithEmptySelectorsArray() public {
        MockAddFacet mockFacet = new MockAddFacet();
        bytes4[] memory selectors = new bytes4[](0);

        // Registry will reject empty selectors
        vm.prank(owner);
        vm.expectRevert();
        facetRegistry.addFunctions(address(mockFacet), selectors);
    }

    function test_AddFacetToExistingFacetAddress() public {
        MockAddFacet mockFacet = new MockAddFacet();

        // Add first selector
        bytes4[] memory selectors1 = new bytes4[](1);
        selectors1[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors1);

        IDiamondCut.FacetCut[] memory cuts1 = new IDiamondCut.FacetCut[](1);
        cuts1[0] = createAddCut(address(mockFacet), selectors1);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts1, address(0), "");

        // Add second selector to same facet
        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = mockFacet.function2.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors2);

        IDiamondCut.FacetCut[] memory cuts2 = new IDiamondCut.FacetCut[](1);
        cuts2[0] = createAddCut(address(mockFacet), selectors2);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts2, address(0), "");

        // Verify both selectors point to same facet
        assertEq(getDiamondLoupe().facetAddress(selectors1[0]), address(mockFacet));
        assertEq(getDiamondLoupe().facetAddress(selectors2[0]), address(mockFacet));

        // Verify facet has both selectors
        bytes4[] memory facetSelectors = getDiamondLoupe().facetFunctionSelectors(address(mockFacet));
        assertEq(facetSelectors.length, 2);
    }

    function testFuzz_AddFacetWithRandomSelectors(bytes4 selector1, bytes4 selector2) public {
        vm.assume(selector1 != selector2);
        vm.assume(selector1 != bytes4(0));
        vm.assume(selector2 != bytes4(0));

        // Check selectors aren't already registered
        vm.assume(getDiamondLoupe().facetAddress(selector1) == address(0));
        vm.assume(getDiamondLoupe().facetAddress(selector2) == address(0));

        MockAddFacet mockFacet = new MockAddFacet();
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = selector1;
        selectors[1] = selector2;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        assertEq(getDiamondLoupe().facetAddress(selector1), address(mockFacet));
        assertEq(getDiamondLoupe().facetAddress(selector2), address(mockFacet));
    }

    function test_AddManyFacetsSequentially() public {
        uint256 count = 10;

        for (uint256 i = 0; i < count; i++) {
            MockAddFacet mockFacet = new MockAddFacet();
            bytes4[] memory selectors = new bytes4[](1);
            selectors[0] = bytes4(keccak256(abi.encodePacked("function", i)));

            vm.prank(owner);
            facetRegistry.addFunctions(address(mockFacet), selectors);

            IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
            cuts[0] = createAddCut(address(mockFacet), selectors);

            vm.prank(owner);
            getDiamondCut().diamondCut(cuts, address(0), "");
        }

        address[] memory addresses = getDiamondLoupe().facetAddresses();
        assertEq(addresses.length, 4 + count); // 4 base + count new
    }

    function test_AddFacetPreservesExistingFacets() public {
        // Get initial facets
        IDiamondLoupe.Facet[] memory initialFacets = getDiamondLoupe().facets();
        uint256 initialCount = initialFacets.length;

        // Add new facet
        MockAddFacet mockFacet = new MockAddFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Verify all initial facets still exist
        IDiamondLoupe.Facet[] memory newFacets = getDiamondLoupe().facets();
        assertEq(newFacets.length, initialCount + 1);

        for (uint256 i = 0; i < initialFacets.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < newFacets.length; j++) {
                if (initialFacets[i].facetAddress == newFacets[j].facetAddress) {
                    found = true;
                    break;
                }
            }
            assertTrue(found, "Initial facet missing");
        }
    }
}

contract MockAddFacet {
    function function1() external pure returns (uint256) {
        return 1;
    }

    function function2() external pure returns (uint256) {
        return 2;
    }

    function function3() external pure returns (uint256) {
        return 3;
    }
}
