// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { GardenFactoryTestBase } from "../GardenFactoryTestBase.sol";

contract GardenFactoryTypeViewsTest is GardenFactoryTestBase {
    // ═══════════════════════════════════════════════════════════════════
    //                     getGardenType
    // ═══════════════════════════════════════════════════════════════════

    function test_getGardenType_returnsCorrectType() public {
        address g1 = _createGarden(alice, 1, GARDEN_TYPE_1);
        address g2 = _createGarden(alice, 2, GARDEN_TYPE_2);

        assertEq(factory.getGardenType(g1), GARDEN_TYPE_1);
        assertEq(factory.getGardenType(g2), GARDEN_TYPE_2);
    }

    function test_getGardenType_returnsZeroForUnknownGarden() public view {
        assertEq(factory.getGardenType(address(0xDEAD)), bytes32(0));
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     getGardenOwner
    // ═══════════════════════════════════════════════════════════════════

    function test_getGardenOwner_returnsCorrectOwner() public {
        address g1 = _createDefaultGarden(alice, 1);
        address g2 = _createDefaultGarden(bob, 1);

        assertEq(factory.getGardenOwner(g1), alice);
        assertEq(factory.getGardenOwner(g2), bob);
    }

    function test_getGardenOwner_returnsZeroForUnknownGarden() public view {
        assertEq(factory.getGardenOwner(address(0xDEAD)), address(0));
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     getGardensByType / getGardensByTypeCount
    // ═══════════════════════════════════════════════════════════════════

    function test_getGardensByType_returnsAllGardensOfType() public {
        address g1 = _createGarden(alice, 1, GARDEN_TYPE_1);
        address g2 = _createGarden(bob, 1, GARDEN_TYPE_1);
        _createGarden(alice, 2, GARDEN_TYPE_2);

        address[] memory type1Gardens = factory.getGardensByType(GARDEN_TYPE_1);
        assertEq(type1Gardens.length, 2);

        bool found1;
        bool found2;
        for (uint256 i = 0; i < type1Gardens.length; i++) {
            if (type1Gardens[i] == g1) found1 = true;
            if (type1Gardens[i] == g2) found2 = true;
        }
        assertTrue(found1 && found2);
    }

    function test_getGardensByTypeCount_matchesArrayLength() public {
        _createGarden(alice, 1, GARDEN_TYPE_1);
        _createGarden(bob, 1, GARDEN_TYPE_1);
        _createGarden(charlie, 1, GARDEN_TYPE_1);

        assertEq(factory.getGardensByTypeCount(GARDEN_TYPE_1), 3);
        assertEq(factory.getGardensByType(GARDEN_TYPE_1).length, 3);
    }

    function test_getGardensByTypeCount_zeroForUnusedType() public view {
        assertEq(factory.getGardensByTypeCount(keccak256("NONEXISTENT")), 0);
    }

    function test_getGardensByType_emptyForUnusedType() public view {
        assertEq(factory.getGardensByType(keccak256("NONEXISTENT")).length, 0);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     getGardensByTypeRange (pagination)
    // ═══════════════════════════════════════════════════════════════════

    function test_getGardensByTypeRange_returnsCorrectSubset() public {
        // Create 4 gardens of TYPE_1
        for (uint256 i = 1; i <= 4; i++) {
            address user = i <= 2 ? alice : bob;
            uint256 idx = i <= 2 ? i : i - 2;
            _createGarden(user, idx, GARDEN_TYPE_1);
        }

        address[] memory page = factory.getGardensByTypeRange(GARDEN_TYPE_1, 1, 2);
        assertEq(page.length, 2);
    }

    function test_getGardensByTypeRange_clampsToTotal() public {
        _createGarden(alice, 1, GARDEN_TYPE_1);

        address[] memory page = factory.getGardensByTypeRange(GARDEN_TYPE_1, 0, 100);
        assertEq(page.length, 1);
    }

    function test_getGardensByTypeRange_emptyWhenOffsetBeyondTotal() public {
        _createGarden(alice, 1, GARDEN_TYPE_1);

        address[] memory page = factory.getGardensByTypeRange(GARDEN_TYPE_1, 10, 5);
        assertEq(page.length, 0);
    }

    function test_getGardensByTypeRange_emptyForNoGardensOfType() public view {
        address[] memory page = factory.getGardensByTypeRange(GARDEN_TYPE_1, 0, 10);
        assertEq(page.length, 0);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     getUserGardensByType / getUserGardensByTypeCount
    // ═══════════════════════════════════════════════════════════════════

    function test_getUserGardensByType_returnsCorrectGardens() public {
        address g1 = _createGarden(alice, 1, GARDEN_TYPE_1);
        address g2 = _createGarden(alice, 2, GARDEN_TYPE_1);
        _createGarden(alice, 3, GARDEN_TYPE_2);

        address[] memory aliceType1 = factory.getUserGardensByType(alice, GARDEN_TYPE_1);
        assertEq(aliceType1.length, 2);
        assertEq(aliceType1[0], g1);
        assertEq(aliceType1[1], g2);
    }

    function test_getUserGardensByTypeCount_matchesArrayLength() public {
        _createGarden(alice, 1, GARDEN_TYPE_1);
        _createGarden(alice, 2, GARDEN_TYPE_2);
        _createGarden(alice, 3, GARDEN_TYPE_1);

        assertEq(factory.getUserGardensByTypeCount(alice, GARDEN_TYPE_1), 2);
        assertEq(factory.getUserGardensByTypeCount(alice, GARDEN_TYPE_2), 1);
    }

    function test_getUserGardensByType_emptyForWrongUser() public {
        _createGarden(alice, 1, GARDEN_TYPE_1);

        assertEq(factory.getUserGardensByType(bob, GARDEN_TYPE_1).length, 0);
        assertEq(factory.getUserGardensByTypeCount(bob, GARDEN_TYPE_1), 0);
    }

    function test_getUserGardensByType_emptyForWrongType() public {
        _createGarden(alice, 1, GARDEN_TYPE_1);

        assertEq(factory.getUserGardensByType(alice, GARDEN_TYPE_2).length, 0);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     getGardenInfo
    // ═══════════════════════════════════════════════════════════════════

    function test_getGardenInfo_returnsCorrectInfoForRegisteredGarden() public {
        address garden = _createGarden(alice, 1, GARDEN_TYPE_1);

        (address infoOwner, bytes32 infoType, bool registered) = factory.getGardenInfo(garden);
        assertEq(infoOwner, alice);
        assertEq(infoType, GARDEN_TYPE_1);
        assertTrue(registered);
    }

    function test_getGardenInfo_returnsDefaultsForUnknownGarden() public view {
        (address infoOwner, bytes32 infoType, bool registered) = factory.getGardenInfo(address(0xDEAD));
        assertEq(infoOwner, address(0));
        assertEq(infoType, bytes32(0));
        assertFalse(registered);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     getUserGardenInfos
    // ═══════════════════════════════════════════════════════════════════

    function test_getUserGardenInfos_returnsAllGardensWithTypes() public {
        address g1 = _createGarden(alice, 1, GARDEN_TYPE_1);
        address g2 = _createGarden(alice, 2, GARDEN_TYPE_2);
        address g3 = _createGarden(alice, 3, GARDEN_TYPE_1);

        (address[] memory gardens, bytes32[] memory types) = factory.getUserGardenInfos(alice);

        assertEq(gardens.length, 3);
        assertEq(types.length, 3);

        assertEq(gardens[0], g1);
        assertEq(gardens[1], g2);
        assertEq(gardens[2], g3);

        assertEq(types[0], GARDEN_TYPE_1);
        assertEq(types[1], GARDEN_TYPE_2);
        assertEq(types[2], GARDEN_TYPE_1);
    }

    function test_getUserGardenInfos_emptyForUnknownUser() public view {
        (address[] memory gardens, bytes32[] memory types) = factory.getUserGardenInfos(alice);
        assertEq(gardens.length, 0);
        assertEq(types.length, 0);
    }

    function test_getUserGardenInfos_isolatedPerUser() public {
        _createGarden(alice, 1, GARDEN_TYPE_1);
        _createGarden(bob, 1, GARDEN_TYPE_2);

        (address[] memory aliceGardens,) = factory.getUserGardenInfos(alice);
        (address[] memory bobGardens,) = factory.getUserGardenInfos(bob);

        assertEq(aliceGardens.length, 1);
        assertEq(bobGardens.length, 1);
        assertTrue(aliceGardens[0] != bobGardens[0]);
    }
}
