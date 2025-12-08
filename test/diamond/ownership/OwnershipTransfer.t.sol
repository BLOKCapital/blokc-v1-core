// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { DiamondTestBase } from "../DiamondTestBase.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";

/// @title OwnershipFacetTest
/// @notice Tests for OwnershipFacet functionality
contract OwnershipFacetTest is DiamondTestBase {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function test_Owner_ReturnsCorrectOwner() public view {
        assertEq(getDiamondOwnership().owner(), owner);
    }

    function test_TransferOwnership_Success() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(owner, user1);
        getDiamondOwnership().transferOwnership(user1);

        assertEq(getDiamondOwnership().owner(), user1);
    }

    function test_TransferOwnership_MultipleTimes() public {
        // First transfer
        vm.prank(owner);
        getDiamondOwnership().transferOwnership(user1);
        assertEq(getDiamondOwnership().owner(), user1);

        // Second transfer
        vm.prank(user1);
        getDiamondOwnership().transferOwnership(user2);
        assertEq(getDiamondOwnership().owner(), user2);

        // Third transfer
        vm.prank(user2);
        getDiamondOwnership().transferOwnership(owner);
        assertEq(getDiamondOwnership().owner(), owner);
    }

    function test_RevertIf_NonOwnerTransfersOwnership() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        getDiamondOwnership().transferOwnership(nonOwner);
    }

    function test_TransferToZeroAddress() public {
        // Note: OwnershipFacet may or may not prevent transfer to zero address
        // depending on implementation. Testing actual behavior here.
        vm.prank(owner);
        getDiamondOwnership().transferOwnership(address(0));

        // If it succeeded, verify owner is zero
        assertEq(getDiamondOwnership().owner(), address(0));
    }

    function test_OldOwnerCannotActAfterTransfer() public {
        // Transfer ownership
        vm.prank(owner);
        getDiamondOwnership().transferOwnership(user1);

        // Old owner should not be able to transfer again
        vm.prank(owner);
        vm.expectRevert();
        getDiamondOwnership().transferOwnership(user2);
    }

    function test_NewOwnerCanActAfterTransfer() public {
        // Transfer ownership
        vm.prank(owner);
        getDiamondOwnership().transferOwnership(user1);

        // New owner should be able to transfer
        vm.prank(user1);
        getDiamondOwnership().transferOwnership(user2);

        assertEq(getDiamondOwnership().owner(), user2);
    }

    function test_OwnershipTransferEmitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(owner, user1);
        getDiamondOwnership().transferOwnership(user1);
    }

    function testFuzz_TransferOwnership(address newOwner) public {
        vm.assume(newOwner != address(0));
        vm.assume(newOwner.code.length == 0); // Not a contract

        vm.prank(owner);
        getDiamondOwnership().transferOwnership(newOwner);

        assertEq(getDiamondOwnership().owner(), newOwner);
    }

    function test_OwnershipPersistsAcrossOperations() public {
        // Perform some operations
        MockOwnershipFacet mockFacet = new MockOwnershipFacet();
        bytes4[] memory mockSelectors = new bytes4[](1);
        mockSelectors[0] = mockFacet.mockFunction.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), mockSelectors);

        // Owner should still be the same
        assertEq(getDiamondOwnership().owner(), owner);

        // Transfer ownership
        vm.prank(owner);
        getDiamondOwnership().transferOwnership(user1);

        // Ownership should have changed
        assertEq(getDiamondOwnership().owner(), user1);
    }

    function test_OnlyOwnerCanPerformOwnerActions() public {
        // Deploy mock facet
        MockOwnershipFacet mockFacet = new MockOwnershipFacet();
        bytes4[] memory mockSelectors = new bytes4[](1);
        mockSelectors[0] = mockFacet.mockFunction.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), mockSelectors);

        // Non-owner should not be able to call diamondCut
        vm.prank(nonOwner);
        vm.expectRevert();
        getDiamondCut().diamondCut(new IDiamondCut.FacetCut[](0), address(0), "");

        // Owner should be able to call diamondCut
        vm.prank(owner);
        getDiamondCut().diamondCut(new IDiamondCut.FacetCut[](0), address(0), "");
    }
}

contract MockOwnershipFacet {
    function mockFunction() external pure returns (uint256) {
        return 100;
    }
}
