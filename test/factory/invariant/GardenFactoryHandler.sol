// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Test } from "forge-std/Test.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";

/// @title GardenFactoryHandler
/// @notice Fuzzer handler for GardenFactory invariant tests.
///         Performs bounded random actions and tracks ghost state so the
///         invariant test can assert global properties.
contract GardenFactoryHandler is Test {
    GardenFactory public factory;

    // ── Bounded actor pool
    // ──────────────────────────────────────────
    address[] public actors;
    uint256 public constant NUM_ACTORS = 5;

    // ── Allowed garden types
    // ────────────────────────────────────────
    bytes32[] public gardenTypes;

    // ── Ghost state — mirrors what the contract should have ─────────
    /// @notice Total gardens created (should match factory.getTotalGardens())
    uint256 public ghost_totalGardens;

    /// @notice Per-user garden count (should match factory.getUserGardenCount())
    mapping(address => uint256) public ghost_userGardenCount;

    /// @notice Per-user per-index occupancy (tracks which indices are taken)
    mapping(address => mapping(uint256 => bool)) public ghost_indexUsed;

    /// @notice Per-type garden count
    mapping(bytes32 => uint256) public ghost_typeCount;

    /// @notice All gardens ever created (for enumeration in invariants)
    address[] public ghost_allGardens;

    /// @notice Per-user per-type count
    mapping(address => mapping(bytes32 => uint256)) public ghost_userTypeCount;

    /// @notice Number of successful createGarden calls (for metrics)
    uint256 public ghost_createCalls;

    /// @notice Number of reverted createGarden calls (for metrics)
    uint256 public ghost_revertedCalls;

    constructor(GardenFactory factory_, bytes32[] memory gardenTypes_) {
        factory = factory_;
        gardenTypes = gardenTypes_;

        // Build actor pool with deterministic addresses
        for (uint256 i = 0; i < NUM_ACTORS; i++) {
            actors.push(address(uint160(0x1000 + i)));
            vm.deal(actors[i], 10 ether);
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     HANDLER ACTIONS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Create a garden with bounded random parameters
    function createGarden(uint256 actorSeed, uint256 indexSeed, uint256 typeSeed) external {
        address actor = actors[actorSeed % actors.length];
        uint256 index = bound(indexSeed, 1, 10);
        bytes32 gardenType = gardenTypes[typeSeed % gardenTypes.length];

        // Skip if this index is already used (avoid known revert)
        if (ghost_indexUsed[actor][index]) {
            ghost_revertedCalls++;
            return;
        }

        vm.prank(actor);
        address garden = factory.createGarden(index, gardenType);

        // Update ghost state
        ghost_totalGardens++;
        ghost_userGardenCount[actor]++;
        ghost_indexUsed[actor][index] = true;
        ghost_typeCount[gardenType]++;
        ghost_userTypeCount[actor][gardenType]++;
        ghost_allGardens.push(garden);
        ghost_createCalls++;
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     GHOST ACCESSORS
    // ═══════════════════════════════════════════════════════════════════

    function ghost_allGardensLength() external view returns (uint256) {
        return ghost_allGardens.length;
    }

    function ghost_allGardensAt(uint256 i) external view returns (address) {
        return ghost_allGardens[i];
    }

    function getActors() external view returns (address[] memory) {
        return actors;
    }

    function getGardenTypes() external view returns (bytes32[] memory) {
        return gardenTypes;
    }
}
