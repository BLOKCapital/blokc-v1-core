// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { FacetRegistryTestBase } from "../FacetRegistryTestBase.sol";

import {
    FacetRegistry_GardenTypeIdIsZero,
    FacetRegistry_GardenTypeAlreadyExists,
    FacetRegistry_GardenTypeDoesNotExist,
    FacetRegistry_ModuleNotAllowed
} from "src/facetRegistry/FacetRegistry.sol";

contract GardenTypeFuzzTest is FacetRegistryTestBase {
    function setUp() public override {
        super.setUp();
        _registerModule(MODULE_1);
        _registerModule(MODULE_2);
        _registerModule(MODULE_3);
    }

    // ─── addGardenType fuzzing ──────────────────────────────────────────

    function testFuzz_addGardenType_arbitraryId(bytes32 gardenTypeId) public {
        vm.assume(gardenTypeId != bytes32(0));

        bytes32[] memory modules = new bytes32[](1);
        modules[0] = MODULE_1;

        registry.addGardenType(gardenTypeId, modules);
        assertTrue(registry.isGardenTypeRegistered(gardenTypeId));
    }

    function testFuzz_addGardenType_revert_zeroId(bytes32) public {
        bytes32[] memory modules = new bytes32[](0);
        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_GardenTypeIdIsZero.selector));
        registry.addGardenType(bytes32(0), modules);
    }

    function testFuzz_addGardenType_revert_duplicate(bytes32 gardenTypeId) public {
        vm.assume(gardenTypeId != bytes32(0));

        bytes32[] memory modules = new bytes32[](0);
        registry.addGardenType(gardenTypeId, modules);

        vm.expectRevert(
            abi.encodeWithSelector(FacetRegistry_GardenTypeAlreadyExists.selector, gardenTypeId)
        );
        registry.addGardenType(gardenTypeId, modules);
    }

    // ─── addAllowedModule + removeAllowedModule fuzzing ─────────────────

    function testFuzz_addAndRemoveModules_orderPreserved(uint8 numOps) public {
        numOps = uint8(bound(numOps, 1, 20));

        bytes32[] memory empty = new bytes32[](0);
        registry.addGardenType(GARDEN_TYPE_1, empty);

        bytes32[3] memory availableModules = [MODULE_1, MODULE_2, MODULE_3];
        bool[3] memory added;

        for (uint8 i = 0; i < numOps; i++) {
            uint8 moduleIdx = i % 3;
            bytes32 modId = availableModules[moduleIdx];

            if (!added[moduleIdx]) {
                registry.addAllowedModule(GARDEN_TYPE_1, modId);
                added[moduleIdx] = true;
                assertTrue(registry.isModuleAllowedForGardenType(GARDEN_TYPE_1, modId));
            } else {
                registry.removeAllowedModule(GARDEN_TYPE_1, modId);
                added[moduleIdx] = false;
                assertFalse(registry.isModuleAllowedForGardenType(GARDEN_TYPE_1, modId));
            }
        }

        // Verify final state matches
        bytes32[] memory gtModules = registry.getGardenTypeModules(GARDEN_TYPE_1);
        uint256 expectedCount;
        for (uint8 i = 0; i < 3; i++) {
            if (added[i]) expectedCount++;
        }
        assertEq(gtModules.length, expectedCount);
    }

    // ─── BASE_MODULE always allowed ─────────────────────────────────────

    function testFuzz_baseModuleAlwaysAllowed(bytes32 gardenTypeId) public {
        vm.assume(gardenTypeId != bytes32(0));

        bytes32[] memory modules = new bytes32[](0);
        registry.addGardenType(gardenTypeId, modules);

        assertTrue(registry.isModuleAllowedForGardenType(gardenTypeId, BASE_MODULE));
    }

    // ─── removeAllowedModule for non-existent garden type ───────────────

    function testFuzz_removeAllowedModule_revert_nonExistentGardenType(bytes32 gardenTypeId) public {
        vm.assume(gardenTypeId != bytes32(0));
        // Don't register it

        vm.expectRevert(
            abi.encodeWithSelector(FacetRegistry_GardenTypeDoesNotExist.selector, gardenTypeId)
        );
        registry.removeAllowedModule(gardenTypeId, MODULE_1);
    }

    // ─── removeAllowedModule for non-allowed module ─────────────────────

    function testFuzz_removeAllowedModule_revert_notAllowed(bytes32 gardenTypeId) public {
        vm.assume(gardenTypeId != bytes32(0));

        bytes32[] memory modules = new bytes32[](0);
        registry.addGardenType(gardenTypeId, modules);

        vm.expectRevert(
            abi.encodeWithSelector(FacetRegistry_ModuleNotAllowed.selector, gardenTypeId, MODULE_1)
        );
        registry.removeAllowedModule(gardenTypeId, MODULE_1);
    }
}
