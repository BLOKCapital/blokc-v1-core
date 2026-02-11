// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { FacetRegistryTestBase, MockFacetE, MockFacetF, MockFacetG, MockFacetH } from "../FacetRegistryTestBase.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";

import {
    FacetRegistry_SelectorArrayEmpty,
    FacetRegistry_FacetAddressIsZero,
    FacetRegistry_SelectorNotRegistered,
    FacetRegistry_CannotReplaceFunctionWithSameFunction,
    FacetRegistry_FacetNotInModule,
    FacetRegistry_FacetBelongsToAnotherModule,
    FacetRegistry_FacetIsNotContract
} from "src/facetRegistry/FacetRegistry.sol";

contract UpgradeModuleReplaceTest is FacetRegistryTestBase {
    function setUp() public override {
        super.setUp();
        _registerModule(MODULE_1);
        _registerModule(MODULE_2);
        // Add facetE to MODULE_1 with selectorsE
        _addFacetToModule(MODULE_1, address(facetE), selectorsE);
    }

    // ─── Success Cases ──────────────────────────────────────────────────

    function test_replaceFacetInModule_success() public {
        // Replace selectorsE from facetE to facetF in MODULE_1
        _replaceFacetInModule(MODULE_1, address(facetF), selectorsE);

        // FacetF now has those selectors
        assertEq(registry.getFacetAddress(MockFacetE.funcE1.selector), address(facetF));
        assertEq(registry.getFacetAddress(MockFacetE.funcE2.selector), address(facetF));
    }

    function test_replaceFacetInModule_oldFacetRemovedWhenNoSelectorsLeft() public {
        _replaceFacetInModule(MODULE_1, address(facetF), selectorsE);

        // FacetE should be removed from global and module
        assertFalse(registry.isFacetRegistered(address(facetE)));
        assertEq(registry.getFacetModule(address(facetE)), bytes32(0));

        // Global facet addresses should still have 5 (4 base + facetF)
        address[] memory addrs = registry.getFacetAddresses();
        assertEq(addrs.length, 5);
    }

    function test_replaceFacetInModule_newFacetAddedToModule() public {
        _replaceFacetInModule(MODULE_1, address(facetF), selectorsE);

        assertEq(registry.getFacetModule(address(facetF)), MODULE_1);

        address[] memory moduleAddrs = registry.getModuleFacetAddresses(MODULE_1);
        assertEq(moduleAddrs.length, 1);
        assertEq(moduleAddrs[0], address(facetF));
    }

    function test_replaceFacetInModule_updatesGlobalVersion() public {
        uint256 vBefore = registry.getCurrentVersion();
        _replaceFacetInModule(MODULE_1, address(facetF), selectorsE);
        assertEq(registry.getCurrentVersion(), vBefore + 1);
    }

    function test_replaceFacetInModule_updatesModuleVersion() public {
        uint256 vBefore = registry.getModuleVersion(MODULE_1);
        _replaceFacetInModule(MODULE_1, address(facetF), selectorsE);
        assertEq(registry.getModuleVersion(MODULE_1), vBefore + 1);
    }

    function test_replaceFacetInModule_globalFacetCutHistory() public {
        _replaceFacetInModule(MODULE_1, address(facetF), selectorsE);

        uint256 version = registry.getCurrentVersion();
        IDiamondCut.FacetCut[] memory cuts = registry.getFacetCutsByVersionRange(version, version);
        assertEq(cuts.length, 1);
        assertEq(cuts[0].facetAddress, address(facetF));
        assertEq(uint8(cuts[0].action), uint8(IDiamondCut.FacetCutAction.Replace));
    }

    function test_replaceFacetInModule_moduleFacetCutHistory() public {
        _replaceFacetInModule(MODULE_1, address(facetF), selectorsE);

        uint256 mVersion = registry.getModuleVersion(MODULE_1);
        IDiamondCut.FacetCut[] memory cuts =
            registry.getModuleFacetCutsByVersionRange(MODULE_1, mVersion, mVersion);
        assertEq(cuts[0].facetAddress, address(facetF));
        assertEq(uint8(cuts[0].action), uint8(IDiamondCut.FacetCutAction.Replace));
    }

    function test_replaceFacetInModule_emitsEvent() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(facetF),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: selectorsE
        });

        vm.expectEmit(true, true, false, true);
        emit ModuleFunctionsReplaced(MODULE_1, address(facetF), selectorsE);
        registry.upgradeModule(MODULE_1, cuts);
    }

    function test_replaceFacetInModule_partialReplace() public {
        // Add facetF with selectorsF to MODULE_1
        _addFacetToModule(MODULE_1, address(facetF), selectorsF);

        // Replace only selectorsE[0] with facetG (single selector facet)
        bytes4[] memory singleSel = new bytes4[](1);
        singleSel[0] = selectorsE[0];

        _replaceFacetInModule(MODULE_1, address(facetG), singleSel);

        // facetG now has selectorsE[0]
        assertEq(registry.getFacetAddress(selectorsE[0]), address(facetG));
        // facetE still has selectorsE[1]
        assertEq(registry.getFacetAddress(selectorsE[1]), address(facetE));
        // facetE still registered
        assertTrue(registry.isFacetRegistered(address(facetE)));
    }

    function test_replaceFacetInModule_oldFacetPartiallyRemainsInModule() public {
        // facetE has selectorsE[0] and selectorsE[1]
        // Replace only one selector
        bytes4[] memory singleSel = new bytes4[](1);
        singleSel[0] = selectorsE[0];

        _replaceFacetInModule(MODULE_1, address(facetF), singleSel);

        // facetE still in module (has 1 selector left)
        address[] memory moduleAddrs = registry.getModuleFacetAddresses(MODULE_1);
        assertEq(moduleAddrs.length, 2); // facetE + facetF

        bytes4[] memory remainingSels = registry.getFacetFunctionSelectors(address(facetE));
        assertEq(remainingSels.length, 1);
    }

    // ─── Revert Cases ───────────────────────────────────────────────────

    function test_replaceFacetInModule_revert_emptySelectorArray() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(facetF),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: new bytes4[](0)
        });

        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_SelectorArrayEmpty.selector));
        registry.upgradeModule(MODULE_1, cuts);
    }

    function test_replaceFacetInModule_revert_zeroFacetAddress() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(0),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: selectorsE
        });

        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_FacetAddressIsZero.selector));
        registry.upgradeModule(MODULE_1, cuts);
    }

    function test_replaceFacetInModule_revert_facetNotContract() public {
        address notContract = address(0xDEAD);
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: notContract,
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: selectorsE
        });

        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_FacetIsNotContract.selector, notContract));
        registry.upgradeModule(MODULE_1, cuts);
    }

    function test_replaceFacetInModule_revert_selectorNotRegistered() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(facetF),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: selectorsF // selectorsF not registered yet
        });

        vm.expectRevert(
            abi.encodeWithSelector(FacetRegistry_SelectorNotRegistered.selector, selectorsF[0])
        );
        registry.upgradeModule(MODULE_1, cuts);
    }

    function test_replaceFacetInModule_revert_replaceSameFunction() public {
        // Try to replace selectorsE with facetE itself (same facet)
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(facetE),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: selectorsE
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                FacetRegistry_CannotReplaceFunctionWithSameFunction.selector, address(facetE), selectorsE[0]
            )
        );
        registry.upgradeModule(MODULE_1, cuts);
    }

    function test_replaceFacetInModule_revert_oldFacetNotInModule() public {
        // Add facetF to MODULE_2
        _addFacetToModule(MODULE_2, address(facetF), selectorsF);

        // Try to replace selectorsF (in MODULE_2) from within MODULE_1 context
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(facetG),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: selectorsF
        });

        vm.expectRevert(
            abi.encodeWithSelector(FacetRegistry_FacetNotInModule.selector, address(facetF), MODULE_1)
        );
        registry.upgradeModule(MODULE_1, cuts);
    }

    function test_replaceFacetInModule_revert_newFacetBelongsToAnotherModule() public {
        // Add facetF to MODULE_2
        _addFacetToModule(MODULE_2, address(facetF), selectorsF);

        // Try to replace MODULE_1 selectors with facetF (which belongs to MODULE_2)
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(facetF),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: selectorsE
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                FacetRegistry_FacetBelongsToAnotherModule.selector, address(facetF), MODULE_2
            )
        );
        registry.upgradeModule(MODULE_1, cuts);
    }

    // ─── Events ─────────────────────────────────────────────────────────

    event ModuleFunctionsReplaced(bytes32 indexed moduleId, address indexed facetAddress, bytes4[] functionSelectors);
}
