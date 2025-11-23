// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { DiamondTestBase } from "../DiamondTestBase.sol";
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";

/// @title DiamondCutAccessControlTest
/// @notice Comprehensive tests for access control in diamondCut
contract DiamondCutAccessControlTest is DiamondTestBase {
    function test_OnlyOwnerCanCallDiamondCut() public {
        MockAccessFacet mockFacet = new MockAccessFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        // Owner can call
        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(mockFacet));
    }

    function test_RevertIf_NonOwnerCallsDiamondCut() public {
        MockAccessFacet mockFacet = new MockAccessFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        // Non-owner cannot call
        vm.prank(nonOwner);
        vm.expectRevert();
        getDiamondCut().diamondCut(cuts, address(0), "");
    }

    function test_RevertIf_User1CallsDiamondCut() public {
        MockAccessFacet mockFacet = new MockAccessFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(user1);
        vm.expectRevert();
        getDiamondCut().diamondCut(cuts, address(0), "");
    }

    function test_RevertIf_User2CallsDiamondCut() public {
        MockAccessFacet mockFacet = new MockAccessFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(user2);
        vm.expectRevert();
        getDiamondCut().diamondCut(cuts, address(0), "");
    }

    function test_OwnerCanCallAfterOwnershipTransfer() public {
        // Transfer ownership
        vm.prank(owner);
        getDiamondOwnership().transferOwnership(user1);

        MockAccessFacet mockFacet = new MockAccessFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        // New owner can call
        vm.prank(user1);
        getDiamondCut().diamondCut(cuts, address(0), "");

        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(mockFacet));
    }

    function test_OldOwnerCannotCallAfterOwnershipTransfer() public {
        // Transfer ownership
        vm.prank(owner);
        getDiamondOwnership().transferOwnership(user1);

        MockAccessFacet mockFacet = new MockAccessFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        // Old owner cannot call
        vm.prank(owner);
        vm.expectRevert();
        getDiamondCut().diamondCut(cuts, address(0), "");
    }

    function test_AccessControlForAdd() public {
        MockAccessFacet mockFacet = new MockAccessFacet();
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

    function test_AccessControlForReplace() public {
        // Add first
        MockAccessFacet facet1 = new MockAccessFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = facet1.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(facet1), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Try to replace as non-owner
        MockAccessFacet facet2 = new MockAccessFacet();

        vm.prank(owner);
        facetRegistry.replaceFunctions(address(facet2), selectors);

        IDiamondCut.FacetCut[] memory replaceCuts = new IDiamondCut.FacetCut[](1);
        replaceCuts[0] = createReplaceCut(address(facet2), selectors);

        vm.prank(nonOwner);
        vm.expectRevert();
        getDiamondCut().diamondCut(replaceCuts, address(0), "");
    }

    function test_AccessControlForRemove() public {
        // Add first
        MockAccessFacet mockFacet = new MockAccessFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Remove from registry
        vm.prank(owner);
        facetRegistry.removeFunctions(address(0), selectors);

        // Try to remove as non-owner
        IDiamondCut.FacetCut[] memory removeCuts = new IDiamondCut.FacetCut[](1);
        removeCuts[0] = createRemoveCut(selectors);

        vm.prank(nonOwner);
        vm.expectRevert();
        getDiamondCut().diamondCut(removeCuts, address(0), "");
    }

    function test_AccessControlForMultipleOperations() public {
        MockAccessFacet facet1 = new MockAccessFacet();
        MockAccessFacet facet2 = new MockAccessFacet();

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

        vm.prank(nonOwner);
        vm.expectRevert();
        getDiamondCut().diamondCut(cuts, address(0), "");
    }

    function test_AccessControlWithInitialization() public {
        MockAccessFacet mockFacet = new MockAccessFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        InitAccessContract initContract = new InitAccessContract();
        bytes memory initData = abi.encodeWithSelector(InitAccessContract.init.selector);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(nonOwner);
        vm.expectRevert();
        getDiamondCut().diamondCut(cuts, address(initContract), initData);
    }

    function testFuzz_AccessControl(address caller) public {
        vm.assume(caller != owner);
        vm.assume(caller != address(0));
        vm.assume(caller.code.length == 0); // Not a contract

        MockAccessFacet mockFacet = new MockAccessFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(caller);
        vm.expectRevert();
        getDiamondCut().diamondCut(cuts, address(0), "");
    }

    function test_AccessControlAfterMultipleTransfers() public {
        // Transfer ownership multiple times
        vm.prank(owner);
        getDiamondOwnership().transferOwnership(user1);

        vm.prank(user1);
        getDiamondOwnership().transferOwnership(user2);

        MockAccessFacet mockFacet = new MockAccessFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        // Only user2 (current owner) can call
        vm.prank(user2);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Previous owners cannot
        vm.prank(owner);
        vm.expectRevert();
        getDiamondCut().diamondCut(cuts, address(0), "");

        vm.prank(user1);
        vm.expectRevert();
        getDiamondCut().diamondCut(cuts, address(0), "");
    }
}

contract MockAccessFacet {
    function function1() external pure returns (uint256) {
        return 200;
    }
}

contract InitAccessContract {
    function init() external {
        // Init logic
    }
}
