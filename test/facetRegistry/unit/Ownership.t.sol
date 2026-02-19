// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { FacetRegistryTestBase } from "../FacetRegistryTestBase.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { FacetRegistry_CannotRenounceOwnership } from "src/facetRegistry/FacetRegistry.sol";

contract OwnershipTest is FacetRegistryTestBase {
    // ─── transferOwnership
    // ──────────────────────────────────────────────

    function test_transferOwnership_success() public {
        address newOwner = address(0xCAFE);
        registry.transferOwnership(newOwner);
        assertEq(registry.owner(), newOwner);
    }

    function test_transferOwnership_revert_nonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        registry.transferOwnership(address(0xCAFE));
    }

    function test_transferOwnership_newOwnerCanRegisterModule() public {
        address newOwner = address(0xCAFE);
        registry.transferOwnership(newOwner);

        vm.prank(newOwner);
        registry.registerModule(MODULE_1);
        assertTrue(registry.isModuleRegistered(MODULE_1));
    }

    function test_transferOwnership_oldOwnerCannotRegisterModule() public {
        address newOwner = address(0xCAFE);
        registry.transferOwnership(newOwner);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, owner));
        registry.registerModule(MODULE_1);
    }

    // ─── All onlyOwner functions revert for non-owner ───────────────────

    function test_allOwnerFunctions_revert_nonOwner() public {
        vm.startPrank(nonOwner);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        registry.registerModule(MODULE_1);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](0);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        registry.upgradeModule(MODULE_1, cuts);

        bytes32[] memory modules = new bytes32[](0);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        registry.addGardenType(GARDEN_TYPE_1, modules);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        registry.addAllowedModule(GARDEN_TYPE_1, MODULE_1);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        registry.removeAllowedModule(GARDEN_TYPE_1, MODULE_1);

        vm.stopPrank();
    }
}

import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";
