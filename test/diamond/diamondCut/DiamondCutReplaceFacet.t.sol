// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { DiamondTestBase } from "../DiamondTestBase.sol";
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";
import { IDiamondLoupe } from "src/diamond/facets/baseFacets/loupe/IDiamondLoupe.sol";

/// @title DiamondCutReplaceFacetTest
/// @notice Comprehensive tests for replacing facets via diamondCut
contract DiamondCutReplaceFacetTest is DiamondTestBase {
    function test_ReplaceFacet() public {
        // Add initial facet
        MockReplaceFacet facet1 = new MockReplaceFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = facet1.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(facet1), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Replace with new facet
        MockReplaceFacetV2 facet2 = new MockReplaceFacetV2();

        vm.prank(owner);
        facetRegistry.replaceFunctions(address(facet2), selectors);

        IDiamondCut.FacetCut[] memory replaceCuts = new IDiamondCut.FacetCut[](1);
        replaceCuts[0] = createReplaceCut(address(facet2), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(replaceCuts, address(0), "");

        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(facet2));
    }

    function test_ReplaceFacetPreservesSelectors() public {
        MockReplaceFacet facet1 = new MockReplaceFacet();
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = facet1.function1.selector;
        selectors[1] = facet1.function2.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(facet1), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Replace with new facet
        MockReplaceFacetV2 facet2 = new MockReplaceFacetV2();

        vm.prank(owner);
        facetRegistry.replaceFunctions(address(facet2), selectors);

        IDiamondCut.FacetCut[] memory replaceCuts = new IDiamondCut.FacetCut[](1);
        replaceCuts[0] = createReplaceCut(address(facet2), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(replaceCuts, address(0), "");

        // Verify both selectors point to new facet
        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(facet2));
        assertEq(getDiamondLoupe().facetAddress(selectors[1]), address(facet2));
    }

    function test_ReplacePartialSelectors() public {
        MockReplaceFacet facet1 = new MockReplaceFacet();
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = facet1.function1.selector;
        selectors[1] = facet1.function2.selector;
        selectors[2] = facet1.function3.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(facet1), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Replace only first two selectors
        MockReplaceFacetV2 facet2 = new MockReplaceFacetV2();
        bytes4[] memory replaceSelectors = new bytes4[](2);
        replaceSelectors[0] = selectors[0];
        replaceSelectors[1] = selectors[1];

        vm.prank(owner);
        facetRegistry.replaceFunctions(address(facet2), replaceSelectors);

        IDiamondCut.FacetCut[] memory replaceCuts = new IDiamondCut.FacetCut[](1);
        replaceCuts[0] = createReplaceCut(address(facet2), replaceSelectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(replaceCuts, address(0), "");

        // First two should point to new facet, third should still point to old
        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(facet2));
        assertEq(getDiamondLoupe().facetAddress(selectors[1]), address(facet2));
        assertEq(getDiamondLoupe().facetAddress(selectors[2]), address(facet1));
    }

    function test_RevertIf_ReplaceToSameFacetAddress() public {
        MockReplaceFacet facet1 = new MockReplaceFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = facet1.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(facet1), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Registry will reject replacing with same facet
        vm.prank(owner);
        vm.expectRevert();
        facetRegistry.replaceFunctions(address(facet1), selectors);
    }

    function test_ReplaceMultipleFacetsInSingleCut() public {
        MockReplaceFacet facet1 = new MockReplaceFacet();
        MockReplaceFacet facet2 = new MockReplaceFacet();

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

        // Replace both
        MockReplaceFacetV2 newFacet1 = new MockReplaceFacetV2();
        MockReplaceFacetV2 newFacet2 = new MockReplaceFacetV2();

        vm.prank(owner);
        facetRegistry.replaceFunctions(address(newFacet1), selectors1);

        vm.prank(owner);
        facetRegistry.replaceFunctions(address(newFacet2), selectors2);

        IDiamondCut.FacetCut[] memory replaceCuts = new IDiamondCut.FacetCut[](2);
        replaceCuts[0] = createReplaceCut(address(newFacet1), selectors1);
        replaceCuts[1] = createReplaceCut(address(newFacet2), selectors2);

        vm.prank(owner);
        getDiamondCut().diamondCut(replaceCuts, address(0), "");

        assertEq(getDiamondLoupe().facetAddress(selectors1[0]), address(newFacet1));
        assertEq(getDiamondLoupe().facetAddress(selectors2[0]), address(newFacet2));
    }

    function test_RevertIf_ReplaceNonExistentSelector() public {
        MockReplaceFacetV2 facet2 = new MockReplaceFacetV2();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(keccak256("nonExistent()"));

        // Registry will reject replacing non-existent selector
        vm.prank(owner);
        vm.expectRevert();
        facetRegistry.replaceFunctions(address(facet2), selectors);
    }

    function test_RevertIf_ReplaceWithUnregisteredFacet() public {
        MockReplaceFacet facet1 = new MockReplaceFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = facet1.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(facet1), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Try to replace with unregistered facet
        MockReplaceFacetV2 unregisteredFacet = new MockReplaceFacetV2();

        IDiamondCut.FacetCut[] memory replaceCuts = new IDiamondCut.FacetCut[](1);
        replaceCuts[0] = createReplaceCut(address(unregisteredFacet), selectors);

        vm.prank(owner);
        vm.expectRevert();
        getDiamondCut().diamondCut(replaceCuts, address(0), "");
    }

    function test_RevertIf_NonOwnerReplacesFacet() public {
        MockReplaceFacet facet1 = new MockReplaceFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = facet1.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(facet1), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        MockReplaceFacetV2 facet2 = new MockReplaceFacetV2();

        vm.prank(owner);
        facetRegistry.replaceFunctions(address(facet2), selectors);

        IDiamondCut.FacetCut[] memory replaceCuts = new IDiamondCut.FacetCut[](1);
        replaceCuts[0] = createReplaceCut(address(facet2), selectors);

        vm.prank(nonOwner);
        vm.expectRevert();
        getDiamondCut().diamondCut(replaceCuts, address(0), "");
    }

    function test_ReplaceFacetUpdatesFacetAddresses() public {
        MockReplaceFacet facet1 = new MockReplaceFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = facet1.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(facet1), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        uint256 facetCountBefore = getDiamondLoupe().facetAddresses().length;

        // Replace
        MockReplaceFacetV2 facet2 = new MockReplaceFacetV2();

        vm.prank(owner);
        facetRegistry.replaceFunctions(address(facet2), selectors);

        IDiamondCut.FacetCut[] memory replaceCuts = new IDiamondCut.FacetCut[](1);
        replaceCuts[0] = createReplaceCut(address(facet2), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(replaceCuts, address(0), "");

        // Facet count should remain same (replacement, not addition)
        uint256 facetCountAfter = getDiamondLoupe().facetAddresses().length;
        assertEq(facetCountBefore, facetCountAfter);
    }

    function test_ReplaceFacetMaintainsSelectorMapping() public {
        MockReplaceFacet facet1 = new MockReplaceFacet();
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = facet1.function1.selector;
        selectors[1] = facet1.function2.selector;
        selectors[2] = facet1.function3.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(facet1), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Verify all selectors point to facet1
        for (uint256 i = 0; i < selectors.length; i++) {
            assertEq(getDiamondLoupe().facetAddress(selectors[i]), address(facet1));
        }

        // Replace
        MockReplaceFacetV2 facet2 = new MockReplaceFacetV2();

        vm.prank(owner);
        facetRegistry.replaceFunctions(address(facet2), selectors);

        IDiamondCut.FacetCut[] memory replaceCuts = new IDiamondCut.FacetCut[](1);
        replaceCuts[0] = createReplaceCut(address(facet2), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(replaceCuts, address(0), "");

        // Verify all selectors now point to facet2
        for (uint256 i = 0; i < selectors.length; i++) {
            assertEq(getDiamondLoupe().facetAddress(selectors[i]), address(facet2));
        }
    }

    function testFuzz_ReplaceFacet(uint256 selectorSeed) public {
        bytes4 selector = bytes4(bytes32(selectorSeed));

        // Skip if selector is zero or already exists
        vm.assume(selector != bytes4(0));
        vm.assume(getDiamondLoupe().facetAddress(selector) == address(0));

        MockReplaceFacet facet1 = new MockReplaceFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(facet1), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Replace
        MockReplaceFacetV2 facet2 = new MockReplaceFacetV2();

        vm.prank(owner);
        facetRegistry.replaceFunctions(address(facet2), selectors);

        IDiamondCut.FacetCut[] memory replaceCuts = new IDiamondCut.FacetCut[](1);
        replaceCuts[0] = createReplaceCut(address(facet2), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(replaceCuts, address(0), "");

        assertEq(getDiamondLoupe().facetAddress(selector), address(facet2));
    }
}

contract MockReplaceFacet {
    function function1() external pure returns (uint256) {
        return 100;
    }

    function function2() external pure returns (uint256) {
        return 200;
    }

    function function3() external pure returns (uint256) {
        return 300;
    }
}

contract MockReplaceFacetV2 {
    function function1() external pure returns (uint256) {
        return 1000;
    }

    function function2() external pure returns (uint256) {
        return 2000;
    }

    function function3() external pure returns (uint256) {
        return 3000;
    }
}
