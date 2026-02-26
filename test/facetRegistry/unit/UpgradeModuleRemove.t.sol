// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { FacetRegistryTestBase, MockFacetE, MockFacetF } from "../FacetRegistryTestBase.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";

import {
    FacetRegistry_SelectorArrayEmpty,
    FacetRegistry_RemoveFacetAddressMustBeZero,
    FacetRegistry_SelectorNotRegistered,
    FacetRegistry_FacetNotInModule
} from "src/facetRegistry/FacetRegistry.sol";

contract UpgradeModuleRemoveTest is FacetRegistryTestBase {
    function setUp() public override {
        super.setUp();
        _registerModule(MODULE_1);
        _registerModule(MODULE_2);
        _addFacetToModule(MODULE_1, address(facetE), selectorsE);
    }

    // ─── Success Cases
    // ──────────────────────────────────────────────────

    function test_removeFacetFromModule_success() public {
        _removeFacetFromModule(MODULE_1, selectorsE);

        assertFalse(registry.isSelectorRegistered(MockFacetE.funcE1.selector));
        assertFalse(registry.isSelectorRegistered(MockFacetE.funcE2.selector));
    }

    function test_removeFacetFromModule_facetRemovedWhenNoSelectors() public {
        _removeFacetFromModule(MODULE_1, selectorsE);

        assertFalse(registry.isFacetRegistered(address(facetE)));
        assertEq(registry.getFacetModule(address(facetE)), bytes32(0));

        address[] memory moduleAddrs = registry.getModuleFacetAddresses(MODULE_1);
        assertEq(moduleAddrs.length, 0);
    }

    function test_removeFacetFromModule_globalAddressesUpdated() public {
        _removeFacetFromModule(MODULE_1, selectorsE);

        address[] memory addrs = registry.getFacetAddresses();
        assertEq(addrs.length, 4); // back to 4 base only
    }

    function test_removeFacetFromModule_updatesGlobalVersion() public {
        uint256 vBefore = registry.getCurrentVersion();
        _removeFacetFromModule(MODULE_1, selectorsE);
        assertEq(registry.getCurrentVersion(), vBefore + 1);
    }

    function test_removeFacetFromModule_updatesModuleVersion() public {
        uint256 vBefore = registry.getModuleVersion(MODULE_1);
        _removeFacetFromModule(MODULE_1, selectorsE);
        assertEq(registry.getModuleVersion(MODULE_1), vBefore + 1);
    }

    function test_removeFacetFromModule_globalFacetCutHistory() public {
        _removeFacetFromModule(MODULE_1, selectorsE);

        uint256 version = registry.getCurrentVersion();
        IDiamondCut.FacetCut[] memory cuts = registry.getFacetCutsByVersionRange(version, version);
        assertEq(cuts.length, 1);
        assertEq(cuts[0].facetAddress, address(0));
        assertEq(uint8(cuts[0].action), uint8(IDiamondCut.FacetCutAction.Remove));
    }

    function test_removeFacetFromModule_moduleFacetCutHistory() public {
        _removeFacetFromModule(MODULE_1, selectorsE);

        uint256 mVersion = registry.getModuleVersion(MODULE_1);
        IDiamondCut.FacetCut[] memory cuts = registry.getModuleFacetCutsByVersionRange(MODULE_1, mVersion, mVersion);
        assertEq(cuts[0].facetAddress, address(0));
        assertEq(uint8(cuts[0].action), uint8(IDiamondCut.FacetCutAction.Remove));
    }

    function test_removeFacetFromModule_emitsEvent() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(0), action: IDiamondCut.FacetCutAction.Remove, functionSelectors: selectorsE
        });

        vm.expectEmit(true, false, false, true);
        emit ModuleFunctionsRemoved(MODULE_1, selectorsE);
        registry.upgradeModule(MODULE_1, cuts);
    }

    function test_removeFacetFromModule_partialRemove() public {
        // Remove only one selector
        bytes4[] memory singleSel = new bytes4[](1);
        singleSel[0] = selectorsE[0];

        _removeFacetFromModule(MODULE_1, singleSel);

        // facetE still has one selector
        assertTrue(registry.isFacetRegistered(address(facetE)));
        assertTrue(registry.isSelectorRegistered(selectorsE[1]));
        assertFalse(registry.isSelectorRegistered(selectorsE[0]));

        bytes4[] memory remainingSels = registry.getFacetFunctionSelectors(address(facetE));
        assertEq(remainingSels.length, 1);
    }

    function test_removeFacetFromModule_multipleFacetsSwapAndPop() public {
        // Add two more facets to MODULE_1
        _addFacetToModule(MODULE_1, address(facetF), selectorsF);
        _addFacetToModule(MODULE_1, address(facetG), selectorsG);

        // Module has: [facetE, facetF, facetG]
        address[] memory addrsBefore = registry.getModuleFacetAddresses(MODULE_1);
        assertEq(addrsBefore.length, 3);

        // Remove facetE (first element) - triggers swap-and-pop
        _removeFacetFromModule(MODULE_1, selectorsE);

        address[] memory addrsAfter = registry.getModuleFacetAddresses(MODULE_1);
        assertEq(addrsAfter.length, 2);

        // facetF and facetG should still be there
        assertTrue(registry.isFacetRegistered(address(facetF)));
        assertTrue(registry.isFacetRegistered(address(facetG)));
    }

    function test_removeFacetFromModule_removeLastFacetInModule() public {
        // Only facetE in MODULE_1, remove it
        _removeFacetFromModule(MODULE_1, selectorsE);

        address[] memory moduleAddrs = registry.getModuleFacetAddresses(MODULE_1);
        assertEq(moduleAddrs.length, 0);
        // Module itself still exists
        assertTrue(registry.isModuleRegistered(MODULE_1));
    }

    function test_removeFacetFromModule_selectorSwapAndPop() public {
        // facetE has [selectorsE[0], selectorsE[1]]
        // Remove selectorsE[0] - should cause swap-and-pop in selector array
        bytes4[] memory singleSel = new bytes4[](1);
        singleSel[0] = selectorsE[0];

        _removeFacetFromModule(MODULE_1, singleSel);

        // selectorsE[1] should still work
        assertEq(registry.getFacetAddress(selectorsE[1]), address(facetE));
        assertFalse(registry.isSelectorRegistered(selectorsE[0]));
    }

    // ─── Revert Cases
    // ───────────────────────────────────────────────────

    function test_removeFacetFromModule_revert_emptySelectorArray() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(0), action: IDiamondCut.FacetCutAction.Remove, functionSelectors: new bytes4[](0)
        });

        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_SelectorArrayEmpty.selector));
        registry.upgradeModule(MODULE_1, cuts);
    }

    function test_removeFacetFromModule_revert_nonZeroFacetAddress() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(facetE), action: IDiamondCut.FacetCutAction.Remove, functionSelectors: selectorsE
        });

        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_RemoveFacetAddressMustBeZero.selector, address(facetE)));
        registry.upgradeModule(MODULE_1, cuts);
    }

    function test_removeFacetFromModule_revert_selectorNotRegistered() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(0),
            action: IDiamondCut.FacetCutAction.Remove,
            functionSelectors: selectorsF // not registered
        });

        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_SelectorNotRegistered.selector, selectorsF[0]));
        registry.upgradeModule(MODULE_1, cuts);
    }

    function test_removeFacetFromModule_revert_facetNotInModule() public {
        // facetE is in MODULE_1, try to remove from MODULE_2
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(0), action: IDiamondCut.FacetCutAction.Remove, functionSelectors: selectorsE
        });

        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_FacetNotInModule.selector, address(facetE), MODULE_2));
        registry.upgradeModule(MODULE_2, cuts);
    }

    // ─── Events
    // ─────────────────────────────────────────────────────────

    event ModuleFunctionsRemoved(bytes32 indexed moduleId, bytes4[] functionSelectors);
}
