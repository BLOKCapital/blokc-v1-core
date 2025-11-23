// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { DiamondTestBase } from "../DiamondTestBase.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";

/// @title OwnershipAccessControlTest
/// @notice Comprehensive tests for ownership-based access control
contract OwnershipAccessControlTest is DiamondTestBase {
    function test_OnlyOwnerCanTransferOwnership() public {
        vm.prank(owner);
        getDiamondOwnership().transferOwnership(user1);

        assertEq(getDiamondOwnership().owner(), user1);
    }

    function test_RevertIf_NonOwnerTransfersOwnership() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        getDiamondOwnership().transferOwnership(nonOwner);
    }

    function test_OnlyOwnerCanCallOwnerFunctions() public {
        MockOwnershipFacet mockFacet = new MockOwnershipFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        // Owner can call
        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Non-owner cannot
        vm.prank(nonOwner);
        vm.expectRevert();
        getDiamondCut().diamondCut(cuts, address(0), "");
    }

    function test_AccessControlPersistsAfterTransfer() public {
        // Transfer ownership
        vm.prank(owner);
        getDiamondOwnership().transferOwnership(user1);

        MockOwnershipFacet mockFacet = new MockOwnershipFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        // New owner can call
        vm.prank(user1);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Old owner cannot
        vm.prank(owner);
        vm.expectRevert();
        getDiamondCut().diamondCut(cuts, address(0), "");
    }

    function test_OwnerCanQueryOwnership() public view {
        address currentOwner = getDiamondOwnership().owner();
        assertEq(currentOwner, owner);
    }

    function test_NonOwnerCanQueryOwnership() public {
        // Anyone can query ownership (view function)
        vm.prank(nonOwner);
        address currentOwner = getDiamondOwnership().owner();
        assertEq(currentOwner, owner);
    }

    function test_AccessControlForDiamondCut() public {
        MockOwnershipFacet mockFacet = new MockOwnershipFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        // Test different callers
        vm.prank(user1);
        vm.expectRevert();
        getDiamondCut().diamondCut(cuts, address(0), "");

        vm.prank(user2);
        vm.expectRevert();
        getDiamondCut().diamondCut(cuts, address(0), "");

        vm.prank(nonOwner);
        vm.expectRevert();
        getDiamondCut().diamondCut(cuts, address(0), "");
    }

    function test_AccessControlForUpgrade() public {
        MockOwnershipFacet mockFacet = new MockOwnershipFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        // Non-owner cannot upgrade
        vm.prank(nonOwner);
        vm.expectRevert();
        getDiamondUpgrade().upgrade(bytes32(0));
    }

    function test_AccessControlMultipleOperations() public {
        // Transfer ownership
        vm.prank(owner);
        getDiamondOwnership().transferOwnership(user1);

        MockOwnershipFacet mockFacet = new MockOwnershipFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        // Only user1 (current owner) can perform operations
        vm.prank(user1);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Others cannot
        vm.prank(owner);
        vm.expectRevert();
        getDiamondCut().diamondCut(cuts, address(0), "");

        vm.prank(user2);
        vm.expectRevert();
        getDiamondCut().diamondCut(cuts, address(0), "");
    }

    function testFuzz_AccessControl(address caller) public {
        vm.assume(caller != owner);
        vm.assume(caller != address(0));
        vm.assume(caller.code.length == 0);

        MockOwnershipFacet mockFacet = new MockOwnershipFacet();
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

    function test_AccessControlAfterRenouncingOwnership() public {
        // Transfer to zero address (renounce)
        vm.prank(owner);
        getDiamondOwnership().transferOwnership(address(0));

        assertEq(getDiamondOwnership().owner(), address(0));

        MockOwnershipFacet mockFacet = new MockOwnershipFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        // No one can call (including old owner)
        vm.prank(owner);
        vm.expectRevert();
        getDiamondCut().diamondCut(cuts, address(0), "");

        vm.prank(user1);
        vm.expectRevert();
        getDiamondCut().diamondCut(cuts, address(0), "");
    }
}

contract MockOwnershipFacet {
    function function1() external pure returns (uint256) {
        return 500;
    }
}
