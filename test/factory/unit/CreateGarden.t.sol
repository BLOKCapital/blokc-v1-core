// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { GardenFactoryTestBase } from "../GardenFactoryTestBase.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";

contract GardenFactoryCreateGardenTest is GardenFactoryTestBase {
    // ═══════════════════════════════════════════════════════════════════
    //                     SUCCESS — BASIC CREATION
    // ═══════════════════════════════════════════════════════════════════

    function test_createGarden_returnsNonZeroAddress() public {
        address garden = _createDefaultGarden(alice, 1);
        assertTrue(garden != address(0));
    }

    function test_createGarden_registersGarden() public {
        address garden = _createDefaultGarden(alice, 1);
        assertTrue(factory.isGardenRegistered(garden));
    }

    function test_createGarden_incrementsTotalGardens() public {
        _createDefaultGarden(alice, 1);
        assertEq(factory.getTotalGardens(), 1);

        _createDefaultGarden(bob, 1);
        assertEq(factory.getTotalGardens(), 2);
    }

    function test_createGarden_tracksUserGarden() public {
        address garden = _createDefaultGarden(alice, 1);

        address[] memory userGardens = factory.getUserGardens(alice);
        assertEq(userGardens.length, 1);
        assertEq(userGardens[0], garden);
    }

    function test_createGarden_mapsIndexToGarden() public {
        address garden = _createDefaultGarden(alice, 3);
        assertEq(factory.getGarden(alice, 3), garden);
    }

    function test_createGarden_setsGardenOwner() public {
        address garden = _createDefaultGarden(alice, 1);
        assertEq(factory.getGardenOwner(garden), alice);
    }

    function test_createGarden_setsGardenType() public {
        address garden = _createDefaultGarden(alice, 1);
        assertEq(factory.getGardenType(garden), GARDEN_TYPE_1);
    }

    function test_createGarden_gardenDiamondOwnerMatchesCaller() public {
        address garden = _createDefaultGarden(alice, 1);
        assertEq(IERC173(garden).owner(), alice);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     SUCCESS — EVENT EMISSION
    // ═══════════════════════════════════════════════════════════════════

    function test_createGarden_emitsGardenCreated() public {
        // We can't predict the exact garden address for topic matching,
        // so check event is emitted with correct owner and index
        vm.prank(alice);
        vm.expectEmit(false, true, true, false);
        emit GardenFactory.GardenCreated(address(0), alice, 1);
        factory.createGarden(1, GARDEN_TYPE_1);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     SUCCESS — INDEX BOUNDARIES
    // ═══════════════════════════════════════════════════════════════════

    function test_createGarden_worksWithIndex1() public {
        address garden = _createDefaultGarden(alice, 1);
        assertTrue(garden != address(0));
    }

    function test_createGarden_worksWithIndex10() public {
        address garden = _createDefaultGarden(alice, 10);
        assertTrue(garden != address(0));
    }

    function test_createGarden_allTenIndices() public {
        for (uint256 i = 1; i <= 10; i++) {
            address garden = _createDefaultGarden(alice, i);
            assertTrue(garden != address(0));
            assertEq(factory.getGarden(alice, i), garden);
        }
        assertEq(factory.getUserGardenCount(alice), 10);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     SUCCESS — MULTI-USER
    // ═══════════════════════════════════════════════════════════════════

    function test_createGarden_differentUsersCanUseSameIndex() public {
        address gardenAlice = _createDefaultGarden(alice, 1);
        address gardenBob = _createDefaultGarden(bob, 1);

        assertTrue(gardenAlice != gardenBob);
        assertEq(factory.getTotalGardens(), 2);
    }

    function test_createGarden_multipleUserGardensTrackedSeparately() public {
        _createDefaultGarden(alice, 1);
        _createDefaultGarden(alice, 2);
        _createDefaultGarden(bob, 1);

        assertEq(factory.getUserGardenCount(alice), 2);
        assertEq(factory.getUserGardenCount(bob), 1);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     SUCCESS — MULTI-TYPE
    // ═══════════════════════════════════════════════════════════════════

    function test_createGarden_withDifferentTypes() public {
        address g1 = _createGarden(alice, 1, GARDEN_TYPE_1);
        address g2 = _createGarden(alice, 2, GARDEN_TYPE_2);

        assertEq(factory.getGardenType(g1), GARDEN_TYPE_1);
        assertEq(factory.getGardenType(g2), GARDEN_TYPE_2);
    }

    function test_createGarden_tracksGardensByType() public {
        _createGarden(alice, 1, GARDEN_TYPE_1);
        _createGarden(bob, 1, GARDEN_TYPE_1);
        _createGarden(alice, 2, GARDEN_TYPE_2);

        assertEq(factory.getGardensByTypeCount(GARDEN_TYPE_1), 2);
        assertEq(factory.getGardensByTypeCount(GARDEN_TYPE_2), 1);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     SUCCESS — DETERMINISTIC ADDRESS
    // ═══════════════════════════════════════════════════════════════════

    function test_createGarden_deterministicAddress() public {
        // Different indices for same user produce different addresses
        address g1 = _createDefaultGarden(alice, 1);
        address g2 = _createDefaultGarden(alice, 2);
        assertTrue(g1 != g2);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     SUCCESS — PROTOCOL STATUS UPGRADES_DISABLED
    // ═══════════════════════════════════════════════════════════════════

    function test_createGarden_succeedsWhenUpgradesDisabled() public {
        protocolStatus.setStatus(IProtocolStatus.State.UPGRADES_DISABLED);
        // UPGRADES_DISABLED != INACTIVE, so creation should succeed
        address garden = _createDefaultGarden(alice, 1);
        assertTrue(garden != address(0));
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     REVERT — INDEX VALIDATION
    // ═══════════════════════════════════════════════════════════════════

    function test_createGarden_revertsWhenIndexIsZero() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("GardenFactory_IndexOutOfRange(uint256)")), 0));
        factory.createGarden(0, GARDEN_TYPE_1);
    }

    function test_createGarden_revertsWhenIndexIs11() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("GardenFactory_IndexOutOfRange(uint256)")), 11));
        factory.createGarden(11, GARDEN_TYPE_1);
    }

    function test_createGarden_revertsWhenIndexIsLarge() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("GardenFactory_IndexOutOfRange(uint256)")), type(uint256).max)
        );
        factory.createGarden(type(uint256).max, GARDEN_TYPE_1);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     REVERT — DUPLICATE INDEX
    // ═══════════════════════════════════════════════════════════════════

    function test_createGarden_revertsWhenIndexAlreadyUsed() public {
        _createDefaultGarden(alice, 1);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("GardenFactory_IndexAlreadyUsed(address,uint256)")), alice, 1)
        );
        factory.createGarden(1, GARDEN_TYPE_1);
    }

    function test_createGarden_revertsOnDuplicateIndexEvenWithDifferentType() public {
        _createGarden(alice, 1, GARDEN_TYPE_1);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("GardenFactory_IndexAlreadyUsed(address,uint256)")), alice, 1)
        );
        factory.createGarden(1, GARDEN_TYPE_2);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     REVERT — PROTOCOL INACTIVE
    // ═══════════════════════════════════════════════════════════════════

    function test_createGarden_revertsWhenProtocolInactive() public {
        protocolStatus.setStatus(IProtocolStatus.State.INACTIVE);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("GardenFactory_ProtocolIsInactive()"));
        factory.createGarden(1, GARDEN_TYPE_1);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     REVERT — UNREGISTERED GARDEN TYPE
    // ═══════════════════════════════════════════════════════════════════

    function test_createGarden_revertsWhenGardenTypeNotRegistered() public {
        bytes32 unregistered = keccak256("UNREGISTERED");
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("GardenFactory_GardenTypeNotRegistered(bytes32)")), unregistered
            )
        );
        factory.createGarden(1, unregistered);
    }

    function test_createGarden_revertsWhenGardenTypeIsZero() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("GardenFactory_GardenTypeNotRegistered(bytes32)")), bytes32(0)
            )
        );
        factory.createGarden(1, bytes32(0));
    }
}
