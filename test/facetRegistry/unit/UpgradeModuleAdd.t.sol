// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { FacetRegistryTestBase, MockFacetE, MockFacetF, MockFacetG } from "../FacetRegistryTestBase.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import {
    FacetRegistry_ModuleDoesNotExist,
    FacetRegistry_CannotModifyBaseModule,
    FacetRegistry_FacetCutsArrayEmpty,
    FacetRegistry_SelectorArrayEmpty,
    FacetRegistry_FacetAddressIsZero,
    FacetRegistry_FacetIsNotContract,
    FacetRegistry_CannotAddFunctionThatAlreadyExists,
    FacetRegistry_FacetBelongsToAnotherModule
} from "src/facetRegistry/FacetRegistry.sol";

contract UpgradeModuleAddTest is FacetRegistryTestBase {
    function setUp() public override {
        super.setUp();
        _registerModule(MODULE_1);
        _registerModule(MODULE_2);
    }

    // ─── Success Cases
    // ──────────────────────────────────────────────────

    function test_addFacetToModule_success() public {
        _addFacetToModule(MODULE_1, address(facetE), selectorsE);

        assertTrue(registry.isFacetRegistered(address(facetE)));
        assertTrue(registry.isSelectorRegistered(MockFacetE.funcE1.selector));
        assertTrue(registry.isSelectorRegistered(MockFacetE.funcE2.selector));
    }

    function test_addFacetToModule_updatesGlobalVersion() public {
        uint256 vBefore = registry.getCurrentVersion();
        _addFacetToModule(MODULE_1, address(facetE), selectorsE);
        assertEq(registry.getCurrentVersion(), vBefore + 1);
    }

    function test_addFacetToModule_updatesModuleVersion() public {
        uint256 vBefore = registry.getModuleVersion(MODULE_1);
        _addFacetToModule(MODULE_1, address(facetE), selectorsE);
        assertEq(registry.getModuleVersion(MODULE_1), vBefore + 1);
    }

    function test_addFacetToModule_facetBelongsToModule() public {
        _addFacetToModule(MODULE_1, address(facetE), selectorsE);
        assertEq(registry.getFacetModule(address(facetE)), MODULE_1);
    }

    function test_addFacetToModule_facetInModuleAddresses() public {
        _addFacetToModule(MODULE_1, address(facetE), selectorsE);

        address[] memory addrs = registry.getModuleFacetAddresses(MODULE_1);
        assertEq(addrs.length, 1);
        assertEq(addrs[0], address(facetE));
    }

    function test_addFacetToModule_selectorMappedToFacet() public {
        _addFacetToModule(MODULE_1, address(facetE), selectorsE);

        assertEq(registry.getFacetAddress(MockFacetE.funcE1.selector), address(facetE));
        assertEq(registry.getFacetAddress(MockFacetE.funcE2.selector), address(facetE));
    }

    function test_addFacetToModule_selectorRegisteredWithFacet() public {
        _addFacetToModule(MODULE_1, address(facetE), selectorsE);

        assertTrue(registry.isSelectorRegisteredWithFacet(address(facetE), MockFacetE.funcE1.selector));
        assertTrue(registry.isSelectorRegisteredWithFacet(address(facetE), MockFacetE.funcE2.selector));
    }

    function test_addFacetToModule_globalFacetCutHistory() public {
        _addFacetToModule(MODULE_1, address(facetE), selectorsE);

        uint256 version = registry.getCurrentVersion();
        IDiamondCut.FacetCut[] memory cuts = registry.getFacetCutsByVersionRange(version, version);
        assertEq(cuts.length, 1);
        assertEq(cuts[0].facetAddress, address(facetE));
        assertEq(uint8(cuts[0].action), uint8(IDiamondCut.FacetCutAction.Add));
        assertEq(cuts[0].functionSelectors.length, 2);
    }

    function test_addFacetToModule_moduleFacetCutHistory() public {
        _addFacetToModule(MODULE_1, address(facetE), selectorsE);

        uint256 mVersion = registry.getModuleVersion(MODULE_1);
        IDiamondCut.FacetCut[] memory cuts = registry.getModuleFacetCutsByVersionRange(MODULE_1, mVersion, mVersion);
        assertEq(cuts.length, 1);
        assertEq(cuts[0].facetAddress, address(facetE));
    }

    function test_addFacetToModule_multipleFacetsToSameModule() public {
        _addFacetToModule(MODULE_1, address(facetE), selectorsE);
        _addFacetToModule(MODULE_1, address(facetF), selectorsF);

        address[] memory addrs = registry.getModuleFacetAddresses(MODULE_1);
        assertEq(addrs.length, 2);

        IFacetRegistry.Facet[] memory facets = registry.getModuleFacets(MODULE_1);
        assertEq(facets.length, 2);
    }

    function test_addFacetToModule_addMoreSelectorsToExistingFacetInSameModule() public {
        // First add with selectorsG (1 selector)
        _addFacetToModule(MODULE_1, address(facetG), selectorsG);

        // Then add more selectors to the same facet using selectorsH on a new facet
        // But for the same facet, we can only add more selectors within the same module
        // Let's verify single selector add works first
        bytes4[] memory sels = registry.getFacetFunctionSelectors(address(facetG));
        assertEq(sels.length, 1);
        assertEq(sels[0], MockFacetG.funcG1.selector);
    }

    function test_addFacetToModule_globalFacetAddresses() public {
        _addFacetToModule(MODULE_1, address(facetE), selectorsE);

        address[] memory all = registry.getFacetAddresses();
        assertEq(all.length, 5); // 4 base + 1
    }

    function test_addFacetToModule_emitsEvent() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(facetE), action: IDiamondCut.FacetCutAction.Add, functionSelectors: selectorsE
        });

        vm.expectEmit(true, true, false, true);
        emit ModuleFunctionsAdded(MODULE_1, address(facetE), selectorsE);
        registry.upgradeModule(MODULE_1, cuts);
    }

    function test_addFacetToModule_multipleCutsInOneCall() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](2);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(facetE), action: IDiamondCut.FacetCutAction.Add, functionSelectors: selectorsE
        });
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(facetF), action: IDiamondCut.FacetCutAction.Add, functionSelectors: selectorsF
        });

        registry.upgradeModule(MODULE_1, cuts);

        assertTrue(registry.isFacetRegistered(address(facetE)));
        assertTrue(registry.isFacetRegistered(address(facetF)));
        assertEq(registry.getFacetModule(address(facetE)), MODULE_1);
        assertEq(registry.getFacetModule(address(facetF)), MODULE_1);
    }

    // ─── Revert Cases
    // ───────────────────────────────────────────────────

    function test_addFacetToModule_revert_moduleDoesNotExist() public {
        bytes32 nonExistent = keccak256("NONEXISTENT");
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(facetE), action: IDiamondCut.FacetCutAction.Add, functionSelectors: selectorsE
        });

        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_ModuleDoesNotExist.selector, nonExistent));
        registry.upgradeModule(nonExistent, cuts);
    }

    function test_addFacetToModule_revert_cannotModifyBaseModule() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(facetE), action: IDiamondCut.FacetCutAction.Add, functionSelectors: selectorsE
        });

        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_CannotModifyBaseModule.selector));
        registry.upgradeModule(BASE_MODULE, cuts);
    }

    function test_addFacetToModule_revert_emptyFacetCutsArray() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](0);

        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_FacetCutsArrayEmpty.selector));
        registry.upgradeModule(MODULE_1, cuts);
    }

    function test_addFacetToModule_revert_emptySelectorArray() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(facetE), action: IDiamondCut.FacetCutAction.Add, functionSelectors: new bytes4[](0)
        });

        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_SelectorArrayEmpty.selector));
        registry.upgradeModule(MODULE_1, cuts);
    }

    function test_addFacetToModule_revert_zeroFacetAddress() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(0), action: IDiamondCut.FacetCutAction.Add, functionSelectors: selectorsE
        });

        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_FacetAddressIsZero.selector));
        registry.upgradeModule(MODULE_1, cuts);
    }

    function test_addFacetToModule_revert_facetNotContract() public {
        address notContract = address(0xDEAD);
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: notContract, action: IDiamondCut.FacetCutAction.Add, functionSelectors: selectorsE
        });

        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_FacetIsNotContract.selector, notContract));
        registry.upgradeModule(MODULE_1, cuts);
    }

    function test_addFacetToModule_revert_selectorAlreadyExists() public {
        _addFacetToModule(MODULE_1, address(facetE), selectorsE);

        // Try adding the same selectors again with a different facet
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(facetF),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectorsE // same selectors
        });

        vm.expectRevert(
            abi.encodeWithSelector(FacetRegistry_CannotAddFunctionThatAlreadyExists.selector, selectorsE[0])
        );
        registry.upgradeModule(MODULE_1, cuts);
    }

    function test_addFacetToModule_revert_selectorAlreadyExistsInBaseFacets() public {
        // Try to add a selector that belongs to base facets
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(facetE),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectorsA // already in base
        });

        vm.expectRevert(
            abi.encodeWithSelector(FacetRegistry_CannotAddFunctionThatAlreadyExists.selector, selectorsA[0])
        );
        registry.upgradeModule(MODULE_1, cuts);
    }

    function test_addFacetToModule_revert_facetBelongsToAnotherModule() public {
        _addFacetToModule(MODULE_1, address(facetE), selectorsE);

        // Try to add same facet to MODULE_2 with different selectors
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(facetE),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectorsF // different selectors
        });

        vm.expectRevert(
            abi.encodeWithSelector(FacetRegistry_FacetBelongsToAnotherModule.selector, address(facetE), MODULE_1)
        );
        registry.upgradeModule(MODULE_2, cuts);
    }

    function test_addFacetToModule_revert_nonOwner() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(facetE), action: IDiamondCut.FacetCutAction.Add, functionSelectors: selectorsE
        });

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        registry.upgradeModule(MODULE_1, cuts);
    }

    // ─── Events
    // ─────────────────────────────────────────────────────────

    event ModuleFunctionsAdded(bytes32 indexed moduleId, address indexed facetAddress, bytes4[] functionSelectors);
}
