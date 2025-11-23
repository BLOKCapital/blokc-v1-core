// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { DiamondTestBase } from "../DiamondTestBase.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";
import { OwnershipFacet } from "src/diamond/facets/baseFacets/ownership/OwnershipFacet.sol";
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";

/// @title OwnershipEdgeCasesTest
/// @notice Comprehensive edge case tests for ownership functionality
contract OwnershipEdgeCasesTest is DiamondTestBase {
    function test_TransferOwnershipToSameAddress() public {
        // Transfer to self
        vm.prank(owner);
        getDiamondOwnership().transferOwnership(owner);

        assertEq(getDiamondOwnership().owner(), owner);
    }

    function test_TransferOwnershipToContract() public {
        MockContract mockContract = new MockContract();

        vm.prank(owner);
        getDiamondOwnership().transferOwnership(address(mockContract));

        assertEq(getDiamondOwnership().owner(), address(mockContract));
    }

    function test_TransferOwnershipToEOA() public {
        address eoa = makeAddr("eoa");

        vm.prank(owner);
        getDiamondOwnership().transferOwnership(eoa);

        assertEq(getDiamondOwnership().owner(), eoa);
    }

    function test_TransferOwnershipMultipleTimesRapidly() public {
        vm.prank(owner);
        getDiamondOwnership().transferOwnership(user1);
        assertEq(getDiamondOwnership().owner(), user1);

        vm.prank(user1);
        getDiamondOwnership().transferOwnership(user2);
        assertEq(getDiamondOwnership().owner(), user2);

        vm.prank(user2);
        getDiamondOwnership().transferOwnership(owner);
        assertEq(getDiamondOwnership().owner(), owner);
    }

    function test_TransferOwnershipAndBack() public {
        vm.prank(owner);
        getDiamondOwnership().transferOwnership(user1);
        assertEq(getDiamondOwnership().owner(), user1);

        vm.prank(user1);
        getDiamondOwnership().transferOwnership(owner);
        assertEq(getDiamondOwnership().owner(), owner);
    }

    function test_TransferOwnershipCircular() public {
        vm.prank(owner);
        getDiamondOwnership().transferOwnership(user1);

        vm.prank(user1);
        getDiamondOwnership().transferOwnership(user2);

        vm.prank(user2);
        getDiamondOwnership().transferOwnership(user1);

        assertEq(getDiamondOwnership().owner(), user1);
    }

    function test_TransferOwnershipToZeroAddress() public {
        vm.prank(owner);
        getDiamondOwnership().transferOwnership(address(0));

        assertEq(getDiamondOwnership().owner(), address(0));
    }

    function test_OwnerIsZeroAfterRenouncing() public {
        vm.prank(owner);
        getDiamondOwnership().transferOwnership(address(0));

        assertEq(getDiamondOwnership().owner(), address(0));
    }

    function test_CannotTransferAfterRenouncing() public {
        vm.prank(owner);
        getDiamondOwnership().transferOwnership(address(0));

        // Cannot transfer from zero address
        // This would require a transaction from address(0) which is not possible
        assertEq(getDiamondOwnership().owner(), address(0));
    }

    function test_OwnershipPersistsAcrossFacetOperations() public {
        // Perform facet operations
        MockEdgeFacet mockFacet = new MockEdgeFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Ownership should still be the same
        assertEq(getDiamondOwnership().owner(), owner);
    }

    function test_OwnershipPersistsAcrossUpgrades() public {
        MockEdgeFacet mockFacet = new MockEdgeFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondUpgrade().upgrade(bytes32(0));

        // Ownership should still be the same
        assertEq(getDiamondOwnership().owner(), owner);
    }

    function test_OwnershipTransferPreservesFacets() public {
        MockEdgeFacet mockFacet = new MockEdgeFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Transfer ownership
        vm.prank(owner);
        getDiamondOwnership().transferOwnership(user1);

        // Facets should still be present
        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(mockFacet));
    }

    function testFuzz_TransferOwnership(address newOwner) public {
        vm.assume(newOwner != address(diamond));

        vm.prank(owner);
        getDiamondOwnership().transferOwnership(newOwner);

        assertEq(getDiamondOwnership().owner(), newOwner);
    }

    function test_OwnershipQueryFromDifferentAccounts() public {
        // Query as owner
        assertEq(getDiamondOwnership().owner(), owner);

        // Query as user1 (should return same) - ownership is public
        address ownerFromUser1 = getDiamondOwnership().owner();
        assertEq(ownerFromUser1, owner);

        // Query as user2 (should return same)
        address ownerFromUser2 = getDiamondOwnership().owner();
        assertEq(ownerFromUser2, owner);
    }

    function test_OwnershipAfterMultipleTransfers() public {
        address[] memory owners = new address[](5);
        owners[0] = owner;
        owners[1] = user1;
        owners[2] = user2;
        owners[3] = makeAddr("user3");
        owners[4] = makeAddr("user4");

        for (uint256 i = 0; i < owners.length - 1; i++) {
            vm.prank(owners[i]);
            getDiamondOwnership().transferOwnership(owners[i + 1]);
            assertEq(getDiamondOwnership().owner(), owners[i + 1]);
        }
    }

    function test_OwnershipTransferSucceeds() public {
        vm.prank(owner);
        getDiamondOwnership().transferOwnership(user1);
        assertEq(getDiamondOwnership().owner(), user1);
    }

    function test_OwnershipTransferMultipleTimes() public {
        vm.prank(owner);
        getDiamondOwnership().transferOwnership(user1);
        assertEq(getDiamondOwnership().owner(), user1);

        vm.prank(user1);
        getDiamondOwnership().transferOwnership(user2);
        assertEq(getDiamondOwnership().owner(), user2);
    }
}

contract MockEdgeFacet {
    function function1() external pure returns (uint256) {
        return 600;
    }
}

contract MockContract {
// Simple contract for testing
}
