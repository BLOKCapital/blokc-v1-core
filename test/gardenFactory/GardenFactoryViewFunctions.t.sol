// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { GardenFactoryTestBase } from "./GardenFactoryTestBase.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Tests for GardenFactory view functions
contract GardenFactoryViewFunctionsTest is GardenFactoryTestBase {
    function setUp() public override {
        super.setUp();

        // Create some test gardens
        createGardenForUser(user1, 1);
        createGardenForUser(user1, 2);
        createGardenForUser(user2, 1);
        createGardenForUser(user2, 3);
        createGardenForUser(user3, 1);
    }

    // =============================================================
    // getAllGardens TESTS
    // =============================================================

    /// @notice Test getAllGardens returns all gardens
    function test_GetAllGardens_ReturnsAllGardens() public {
        address[] memory allGardens = factory.getAllGardens();
        assertEq(allGardens.length, 5, "Should have 5 gardens");
    }

    /// @notice Test getAllGardens returns empty array when no gardens
    function test_GetAllGardens_ReturnsEmptyWhenNoGardens() public {
        // Create new factory without gardens
        GardenFactory newImpl = new GardenFactory();
        ProxyAdmin newAdmin = new ProxyAdmin(address(this));

        bytes memory factoryInitData = abi.encodeWithSelector(GardenFactory.initialize.selector, owner);

        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImpl), address(newAdmin), factoryInitData);

        GardenFactory newFactory = GardenFactory(payable(address(newProxy)));

        address[] memory allGardens = newFactory.getAllGardens();
        assertEq(allGardens.length, 0, "Should return empty array");
    }

    /// @notice Test getAllGardens returns correct gardens after multiple creations
    function test_GetAllGardens_UpdatesCorrectly() public {
        address[] memory before = factory.getAllGardens();
        uint256 beforeLength = before.length;

        address newGarden = createGardenForUser(user3, 2);

        address[] memory allGardensAfter = factory.getAllGardens();
        assertEq(allGardensAfter.length, beforeLength + 1, "Should have one more garden");

        bool found = false;
        for (uint256 i = 0; i < allGardensAfter.length; i++) {
            if (allGardensAfter[i] == newGarden) {
                found = true;
                break;
            }
        }
        assertTrue(found, "New garden should be in getAllGardens");
    }

    // =============================================================
    // getUserGardens TESTS
    // =============================================================

    /// @notice Test getUserGardens returns correct gardens for user
    function test_GetUserGardens_ReturnsUserGardens() public {
        address[] memory user1Gardens = factory.getUserGardens(user1);
        assertEq(user1Gardens.length, 2, "User1 should have 2 gardens");

        address[] memory user2Gardens = factory.getUserGardens(user2);
        assertEq(user2Gardens.length, 2, "User2 should have 2 gardens");

        address[] memory user3Gardens = factory.getUserGardens(user3);
        assertEq(user3Gardens.length, 1, "User3 should have 1 garden");
    }

    /// @notice Test getUserGardens returns empty array for user with no gardens
    function test_GetUserGardens_ReturnsEmptyForNoGardens() public {
        address newUser = makeAddr("newUser");
        address[] memory gardens = factory.getUserGardens(newUser);
        assertEq(gardens.length, 0, "Should return empty array");
    }

    /// @notice Test getUserGardens updates correctly as gardens are created
    function test_GetUserGardens_UpdatesCorrectly() public {
        address[] memory before = factory.getUserGardens(user1);
        assertEq(before.length, 2, "Should start with 2 gardens");

        address newGarden = createGardenForUser(user1, 3);

        address[] memory afterCreation = factory.getUserGardens(user1);
        assertEq(afterCreation.length, 3, "Should have 3 gardens now");
        assertEq(afterCreation[2], newGarden, "Last garden should be the new one");
    }

    /// @notice Test getUserGardens returns gardens in creation order
    function test_GetUserGardens_ReturnsInCreationOrder() public {
        // Clear and recreate for predictable order
        address testUser = makeAddr("testUser");

        address garden1 = createGardenForUser(testUser, 1);
        address garden2 = createGardenForUser(testUser, 2);
        address garden3 = createGardenForUser(testUser, 3);

        address[] memory gardens = factory.getUserGardens(testUser);
        assertEq(gardens[0], garden1, "First garden should match");
        assertEq(gardens[1], garden2, "Second garden should match");
        assertEq(gardens[2], garden3, "Third garden should match");
    }

    // =============================================================
    // getGarden TESTS
    // =============================================================

    /// @notice Test getGarden returns correct garden for user and index
    function test_GetGarden_ReturnsCorrectGarden() public {
        address[] memory user1Gardens = factory.getUserGardens(user1);
        address gardenAtIndex1 = factory.getGarden(user1, 1);
        address gardenAtIndex2 = factory.getGarden(user1, 2);

        // Verify they match the user's gardens
        assertTrue(
            gardenAtIndex1 == user1Gardens[0] || gardenAtIndex1 == user1Gardens[1],
            "Garden at index 1 should be in user's gardens"
        );
        assertTrue(
            gardenAtIndex2 == user1Gardens[0] || gardenAtIndex2 == user1Gardens[1],
            "Garden at index 2 should be in user's gardens"
        );
    }

    /// @notice Test getGarden returns zero address for unused index
    function test_GetGarden_ReturnsZeroForUnusedIndex() public {
        address garden = factory.getGarden(user1, 5);
        assertEq(garden, address(0), "Should return zero address");
    }

    /// @notice Test getGarden returns zero address for non-existent user
    function test_GetGarden_ReturnsZeroForNonExistentUser() public {
        address newUser = makeAddr("newUser");
        address garden = factory.getGarden(newUser, 1);
        assertEq(garden, address(0), "Should return zero address");
    }

    /// @notice Test getGarden is consistent with getUserGardens
    function test_GetGarden_ConsistentWithGetUserGardens() public {
        address[] memory user1Gardens = factory.getUserGardens(user1);

        // Check that getGarden returns gardens that are in getUserGardens
        address garden1 = factory.getGarden(user1, 1);
        address garden2 = factory.getGarden(user1, 2);

        bool found1 = false;
        bool found2 = false;

        for (uint256 i = 0; i < user1Gardens.length; i++) {
            if (user1Gardens[i] == garden1) found1 = true;
            if (user1Gardens[i] == garden2) found2 = true;
        }

        assertTrue(found1, "Garden at index 1 should be in getUserGardens");
        assertTrue(found2, "Garden at index 2 should be in getUserGardens");
    }

    // =============================================================
    // isGardenRegistered TESTS
    // =============================================================

    /// @notice Test isGardenRegistered returns true for registered garden
    function test_IsGardenRegistered_ReturnsTrueForRegistered() public {
        address[] memory allGardens = factory.getAllGardens();

        for (uint256 i = 0; i < allGardens.length; i++) {
            assertTrue(factory.isGardenRegistered(allGardens[i]), "All gardens should be registered");
        }
    }

    /// @notice Test isGardenRegistered returns false for unregistered address
    function test_IsGardenRegistered_ReturnsFalseForUnregistered() public {
        address fakeGarden = makeAddr("fakeGarden");
        assertFalse(factory.isGardenRegistered(fakeGarden), "Unregistered garden should return false");
    }

    /// @notice Test isGardenRegistered returns false for zero address
    function test_IsGardenRegistered_ReturnsFalseForZeroAddress() public {
        assertFalse(factory.isGardenRegistered(address(0)), "Zero address should return false");
    }

    /// @notice Test isGardenRegistered updates correctly after creation
    function test_IsGardenRegistered_UpdatesAfterCreation() public {
        address newGarden = createGardenForUser(user3, 2);

        assertTrue(factory.isGardenRegistered(newGarden), "Newly created garden should be registered");
    }

    // =============================================================
    // FUZZ TESTS
    // =============================================================

    /// @notice Fuzz test getGarden with various indices
    function testFuzz_GetGarden_VariousIndices(address user, uint256 index) public {
        // Bound index to valid range for this test
        index = bound(index, 1, 10);

        // If user has no garden at this index, should return zero
        // If user has garden at this index, should return that garden
        address garden = factory.getGarden(user, index);

        if (garden != address(0)) {
            assertTrue(factory.isGardenRegistered(garden), "If garden is returned, it should be registered");

            address[] memory userGardens = factory.getUserGardens(user);
            bool found = false;
            for (uint256 i = 0; i < userGardens.length; i++) {
                if (userGardens[i] == garden) {
                    found = true;
                    break;
                }
            }
            assertTrue(found, "Returned garden should be in user's gardens");
        }
    }

    /// @notice Fuzz test isGardenRegistered with various addresses
    function testFuzz_IsGardenRegistered_VariousAddresses(address gardenAddress) public {
        bool isRegistered = factory.isGardenRegistered(gardenAddress);

        if (isRegistered) {
            // If registered, should be in getAllGardens
            address[] memory allGardens = factory.getAllGardens();
            bool found = false;
            for (uint256 i = 0; i < allGardens.length; i++) {
                if (allGardens[i] == gardenAddress) {
                    found = true;
                    break;
                }
            }
            assertTrue(found, "Registered garden should be in getAllGardens");
        }
    }
}
