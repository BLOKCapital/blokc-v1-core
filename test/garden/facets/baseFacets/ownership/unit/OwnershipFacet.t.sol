// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { DiamondTestBase } from "../../../../../base/DiamondTestBase.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";
import { OwnershipBase_InvalidNewOwner } from "src/garden/facets/baseFacets/ownership/OwnershipBase.sol";

contract OwnershipFacetTest is DiamondTestBase {
    address public garden;

    function setUp() public override {
        super.setUp();
        _addGardenTypeEmpty(GARDEN_TYPE_1);
        garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);
    }

    // ═════════════════════════════════════════════════════════════════
    //                     owner()
    // ═════════════════════════════════════════════════════════════════

    function test_owner_returnsGardenOwner() public view {
        assertEq(IERC173(garden).owner(), gardenOwner);
    }

    // ═════════════════════════════════════════════════════════════════
    //                     transferOwnership — SUCCESS
    // ═════════════════════════════════════════════════════════════════

    function test_transferOwnership_updatesOwner() public {
        vm.prank(gardenOwner);
        IERC173(garden).transferOwnership(alice);
        assertEq(IERC173(garden).owner(), alice);
    }

    function test_transferOwnership_emitsEvent() public {
        vm.prank(gardenOwner);
        vm.expectEmit(true, true, false, false);
        emit IERC173.OwnershipTransferred(gardenOwner, alice);
        IERC173(garden).transferOwnership(alice);
    }

    function test_transferOwnership_newOwnerCanTransferAgain() public {
        vm.prank(gardenOwner);
        IERC173(garden).transferOwnership(alice);

        vm.prank(alice);
        IERC173(garden).transferOwnership(bob);
        assertEq(IERC173(garden).owner(), bob);
    }

    function test_transferOwnership_revertsWhenTransferringToZero() public {
        // Transferring to address(0) would permanently brick the garden — all
        // onlyGardenOwner functions would be locked with no recoverable owner.
        vm.prank(gardenOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnershipBase_InvalidNewOwner.selector, address(0)));
        IERC173(garden).transferOwnership(address(0));
        // Owner is unchanged
        assertEq(IERC173(garden).owner(), gardenOwner);
    }

    function test_transferOwnership_oldOwnerLosesAccess() public {
        vm.prank(gardenOwner);
        IERC173(garden).transferOwnership(alice);

        // Old owner can no longer transfer
        vm.prank(gardenOwner);
        vm.expectRevert();
        IERC173(garden).transferOwnership(bob);
    }

    // ═════════════════════════════════════════════════════════════════
    //                     transferOwnership — REVERTS
    // ═════════════════════════════════════════════════════════════════

    function test_transferOwnership_revertsForNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        IERC173(garden).transferOwnership(nonOwner);
    }

    function test_transferOwnership_revertsForAttacker() public {
        vm.prank(attacker);
        vm.expectRevert();
        IERC173(garden).transferOwnership(attacker);
    }
}
