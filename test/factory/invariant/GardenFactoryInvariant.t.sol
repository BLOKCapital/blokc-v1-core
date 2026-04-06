// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { GardenFactoryTestBase } from "../GardenFactoryTestBase.sol";
import { GardenFactoryHandler } from "./GardenFactoryHandler.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";

contract GardenFactoryInvariantTest is GardenFactoryTestBase {
    GardenFactoryHandler public handler;

    function setUp() public override {
        super.setUp();

        // Build garden type array for the handler
        bytes32[] memory types = new bytes32[](2);
        types[0] = GARDEN_TYPE_1;
        types[1] = GARDEN_TYPE_2;

        handler = new GardenFactoryHandler(factory, types);

        // Focus fuzzer on handler only
        targetContract(address(handler));
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     CORE COUNTING INVARIANTS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice getTotalGardens() must always equal the handler's ghost counter
    function invariant_totalGardensMatchesGhost() public view {
        assertEq(factory.getTotalGardens(), handler.ghost_totalGardens());
    }

    /// @notice getAllGardens().length must equal getTotalGardens()
    function invariant_allGardensLengthMatchesTotal() public view {
        assertEq(factory.getAllGardens().length, factory.getTotalGardens());
    }

    /// @notice ghost_allGardens length must match getTotalGardens()
    function invariant_ghostArrayLengthMatchesTotal() public view {
        assertEq(handler.ghost_allGardensLength(), factory.getTotalGardens());
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     PER-USER INVARIANTS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Each actor's getUserGardenCount must match ghost state
    function invariant_userGardenCountMatchesGhost() public view {
        address[] memory actors = handler.getActors();
        for (uint256 i = 0; i < actors.length; i++) {
            assertEq(factory.getUserGardenCount(actors[i]), handler.ghost_userGardenCount(actors[i]));
        }
    }

    /// @notice For every actor, available + used indices must always equal 10
    function invariant_availablePlusUsedAlwaysTen() public view {
        address[] memory actors = handler.getActors();
        for (uint256 i = 0; i < actors.length; i++) {
            uint256[] memory available = factory.getUserAvailableIndices(actors[i]);
            uint256[] memory used = factory.getUserUsedIndices(actors[i]);
            assertEq(available.length + used.length, 10);
        }
    }

    /// @notice getUserGardens().length must equal getUserGardenCount() for every actor
    function invariant_userGardensArrayMatchesCount() public view {
        address[] memory actors = handler.getActors();
        for (uint256 i = 0; i < actors.length; i++) {
            assertEq(factory.getUserGardens(actors[i]).length, factory.getUserGardenCount(actors[i]));
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     REGISTRATION INVARIANTS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Every garden in ghost_allGardens must be registered
    function invariant_allCreatedGardensAreRegistered() public view {
        uint256 len = handler.ghost_allGardensLength();
        for (uint256 i = 0; i < len; i++) {
            assertTrue(factory.isGardenRegistered(handler.ghost_allGardensAt(i)));
        }
    }

    /// @notice Every registered garden must have a non-zero owner
    function invariant_registeredGardensHaveOwner() public view {
        uint256 len = handler.ghost_allGardensLength();
        for (uint256 i = 0; i < len; i++) {
            address garden = handler.ghost_allGardensAt(i);
            assertTrue(factory.getGardenOwner(garden) != address(0));
        }
    }

    /// @notice Every registered garden must have a non-zero garden type
    function invariant_registeredGardensHaveType() public view {
        uint256 len = handler.ghost_allGardensLength();
        for (uint256 i = 0; i < len; i++) {
            address garden = handler.ghost_allGardensAt(i);
            assertTrue(factory.getGardenType(garden) != bytes32(0));
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     TYPE COUNTING INVARIANTS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Per-type garden count must match ghost state
    function invariant_typeCountMatchesGhost() public view {
        bytes32[] memory types = handler.getGardenTypes();
        for (uint256 i = 0; i < types.length; i++) {
            assertEq(factory.getGardensByTypeCount(types[i]), handler.ghost_typeCount(types[i]));
        }
    }

    /// @notice Sum of all type counts must equal total gardens
    function invariant_typeCountsSumToTotal() public view {
        bytes32[] memory types = handler.getGardenTypes();
        uint256 sum;
        for (uint256 i = 0; i < types.length; i++) {
            sum += factory.getGardensByTypeCount(types[i]);
        }
        assertEq(sum, factory.getTotalGardens());
    }

    /// @notice Per-user per-type count must match ghost state
    function invariant_userTypeCountMatchesGhost() public view {
        address[] memory actors = handler.getActors();
        bytes32[] memory types = handler.getGardenTypes();
        for (uint256 i = 0; i < actors.length; i++) {
            for (uint256 j = 0; j < types.length; j++) {
                assertEq(
                    factory.getUserGardensByTypeCount(actors[i], types[j]),
                    handler.ghost_userTypeCount(actors[i], types[j])
                );
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     DIAMOND OWNERSHIP INVARIANT
    // ═══════════════════════════════════════════════════════════════════

    /// @notice The Diamond's owner (ERC-173) must match the factory's recorded owner
    function invariant_diamondOwnerMatchesFactoryOwner() public view {
        uint256 len = handler.ghost_allGardensLength();
        for (uint256 i = 0; i < len; i++) {
            address garden = handler.ghost_allGardensAt(i);
            assertEq(IERC173(garden).owner(), factory.getGardenOwner(garden));
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     INDEX UNIQUENESS INVARIANT
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Each used index should map to a registered, unique garden per user
    function invariant_usedIndicesMapToUniqueGardens() public view {
        address[] memory actors = handler.getActors();
        for (uint256 a = 0; a < actors.length; a++) {
            uint256[] memory used = factory.getUserUsedIndices(actors[a]);
            for (uint256 i = 0; i < used.length; i++) {
                address garden = factory.getGarden(actors[a], used[i]);
                assertTrue(garden != address(0));
                assertTrue(factory.isGardenRegistered(garden));

                // No other used index for this user points to the same garden
                for (uint256 j = i + 1; j < used.length; j++) {
                    assertTrue(factory.getGarden(actors[a], used[j]) != garden);
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     getGardenInfo CONSISTENCY
    // ═══════════════════════════════════════════════════════════════════

    /// @notice getGardenInfo must be consistent with individual getters for all gardens
    function invariant_gardenInfoConsistent() public view {
        uint256 len = handler.ghost_allGardensLength();
        for (uint256 i = 0; i < len; i++) {
            address garden = handler.ghost_allGardensAt(i);
            (address infoOwner, bytes32 infoType, bool registered) = factory.getGardenInfo(garden);

            assertEq(infoOwner, factory.getGardenOwner(garden));
            assertEq(infoType, factory.getGardenType(garden));
            assertEq(registered, factory.isGardenRegistered(garden));
        }
    }
}
