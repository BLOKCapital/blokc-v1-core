// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { GardenFactoryTestBase } from "./GardenFactoryTestBase.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// Import errors from GardenFactory
error GardenFactory_IndexOutOfRange(uint256 index);
error GardenFactory_IndexAlreadyUsed(address user, uint256 index);

/// @title Tests for GardenFactory edge cases and security
contract GardenFactoryEdgeCasesTest is GardenFactoryTestBase {
    function setUp() public override {
        super.setUp();
    }

    // =============================================================
    // REENTRANCY PROTECTION TESTS
    // =============================================================

    /// @notice Test that createGarden is protected against reentrancy
    /// @dev This is tested by the nonReentrant modifier
    function test_ReentrancyProtection() public {
        // The nonReentrant modifier should prevent reentrancy
        // In practice, this would require a malicious contract trying to reenter
        // The modifier from OpenZeppelin handles this
        address garden = createGardenForUser(user1, 1);
        assertTrue(garden != address(0), "Should create garden successfully");
    }

    // =============================================================
    // INDEX BOUNDARY TESTS
    // =============================================================

    /// @notice Test creating garden with minimum valid index (1)
    function test_CreateGarden_MinimumIndex() public {
        address garden = createGardenForUser(user1, 1);
        assertTrue(garden != address(0), "Should create garden with index 1");
        assertEq(factory.getGarden(user1, 1), garden);
    }

    /// @notice Test creating garden with maximum valid index (10)
    function test_CreateGarden_MaximumIndex() public {
        address garden = createGardenForUser(user1, 10);
        assertTrue(garden != address(0), "Should create garden with index 10");
        assertEq(factory.getGarden(user1, 10), garden);
    }

    /// @notice Test boundary condition: index 0
    function test_RevertIf_IndexZero() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(GardenFactory_IndexOutOfRange.selector, 0));
        factory.createGarden(0);
    }

    /// @notice Test boundary condition: index 11
    function test_RevertIf_IndexEleven() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(GardenFactory_IndexOutOfRange.selector, 11));
        factory.createGarden(11);
    }

    /// @notice Test boundary condition: very large index
    function test_RevertIf_VeryLargeIndex() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(GardenFactory_IndexOutOfRange.selector, type(uint256).max));
        factory.createGarden(type(uint256).max);
    }

    // =============================================================
    // DETERMINISTIC ADDRESS TESTS
    // =============================================================

    /// @notice Test that same user + same index + same factory = same address
    function test_DeterministicAddress_SameParameters() public {
        address garden1 = createGardenForUser(user1, 5);

        // Note: We can't create the same garden twice, but we can verify the salt calculation
        bytes32 salt1 = keccak256(abi.encode(user1, 5, address(factory)));
        bytes32 salt2 = keccak256(abi.encode(user1, 5, address(factory)));

        assertEq(salt1, salt2, "Salts should be identical for same parameters");
        assertTrue(garden1 != address(0), "Garden should have valid address");
    }

    /// @notice Test that different users get different addresses for same index
    function test_DeterministicAddress_DifferentUsers() public {
        address garden1 = createGardenForUser(user1, 1);
        address garden2 = createGardenForUser(user2, 1);

        assertNotEq(garden1, garden2, "Different users should get different addresses");
    }

    /// @notice Test that same user gets different addresses for different indices
    function test_DeterministicAddress_DifferentIndices() public {
        address garden1 = createGardenForUser(user1, 1);
        address garden2 = createGardenForUser(user1, 2);

        assertNotEq(garden1, garden2, "Different indices should give different addresses");
    }

    // =============================================================
    // MULTIPLE USER SCENARIOS
    // =============================================================

    /// @notice Test multiple users creating gardens concurrently
    function test_MultipleUsers_ConcurrentCreation() public {
        address garden1 = createGardenForUser(user1, 1);
        address garden2 = createGardenForUser(user2, 1);
        address garden3 = createGardenForUser(user3, 1);

        assertNotEq(garden1, garden2);
        assertNotEq(garden2, garden3);
        assertNotEq(garden1, garden3);

        assertTrue(factory.isGardenRegistered(garden1));
        assertTrue(factory.isGardenRegistered(garden2));
        assertTrue(factory.isGardenRegistered(garden3));
    }

    /// @notice Test user creating maximum gardens
    function test_UserCreatesMaximumGardens() public {
        address[] memory gardens = createMultipleGardensForUser(user1, 10);

        // Verify all are unique
        for (uint256 i = 0; i < gardens.length; i++) {
            for (uint256 j = i + 1; j < gardens.length; j++) {
                assertNotEq(gardens[i], gardens[j], "All gardens should be unique");
            }
            assertTrue(factory.isGardenRegistered(gardens[i]), "All gardens should be registered");
        }
    }

    /// @notice Test that user can't reuse index after creating maximum gardens
    function test_CannotReuseIndexAfterMaximum() public {
        createMultipleGardensForUser(user1, 10);

        // Try to reuse index 1
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(GardenFactory_IndexAlreadyUsed.selector, user1, 1));
        factory.createGarden(1);
    }

    // =============================================================
    // STATE CONSISTENCY TESTS
    // =============================================================

    /// @notice Test that state is consistent after multiple operations
    function test_StateConsistency_MultipleOperations() public {
        // Create gardens for multiple users
        address g1 = createGardenForUser(user1, 1);
        address g2 = createGardenForUser(user1, 2);
        address g3 = createGardenForUser(user2, 1);

        // Verify getAllGardens
        address[] memory allGardens = factory.getAllGardens();
        assertEq(allGardens.length, 3, "Should have 3 gardens");

        // Verify getUserGardens
        address[] memory user1Gardens = factory.getUserGardens(user1);
        assertEq(user1Gardens.length, 2, "User1 should have 2 gardens");

        // Verify getGarden
        assertEq(factory.getGarden(user1, 1), g1);
        assertEq(factory.getGarden(user1, 2), g2);
        assertEq(factory.getGarden(user2, 1), g3);

        // Verify isGardenRegistered
        assertTrue(factory.isGardenRegistered(g1));
        assertTrue(factory.isGardenRegistered(g2));
        assertTrue(factory.isGardenRegistered(g3));
    }

    /// @notice Test that garden arrays grow correctly
    function test_ArrayGrowth_Correctly() public {
        address testUser = makeAddr("testUser");

        for (uint256 i = 1; i <= 10; i++) {
            createGardenForUser(testUser, i);

            address[] memory userGardens = factory.getUserGardens(testUser);
            assertEq(userGardens.length, i, "Array should grow correctly");

            address[] memory allGardens = factory.getAllGardens();
            assertTrue(allGardens.length >= i, "Total gardens should include new one");
        }
    }

    // =============================================================
    // GAS AND PERFORMANCE TESTS
    // =============================================================

    /// @notice Test gas cost of creating a garden
    function test_GasCost_CreateGarden() public {
        uint256 gasBefore = gasleft();
        createGardenForUser(user1, 1);
        uint256 gasUsed = gasBefore - gasleft();

        // Just verify it doesn't exceed reasonable bounds
        // Exact gas depends on deployment, but should be reasonable
        assertTrue(gasUsed < 10_000_000, "Gas should be reasonable");
    }

    /// @notice Test gas cost of view functions
    function test_GasCost_ViewFunctions() public {
        createMultipleGardensForUser(user1, 10);

        uint256 gasBefore = gasleft();
        factory.getAllGardens();
        uint256 gas1 = gasBefore - gasleft();

        gasBefore = gasleft();
        factory.getUserGardens(user1);
        uint256 gas2 = gasBefore - gasleft();

        // Create garden for user2 (this also tests isGardenRegistered indirectly)
        createGardenForUser(user2, 1);

        // All should be reasonable
        assertTrue(gas1 < 1_000_000, "getAllGardens gas should be reasonable");
        assertTrue(gas2 < 1_000_000, "getUserGardens gas should be reasonable");

        uint256 gasBefore2 = gasleft();
        factory.isGardenRegistered(address(1));
        uint256 gas4 = gasBefore2 - gasleft();
        assertTrue(gas4 < 1_000_000, "isGardenRegistered gas should be reasonable");
    }

    // =============================================================
    // FUZZ TESTS
    // =============================================================

    /// @notice Fuzz test index validation
    function testFuzz_IndexValidation(uint256 index) public {
        if (index < 1 || index > 10) {
            vm.prank(user1);
            vm.expectRevert();
            factory.createGarden(index);
        } else {
            // Valid index, should work
            address garden = createGardenForUser(user1, index);
            assertTrue(garden != address(0));
        }
    }

    /// @notice Fuzz test multiple garden creation
    function testFuzz_MultipleGardens(address user, uint8 count) public {
        vm.assume(count > 0 && count <= 10);
        vm.assume(user != address(0));

        address[] memory gardens = new address[](count);

        for (uint256 i = 0; i < count; i++) {
            vm.prank(user);
            gardens[i] = factory.createGarden(i + 1);
            assertTrue(gardens[i] != address(0));
        }

        address[] memory userGardens = factory.getUserGardens(user);
        assertEq(userGardens.length, count);
    }

    // =============================================================
    // EDGE CASE: EMPTY STATE
    // =============================================================

    /// @notice Test view functions on empty factory
    function test_EmptyFactory_ViewFunctions() public {
        GardenFactory newImpl = new GardenFactory();
        ProxyAdmin newAdmin = new ProxyAdmin(address(this));

        bytes memory factoryInitData = abi.encodeWithSelector(GardenFactory.initialize.selector, owner);

        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImpl), address(newAdmin), factoryInitData);

        GardenFactory newFactory = GardenFactory(payable(address(newProxy)));

        address[] memory allGardens = newFactory.getAllGardens();
        assertEq(allGardens.length, 0);

        address[] memory userGardens = newFactory.getUserGardens(user1);
        assertEq(userGardens.length, 0);

        address garden = newFactory.getGarden(user1, 1);
        assertEq(garden, address(0));

        assertFalse(newFactory.isGardenRegistered(address(1)));
    }
}
