// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { FacetRegistryTestBase } from "../FacetRegistryTestBase.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import {
    FacetRegistry_ModuleIdIsZero,
    FacetRegistry_ModuleAlreadyExists
} from "src/facetRegistry/FacetRegistry.sol";

contract RegisterModuleTest is FacetRegistryTestBase {
    // ─── Success Cases ──────────────────────────────────────────────────

    function test_registerModule_success() public {
        _registerModule(MODULE_1);
        assertTrue(registry.isModuleRegistered(MODULE_1));
    }

    function test_registerModule_addsToModuleIdsList() public {
        _registerModule(MODULE_1);

        bytes32[] memory moduleIds = registry.getAllModuleIds();
        assertEq(moduleIds.length, 2); // BASE_MODULE + MODULE_1
        assertEq(moduleIds[1], MODULE_1);
    }

    function test_registerModule_moduleVersionStartsAtZero() public {
        _registerModule(MODULE_1);
        assertEq(registry.getModuleVersion(MODULE_1), 0);
    }

    function test_registerModule_emptyFacetAddresses() public {
        _registerModule(MODULE_1);

        address[] memory addrs = registry.getModuleFacetAddresses(MODULE_1);
        assertEq(addrs.length, 0);
    }

    function test_registerModule_multipleModules() public {
        _registerModule(MODULE_1);
        _registerModule(MODULE_2);
        _registerModule(MODULE_3);

        bytes32[] memory moduleIds = registry.getAllModuleIds();
        assertEq(moduleIds.length, 4); // BASE + 3
        assertTrue(registry.isModuleRegistered(MODULE_1));
        assertTrue(registry.isModuleRegistered(MODULE_2));
        assertTrue(registry.isModuleRegistered(MODULE_3));
    }

    function test_registerModule_emitsEvent() public {
        vm.expectEmit(true, false, false, false);
        emit ModuleRegistered(MODULE_1);
        _registerModule(MODULE_1);
    }

    function test_registerModule_doesNotChangeGlobalVersion() public {
        uint256 versionBefore = registry.getCurrentVersion();
        _registerModule(MODULE_1);
        assertEq(registry.getCurrentVersion(), versionBefore);
    }

    // ─── Revert Cases ───────────────────────────────────────────────────

    function test_registerModule_revert_zeroModuleId() public {
        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_ModuleIdIsZero.selector));
        registry.registerModule(bytes32(0));
    }

    function test_registerModule_revert_moduleAlreadyExists() public {
        _registerModule(MODULE_1);

        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_ModuleAlreadyExists.selector, MODULE_1));
        registry.registerModule(MODULE_1);
    }

    function test_registerModule_revert_baseModuleAlreadyExists() public {
        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_ModuleAlreadyExists.selector, BASE_MODULE));
        registry.registerModule(BASE_MODULE);
    }

    function test_registerModule_revert_nonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        registry.registerModule(MODULE_1);
    }

    // ─── Events ─────────────────────────────────────────────────────────

    event ModuleRegistered(bytes32 indexed moduleId);
}
