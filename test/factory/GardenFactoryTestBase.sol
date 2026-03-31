// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { DiamondTestBase } from "../base/DiamondTestBase.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";

/// @title GardenFactoryTestBase
/// @notice Shared setup for all GardenFactory tests.
///         Deploys a FacetRegistry (via DiamondTestBase), MockProtocolStatus,
///         registers a default garden type, and deploys the GardenFactory.
abstract contract GardenFactoryTestBase is DiamondTestBase {
    GardenFactory public factory;

    function setUp() public virtual override {
        super.setUp();

        // Register a garden type so createGarden has something valid to use
        _addGardenTypeEmpty(GARDEN_TYPE_1);

        // Register a second garden type for multi-type tests
        _registerModule(MODULE_1);
        _addFacetToModule(MODULE_1, address(stubA), selsStubA);
        bytes32[] memory mods = new bytes32[](1);
        mods[0] = MODULE_1;
        _addGardenType(GARDEN_TYPE_2, mods);

        // Deploy the factory (owned by `owner`)
        factory = new GardenFactory(owner, address(registry), address(protocolStatus));
    }

    // ═══════════════════════════════════════════════════════════════════
    //                         HELPERS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Create a garden via the factory as `caller`
    function _createGarden(address caller, uint256 index, bytes32 gardenType) internal returns (address) {
        vm.prank(caller);
        return factory.createGarden(index, gardenType);
    }

    /// @notice Create a garden with GARDEN_TYPE_1 defaults
    function _createDefaultGarden(address caller, uint256 index) internal returns (address) {
        return _createGarden(caller, index, GARDEN_TYPE_1);
    }

    /// @notice Create multiple gardens for a single user (indices 1..count)
    function _createGardensForUser(address user, uint256 count, bytes32 gardenType) internal returns (address[] memory) {
        address[] memory gardens = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            gardens[i] = _createGarden(user, i + 1, gardenType);
        }
        return gardens;
    }
}
