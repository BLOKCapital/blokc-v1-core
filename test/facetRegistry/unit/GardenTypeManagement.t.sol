// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { FacetRegistryTestBase } from "../FacetRegistryTestBase.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import {
    FacetRegistry_GardenTypeIdIsZero,
    FacetRegistry_GardenTypeAlreadyExists,
    FacetRegistry_GardenTypeDoesNotExist,
    FacetRegistry_CannotAddBaseModule,
    FacetRegistry_ModuleDoesNotExist,
    FacetRegistry_ModuleAlreadyAllowed,
    FacetRegistry_ModuleNotAllowed
} from "src/facetRegistry/FacetRegistry.sol";

contract GardenTypeManagementTest is FacetRegistryTestBase {
    function setUp() public override {
        super.setUp();
        _registerModule(MODULE_1);
        _registerModule(MODULE_2);
        _registerModule(MODULE_3);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                          addGardenType
    // ═══════════════════════════════════════════════════════════════════════

    // ─── Success Cases ──────────────────────────────────────────────────

    function test_addGardenType_withModules() public {
        bytes32[] memory modules = new bytes32[](2);
        modules[0] = MODULE_1;
        modules[1] = MODULE_2;

        _addGardenType(GARDEN_TYPE_1, modules);

        assertTrue(registry.isGardenTypeRegistered(GARDEN_TYPE_1));
        bytes32[] memory gtModules = registry.getGardenTypeModules(GARDEN_TYPE_1);
        assertEq(gtModules.length, 2);
        assertEq(gtModules[0], MODULE_1);
        assertEq(gtModules[1], MODULE_2);
    }

    function test_addGardenType_empty() public {
        _addGardenTypeEmpty(GARDEN_TYPE_1);

        assertTrue(registry.isGardenTypeRegistered(GARDEN_TYPE_1));
        bytes32[] memory gtModules = registry.getGardenTypeModules(GARDEN_TYPE_1);
        assertEq(gtModules.length, 0);
    }

    function test_addGardenType_addsToGardenTypeIds() public {
        _addGardenTypeEmpty(GARDEN_TYPE_1);
        _addGardenTypeEmpty(GARDEN_TYPE_2);

        bytes32[] memory allIds = registry.getAllGardenTypeIds();
        assertEq(allIds.length, 2);
        assertEq(allIds[0], GARDEN_TYPE_1);
        assertEq(allIds[1], GARDEN_TYPE_2);
    }

    function test_addGardenType_emitsEvent() public {
        bytes32[] memory modules = new bytes32[](1);
        modules[0] = MODULE_1;

        vm.expectEmit(true, false, false, true);
        emit GardenTypeAdded(GARDEN_TYPE_1, modules);
        registry.addGardenType(GARDEN_TYPE_1, modules);
    }

    function test_addGardenType_baseModuleImplicitlyAllowed() public {
        _addGardenTypeEmpty(GARDEN_TYPE_1);

        assertTrue(registry.isModuleAllowedForGardenType(GARDEN_TYPE_1, BASE_MODULE));
    }

    // ─── Revert Cases ───────────────────────────────────────────────────

    function test_addGardenType_revert_zeroId() public {
        bytes32[] memory modules = new bytes32[](0);

        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_GardenTypeIdIsZero.selector));
        registry.addGardenType(bytes32(0), modules);
    }

    function test_addGardenType_revert_alreadyExists() public {
        _addGardenTypeEmpty(GARDEN_TYPE_1);

        vm.expectRevert(
            abi.encodeWithSelector(FacetRegistry_GardenTypeAlreadyExists.selector, GARDEN_TYPE_1)
        );
        _addGardenTypeEmpty(GARDEN_TYPE_1);
    }

    function test_addGardenType_revert_baseModuleInAllowed() public {
        bytes32[] memory modules = new bytes32[](1);
        modules[0] = BASE_MODULE;

        vm.expectRevert(
            abi.encodeWithSelector(FacetRegistry_CannotAddBaseModule.selector, GARDEN_TYPE_1)
        );
        registry.addGardenType(GARDEN_TYPE_1, modules);
    }

    function test_addGardenType_revert_moduleDoesNotExist() public {
        bytes32 nonExistent = keccak256("NONEXISTENT");
        bytes32[] memory modules = new bytes32[](1);
        modules[0] = nonExistent;

        vm.expectRevert(
            abi.encodeWithSelector(FacetRegistry_ModuleDoesNotExist.selector, nonExistent)
        );
        registry.addGardenType(GARDEN_TYPE_1, modules);
    }

    function test_addGardenType_revert_duplicateModuleInAllowed() public {
        bytes32[] memory modules = new bytes32[](2);
        modules[0] = MODULE_1;
        modules[1] = MODULE_1;

        vm.expectRevert(
            abi.encodeWithSelector(FacetRegistry_ModuleAlreadyAllowed.selector, GARDEN_TYPE_1, MODULE_1)
        );
        registry.addGardenType(GARDEN_TYPE_1, modules);
    }

    function test_addGardenType_revert_nonOwner() public {
        bytes32[] memory modules = new bytes32[](0);

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        registry.addGardenType(GARDEN_TYPE_1, modules);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                        addAllowedModule
    // ═══════════════════════════════════════════════════════════════════════

    // ─── Success Cases ──────────────────────────────────────────────────

    function test_addAllowedModule_success() public {
        _addGardenTypeEmpty(GARDEN_TYPE_1);

        registry.addAllowedModule(GARDEN_TYPE_1, MODULE_1);

        bytes32[] memory gtModules = registry.getGardenTypeModules(GARDEN_TYPE_1);
        assertEq(gtModules.length, 1);
        assertEq(gtModules[0], MODULE_1);
        assertTrue(registry.isModuleAllowedForGardenType(GARDEN_TYPE_1, MODULE_1));
    }

    function test_addAllowedModule_multipleModules() public {
        _addGardenTypeEmpty(GARDEN_TYPE_1);

        registry.addAllowedModule(GARDEN_TYPE_1, MODULE_1);
        registry.addAllowedModule(GARDEN_TYPE_1, MODULE_2);
        registry.addAllowedModule(GARDEN_TYPE_1, MODULE_3);

        bytes32[] memory gtModules = registry.getGardenTypeModules(GARDEN_TYPE_1);
        assertEq(gtModules.length, 3);
    }

    function test_addAllowedModule_emitsEvent() public {
        _addGardenTypeEmpty(GARDEN_TYPE_1);

        vm.expectEmit(true, true, false, false);
        emit AllowedModuleAdded(GARDEN_TYPE_1, MODULE_1);
        registry.addAllowedModule(GARDEN_TYPE_1, MODULE_1);
    }

    // ─── Revert Cases ───────────────────────────────────────────────────

    function test_addAllowedModule_revert_gardenTypeDoesNotExist() public {
        vm.expectRevert(
            abi.encodeWithSelector(FacetRegistry_GardenTypeDoesNotExist.selector, GARDEN_TYPE_1)
        );
        registry.addAllowedModule(GARDEN_TYPE_1, MODULE_1);
    }

    function test_addAllowedModule_revert_baseModule() public {
        _addGardenTypeEmpty(GARDEN_TYPE_1);

        vm.expectRevert(
            abi.encodeWithSelector(FacetRegistry_CannotAddBaseModule.selector, GARDEN_TYPE_1)
        );
        registry.addAllowedModule(GARDEN_TYPE_1, BASE_MODULE);
    }

    function test_addAllowedModule_revert_moduleDoesNotExist() public {
        _addGardenTypeEmpty(GARDEN_TYPE_1);
        bytes32 nonExistent = keccak256("NONEXISTENT");

        vm.expectRevert(
            abi.encodeWithSelector(FacetRegistry_ModuleDoesNotExist.selector, nonExistent)
        );
        registry.addAllowedModule(GARDEN_TYPE_1, nonExistent);
    }

    function test_addAllowedModule_revert_alreadyAllowed() public {
        _addGardenTypeEmpty(GARDEN_TYPE_1);
        registry.addAllowedModule(GARDEN_TYPE_1, MODULE_1);

        vm.expectRevert(
            abi.encodeWithSelector(FacetRegistry_ModuleAlreadyAllowed.selector, GARDEN_TYPE_1, MODULE_1)
        );
        registry.addAllowedModule(GARDEN_TYPE_1, MODULE_1);
    }

    function test_addAllowedModule_revert_nonOwner() public {
        _addGardenTypeEmpty(GARDEN_TYPE_1);

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        registry.addAllowedModule(GARDEN_TYPE_1, MODULE_1);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                       removeAllowedModule
    // ═══════════════════════════════════════════════════════════════════════

    // ─── Success Cases ──────────────────────────────────────────────────

    function test_removeAllowedModule_success() public {
        bytes32[] memory modules = new bytes32[](2);
        modules[0] = MODULE_1;
        modules[1] = MODULE_2;
        _addGardenType(GARDEN_TYPE_1, modules);

        registry.removeAllowedModule(GARDEN_TYPE_1, MODULE_1);

        assertFalse(registry.isModuleAllowedForGardenType(GARDEN_TYPE_1, MODULE_1));
        assertTrue(registry.isModuleAllowedForGardenType(GARDEN_TYPE_1, MODULE_2));

        bytes32[] memory gtModules = registry.getGardenTypeModules(GARDEN_TYPE_1);
        assertEq(gtModules.length, 1);
    }

    function test_removeAllowedModule_lastModule() public {
        bytes32[] memory modules = new bytes32[](1);
        modules[0] = MODULE_1;
        _addGardenType(GARDEN_TYPE_1, modules);

        registry.removeAllowedModule(GARDEN_TYPE_1, MODULE_1);

        bytes32[] memory gtModules = registry.getGardenTypeModules(GARDEN_TYPE_1);
        assertEq(gtModules.length, 0);
        // Garden type still exists
        assertTrue(registry.isGardenTypeRegistered(GARDEN_TYPE_1));
    }

    function test_removeAllowedModule_swapAndPop_removesFirstElement() public {
        bytes32[] memory modules = new bytes32[](3);
        modules[0] = MODULE_1;
        modules[1] = MODULE_2;
        modules[2] = MODULE_3;
        _addGardenType(GARDEN_TYPE_1, modules);

        // Remove first element (MODULE_1) - MODULE_3 should swap in
        registry.removeAllowedModule(GARDEN_TYPE_1, MODULE_1);

        bytes32[] memory gtModules = registry.getGardenTypeModules(GARDEN_TYPE_1);
        assertEq(gtModules.length, 2);
        // MODULE_3 swapped to position 0
        assertEq(gtModules[0], MODULE_3);
        assertEq(gtModules[1], MODULE_2);
    }

    function test_removeAllowedModule_swapAndPop_removesMiddleElement() public {
        bytes32[] memory modules = new bytes32[](3);
        modules[0] = MODULE_1;
        modules[1] = MODULE_2;
        modules[2] = MODULE_3;
        _addGardenType(GARDEN_TYPE_1, modules);

        // Remove middle element (MODULE_2) - MODULE_3 should swap in
        registry.removeAllowedModule(GARDEN_TYPE_1, MODULE_2);

        bytes32[] memory gtModules = registry.getGardenTypeModules(GARDEN_TYPE_1);
        assertEq(gtModules.length, 2);
        assertEq(gtModules[0], MODULE_1);
        assertEq(gtModules[1], MODULE_3);
    }

    function test_removeAllowedModule_removesLastElement() public {
        bytes32[] memory modules = new bytes32[](3);
        modules[0] = MODULE_1;
        modules[1] = MODULE_2;
        modules[2] = MODULE_3;
        _addGardenType(GARDEN_TYPE_1, modules);

        // Remove last element (MODULE_3) - no swap needed
        registry.removeAllowedModule(GARDEN_TYPE_1, MODULE_3);

        bytes32[] memory gtModules = registry.getGardenTypeModules(GARDEN_TYPE_1);
        assertEq(gtModules.length, 2);
        assertEq(gtModules[0], MODULE_1);
        assertEq(gtModules[1], MODULE_2);
    }

    function test_removeAllowedModule_emitsEvent() public {
        bytes32[] memory modules = new bytes32[](1);
        modules[0] = MODULE_1;
        _addGardenType(GARDEN_TYPE_1, modules);

        vm.expectEmit(true, true, false, false);
        emit AllowedModuleRemoved(GARDEN_TYPE_1, MODULE_1);
        registry.removeAllowedModule(GARDEN_TYPE_1, MODULE_1);
    }

    function test_removeAllowedModule_canReAddAfterRemove() public {
        bytes32[] memory modules = new bytes32[](1);
        modules[0] = MODULE_1;
        _addGardenType(GARDEN_TYPE_1, modules);

        registry.removeAllowedModule(GARDEN_TYPE_1, MODULE_1);
        assertFalse(registry.isModuleAllowedForGardenType(GARDEN_TYPE_1, MODULE_1));

        registry.addAllowedModule(GARDEN_TYPE_1, MODULE_1);
        assertTrue(registry.isModuleAllowedForGardenType(GARDEN_TYPE_1, MODULE_1));
    }

    // ─── Revert Cases ───────────────────────────────────────────────────

    function test_removeAllowedModule_revert_gardenTypeDoesNotExist() public {
        vm.expectRevert(
            abi.encodeWithSelector(FacetRegistry_GardenTypeDoesNotExist.selector, GARDEN_TYPE_1)
        );
        registry.removeAllowedModule(GARDEN_TYPE_1, MODULE_1);
    }

    function test_removeAllowedModule_revert_moduleNotAllowed() public {
        _addGardenTypeEmpty(GARDEN_TYPE_1);

        vm.expectRevert(
            abi.encodeWithSelector(FacetRegistry_ModuleNotAllowed.selector, GARDEN_TYPE_1, MODULE_1)
        );
        registry.removeAllowedModule(GARDEN_TYPE_1, MODULE_1);
    }

    function test_removeAllowedModule_revert_nonOwner() public {
        bytes32[] memory modules = new bytes32[](1);
        modules[0] = MODULE_1;
        _addGardenType(GARDEN_TYPE_1, modules);

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        registry.removeAllowedModule(GARDEN_TYPE_1, MODULE_1);
    }

    // ─── Events ─────────────────────────────────────────────────────────

    event GardenTypeAdded(bytes32 indexed gardenTypeId, bytes32[] allowedModules);
    event AllowedModuleAdded(bytes32 indexed gardenTypeId, bytes32 indexed moduleId);
    event AllowedModuleRemoved(bytes32 indexed gardenTypeId, bytes32 indexed moduleId);
}
