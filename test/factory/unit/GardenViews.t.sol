// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { GardenFactoryTestBase } from "../GardenFactoryTestBase.sol";

contract GardenFactoryViewsTest is GardenFactoryTestBase {
    // ═══════════════════════════════════════════════════════════════════
    //                     EMPTY STATE
    // ═══════════════════════════════════════════════════════════════════

    function test_getAllGardens_emptyWhenNoGardens() public view {
        assertEq(factory.getAllGardens().length, 0);
    }

    function test_getUserGardens_emptyForUnknownUser() public view {
        assertEq(factory.getUserGardens(alice).length, 0);
    }

    function test_getGarden_returnsZeroForUnusedIndex() public view {
        assertEq(factory.getGarden(alice, 1), address(0));
    }

    function test_isGardenRegistered_falseForRandomAddress() public view {
        assertFalse(factory.isGardenRegistered(address(0xDEAD)));
    }

    function test_getTotalGardens_zeroInitially() public view {
        assertEq(factory.getTotalGardens(), 0);
    }

    function test_getUserGardenCount_zeroForUnknownUser() public view {
        assertEq(factory.getUserGardenCount(alice), 0);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     getAllGardens
    // ═══════════════════════════════════════════════════════════════════

    function test_getAllGardens_returnsAllCreatedGardens() public {
        address g1 = _createDefaultGarden(alice, 1);
        address g2 = _createDefaultGarden(bob, 1);
        address g3 = _createDefaultGarden(alice, 2);

        address[] memory all = factory.getAllGardens();
        assertEq(all.length, 3);

        // Verify all gardens are in the set (order may vary with EnumerableSet)
        bool foundG1;
        bool foundG2;
        bool foundG3;
        for (uint256 i = 0; i < all.length; i++) {
            if (all[i] == g1) foundG1 = true;
            if (all[i] == g2) foundG2 = true;
            if (all[i] == g3) foundG3 = true;
        }
        assertTrue(foundG1 && foundG2 && foundG3);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     getUserGardens / getUserGardenCount
    // ═══════════════════════════════════════════════════════════════════

    function test_getUserGardens_returnsGardensInOrder() public {
        address g1 = _createDefaultGarden(alice, 1);
        address g2 = _createDefaultGarden(alice, 5);

        address[] memory gardens = factory.getUserGardens(alice);
        assertEq(gardens.length, 2);
        assertEq(gardens[0], g1);
        assertEq(gardens[1], g2);
    }

    function test_getUserGardenCount_matchesArrayLength() public {
        _createDefaultGarden(alice, 1);
        _createDefaultGarden(alice, 2);
        _createDefaultGarden(alice, 3);

        assertEq(factory.getUserGardenCount(alice), 3);
        assertEq(factory.getUserGardens(alice).length, 3);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     getGarden (index lookup)
    // ═══════════════════════════════════════════════════════════════════

    function test_getGarden_correctMappingPerUser() public {
        address gAlice1 = _createDefaultGarden(alice, 1);
        address gAlice5 = _createDefaultGarden(alice, 5);
        address gBob1 = _createDefaultGarden(bob, 1);

        assertEq(factory.getGarden(alice, 1), gAlice1);
        assertEq(factory.getGarden(alice, 5), gAlice5);
        assertEq(factory.getGarden(bob, 1), gBob1);

        // Unused indices return zero
        assertEq(factory.getGarden(alice, 2), address(0));
        assertEq(factory.getGarden(bob, 2), address(0));
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     isIndexAvailable
    // ═══════════════════════════════════════════════════════════════════

    function test_isIndexAvailable_trueForUnusedIndex() public view {
        assertTrue(factory.isIndexAvailable(alice, 1));
        assertTrue(factory.isIndexAvailable(alice, 10));
    }

    function test_isIndexAvailable_falseForUsedIndex() public {
        _createDefaultGarden(alice, 3);
        assertFalse(factory.isIndexAvailable(alice, 3));
    }

    function test_isIndexAvailable_falseForOutOfRange() public view {
        assertFalse(factory.isIndexAvailable(alice, 0));
        assertFalse(factory.isIndexAvailable(alice, 11));
        assertFalse(factory.isIndexAvailable(alice, 100));
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     getUserAvailableIndices
    // ═══════════════════════════════════════════════════════════════════

    function test_getUserAvailableIndices_allTenWhenNoGardens() public view {
        uint256[] memory available = factory.getUserAvailableIndices(alice);
        assertEq(available.length, 10);
        for (uint256 i = 0; i < 10; i++) {
            assertEq(available[i], i + 1);
        }
    }

    function test_getUserAvailableIndices_decreasesAfterCreation() public {
        _createDefaultGarden(alice, 3);
        _createDefaultGarden(alice, 7);

        uint256[] memory available = factory.getUserAvailableIndices(alice);
        assertEq(available.length, 8);

        // Verify 3 and 7 are not in the available list
        for (uint256 i = 0; i < available.length; i++) {
            assertTrue(available[i] != 3);
            assertTrue(available[i] != 7);
        }
    }

    function test_getUserAvailableIndices_emptyWhenAllUsed() public {
        for (uint256 i = 1; i <= 10; i++) {
            _createDefaultGarden(alice, i);
        }
        uint256[] memory available = factory.getUserAvailableIndices(alice);
        assertEq(available.length, 0);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     getUserUsedIndices
    // ═══════════════════════════════════════════════════════════════════

    function test_getUserUsedIndices_emptyWhenNoGardens() public view {
        uint256[] memory used = factory.getUserUsedIndices(alice);
        assertEq(used.length, 0);
    }

    function test_getUserUsedIndices_tracksUsedIndices() public {
        _createDefaultGarden(alice, 2);
        _createDefaultGarden(alice, 8);

        uint256[] memory used = factory.getUserUsedIndices(alice);
        assertEq(used.length, 2);
        assertEq(used[0], 2);
        assertEq(used[1], 8);
    }

    function test_getUserUsedIndices_allTenWhenFull() public {
        for (uint256 i = 1; i <= 10; i++) {
            _createDefaultGarden(alice, i);
        }
        uint256[] memory used = factory.getUserUsedIndices(alice);
        assertEq(used.length, 10);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     getGardensByRange (pagination)
    // ═══════════════════════════════════════════════════════════════════

    function test_getGardensByRange_returnsCorrectSubset() public {
        // Create 5 gardens
        address[] memory created = new address[](5);
        for (uint256 i = 0; i < 5; i++) {
            created[i] = _createDefaultGarden(alice, i + 1);
        }

        // Fetch middle page
        address[] memory page = factory.getGardensByRange(1, 3);
        assertEq(page.length, 3);
    }

    function test_getGardensByRange_clampsToTotal() public {
        _createDefaultGarden(alice, 1);
        _createDefaultGarden(alice, 2);

        // Request more than available
        address[] memory page = factory.getGardensByRange(0, 100);
        assertEq(page.length, 2);
    }

    function test_getGardensByRange_emptyWhenOffsetBeyondTotal() public {
        _createDefaultGarden(alice, 1);

        address[] memory page = factory.getGardensByRange(5, 10);
        assertEq(page.length, 0);
    }

    function test_getGardensByRange_emptyWhenNoGardens() public view {
        address[] memory page = factory.getGardensByRange(0, 10);
        assertEq(page.length, 0);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     REGISTRY GETTERS
    // ═══════════════════════════════════════════════════════════════════

    function test_getFacetRegistry_returnsCorrectAddress() public view {
        assertEq(factory.getFacetRegistry(), address(registry));
    }

    function test_getProtocolStatus_returnsCorrectAddress() public view {
        assertEq(factory.getProtocolStatus(), address(protocolStatus));
    }
}
