// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { GardenFactoryTestBase } from "../GardenFactoryTestBase.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";

contract GardenFactoryFuzzTest is GardenFactoryTestBase {
    // ═══════════════════════════════════════════════════════════════════
    //                  FUZZ — createGarden success
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Any valid user/index combo should produce a registered garden
    function testFuzz_createGarden_validIndexRegistersGarden(address user, uint256 index) public {
        user = _boundAddress(user);
        index = bound(index, 1, 10);

        vm.prank(user);
        address garden = factory.createGarden(index, GARDEN_TYPE_1);

        assertTrue(factory.isGardenRegistered(garden));
        assertEq(factory.getGarden(user, index), garden);
        assertEq(factory.getGardenOwner(garden), user);
        assertEq(factory.getGardenType(garden), GARDEN_TYPE_1);
    }

    /// @notice Diamond owner should always be the caller, not the factory owner
    function testFuzz_createGarden_diamondOwnerIsCaller(address user, uint256 index) public {
        user = _boundAddress(user);
        index = bound(index, 1, 10);

        vm.prank(user);
        address garden = factory.createGarden(index, GARDEN_TYPE_1);

        assertEq(IERC173(garden).owner(), user);
    }

    /// @notice Creating a garden should always increment total count by exactly 1
    function testFuzz_createGarden_incrementsTotalByOne(address user, uint256 index) public {
        user = _boundAddress(user);
        index = bound(index, 1, 10);

        uint256 before = factory.getTotalGardens();
        vm.prank(user);
        factory.createGarden(index, GARDEN_TYPE_1);

        assertEq(factory.getTotalGardens(), before + 1);
    }

    /// @notice User garden count should always increment by 1 on creation
    function testFuzz_createGarden_incrementsUserCountByOne(address user, uint256 index) public {
        user = _boundAddress(user);
        index = bound(index, 1, 10);

        uint256 before = factory.getUserGardenCount(user);
        vm.prank(user);
        factory.createGarden(index, GARDEN_TYPE_1);

        assertEq(factory.getUserGardenCount(user), before + 1);
    }

    /// @notice After creation, index should no longer be available
    function testFuzz_createGarden_indexBecomesUnavailable(address user, uint256 index) public {
        user = _boundAddress(user);
        index = bound(index, 1, 10);

        assertTrue(factory.isIndexAvailable(user, index));

        vm.prank(user);
        factory.createGarden(index, GARDEN_TYPE_1);

        assertFalse(factory.isIndexAvailable(user, index));
    }

    /// @notice Two different users using the same index produce different gardens
    function testFuzz_createGarden_differentUsersGetDifferentAddresses(
        address user1,
        address user2,
        uint256 index
    )
        public
    {
        user1 = _boundAddress(user1);
        user2 = _boundAddress(user2);
        vm.assume(user1 != user2);
        index = bound(index, 1, 10);

        vm.prank(user1);
        address g1 = factory.createGarden(index, GARDEN_TYPE_1);

        vm.prank(user2);
        address g2 = factory.createGarden(index, GARDEN_TYPE_1);

        assertTrue(g1 != g2);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                  FUZZ — createGarden reverts
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Any index outside 1-10 should revert
    function testFuzz_createGarden_revertsOnInvalidIndex(address user, uint256 index) public {
        user = _boundAddress(user);
        // Exclude valid range 1-10
        vm.assume(index == 0 || index > 10);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("GardenFactory_IndexOutOfRange(uint256)")), index)
        );
        factory.createGarden(index, GARDEN_TYPE_1);
    }

    /// @notice Duplicate index for same user should always revert
    function testFuzz_createGarden_revertsOnDuplicateIndex(address user, uint256 index) public {
        user = _boundAddress(user);
        index = bound(index, 1, 10);

        vm.prank(user);
        factory.createGarden(index, GARDEN_TYPE_1);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("GardenFactory_IndexAlreadyUsed(address,uint256)")), user, index
            )
        );
        factory.createGarden(index, GARDEN_TYPE_1);
    }

    /// @notice Unregistered garden type should always revert
    function testFuzz_createGarden_revertsOnUnregisteredType(bytes32 gardenType) public {
        // Exclude registered types
        vm.assume(gardenType != GARDEN_TYPE_1 && gardenType != GARDEN_TYPE_2);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("GardenFactory_GardenTypeNotRegistered(bytes32)")), gardenType
            )
        );
        factory.createGarden(1, gardenType);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                  FUZZ — index availability
    // ═══════════════════════════════════════════════════════════════════

    /// @notice isIndexAvailable should return false for out-of-range indices
    function testFuzz_isIndexAvailable_falseForOutOfRange(address user, uint256 index) public view {
        vm.assume(index == 0 || index > 10);
        assertFalse(factory.isIndexAvailable(user, index));
    }

    /// @notice available + used indices should always sum to 10 for any user
    function testFuzz_availablePlusUsedEqualsTen(address user, uint256 gardenCount) public {
        user = _boundAddress(user);
        gardenCount = bound(gardenCount, 0, 10);

        for (uint256 i = 1; i <= gardenCount; i++) {
            vm.prank(user);
            factory.createGarden(i, GARDEN_TYPE_1);
        }

        uint256[] memory available = factory.getUserAvailableIndices(user);
        uint256[] memory used = factory.getUserUsedIndices(user);

        assertEq(available.length + used.length, 10);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                  FUZZ — pagination
    // ═══════════════════════════════════════════════════════════════════

    /// @notice getGardensByRange should never return more elements than exist
    function testFuzz_getGardensByRange_neverExceedsTotal(uint256 offset, uint256 limit) public {
        // Create 3 gardens
        _createDefaultGarden(alice, 1);
        _createDefaultGarden(bob, 1);
        _createDefaultGarden(charlie, 1);

        uint256 total = factory.getTotalGardens();
        address[] memory page = factory.getGardensByRange(offset, limit);

        assertLe(page.length, total);

        if (offset >= total) {
            assertEq(page.length, 0);
        } else {
            uint256 expectedMax = total - offset;
            if (limit < expectedMax) expectedMax = limit;
            assertEq(page.length, expectedMax);
        }
    }

    /// @notice getGardensByTypeRange should never return more than exist for that type
    function testFuzz_getGardensByTypeRange_neverExceedsTypeTotal(uint256 offset, uint256 limit) public {
        _createGarden(alice, 1, GARDEN_TYPE_1);
        _createGarden(bob, 1, GARDEN_TYPE_1);
        _createGarden(alice, 2, GARDEN_TYPE_2);

        uint256 total = factory.getGardensByTypeCount(GARDEN_TYPE_1);
        address[] memory page = factory.getGardensByTypeRange(GARDEN_TYPE_1, offset, limit);

        assertLe(page.length, total);

        if (offset >= total) {
            assertEq(page.length, 0);
        } else {
            uint256 expectedMax = total - offset;
            if (limit < expectedMax) expectedMax = limit;
            assertEq(page.length, expectedMax);
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //                  FUZZ — multi-type tracking
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Garden type tracking should be consistent regardless of creation order
    function testFuzz_createGarden_typeTrackingConsistentAcrossTypes(
        uint256 idx1,
        uint256 idx2
    )
        public
    {
        idx1 = bound(idx1, 1, 5);
        idx2 = bound(idx2, 6, 10);

        address g1 = _createGarden(alice, idx1, GARDEN_TYPE_1);
        address g2 = _createGarden(alice, idx2, GARDEN_TYPE_2);

        // Type counts
        assertEq(factory.getGardensByTypeCount(GARDEN_TYPE_1), 1);
        assertEq(factory.getGardensByTypeCount(GARDEN_TYPE_2), 1);

        // User type counts
        assertEq(factory.getUserGardensByTypeCount(alice, GARDEN_TYPE_1), 1);
        assertEq(factory.getUserGardensByTypeCount(alice, GARDEN_TYPE_2), 1);

        // Type arrays contain correct gardens
        assertEq(factory.getGardensByType(GARDEN_TYPE_1)[0], g1);
        assertEq(factory.getGardensByType(GARDEN_TYPE_2)[0], g2);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                  FUZZ — getGardenInfo consistency
    // ═══════════════════════════════════════════════════════════════════

    /// @notice getGardenInfo should always match individual getters
    function testFuzz_getGardenInfo_matchesIndividualGetters(address user, uint256 index) public {
        user = _boundAddress(user);
        index = bound(index, 1, 10);

        vm.prank(user);
        address garden = factory.createGarden(index, GARDEN_TYPE_1);

        (address infoOwner, bytes32 infoType, bool registered) = factory.getGardenInfo(garden);

        assertEq(infoOwner, factory.getGardenOwner(garden));
        assertEq(infoType, factory.getGardenType(garden));
        assertEq(registered, factory.isGardenRegistered(garden));
    }
}
