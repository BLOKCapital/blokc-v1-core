// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { FacetRegistryTestBase, MockFacetE, MockFacetF } from "../FacetRegistryTestBase.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";

import { FacetRegistry_GardenTypeDoesNotExist } from "src/facetRegistry/FacetRegistry.sol";

contract GardenTypeViewsTest is FacetRegistryTestBase {
    function setUp() public override {
        super.setUp();
        _registerModule(MODULE_1);
        _registerModule(MODULE_2);
        _addFacetToModule(MODULE_1, address(facetE), selectorsE);
        _addFacetToModule(MODULE_2, address(facetF), selectorsF);

        bytes32[] memory modules = new bytes32[](2);
        modules[0] = MODULE_1;
        modules[1] = MODULE_2;
        _addGardenType(GARDEN_TYPE_1, modules);

        _addGardenTypeEmpty(GARDEN_TYPE_2);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                       getGardenTypeModules
    // ═══════════════════════════════════════════════════════════════════════

    function test_getGardenTypeModules_withModules() public view {
        bytes32[] memory modules = registry.getGardenTypeModules(GARDEN_TYPE_1);
        assertEq(modules.length, 2);
        assertEq(modules[0], MODULE_1);
        assertEq(modules[1], MODULE_2);
    }

    function test_getGardenTypeModules_empty() public view {
        bytes32[] memory modules = registry.getGardenTypeModules(GARDEN_TYPE_2);
        assertEq(modules.length, 0);
    }

    function test_getGardenTypeModules_revert_doesNotExist() public {
        bytes32 nonExistent = keccak256("NONEXISTENT");
        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_GardenTypeDoesNotExist.selector, nonExistent));
        registry.getGardenTypeModules(nonExistent);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                   isModuleAllowedForGardenType
    // ═══════════════════════════════════════════════════════════════════════

    function test_isModuleAllowedForGardenType_trueForAddedModule() public view {
        assertTrue(registry.isModuleAllowedForGardenType(GARDEN_TYPE_1, MODULE_1));
        assertTrue(registry.isModuleAllowedForGardenType(GARDEN_TYPE_1, MODULE_2));
    }

    function test_isModuleAllowedForGardenType_trueForBaseModule() public view {
        assertTrue(registry.isModuleAllowedForGardenType(GARDEN_TYPE_1, BASE_MODULE));
        assertTrue(registry.isModuleAllowedForGardenType(GARDEN_TYPE_2, BASE_MODULE));
    }

    function test_isModuleAllowedForGardenType_falseForUnallowedModule() public view {
        assertFalse(registry.isModuleAllowedForGardenType(GARDEN_TYPE_2, MODULE_1));
    }

    function test_isModuleAllowedForGardenType_revert_doesNotExist() public {
        bytes32 nonExistent = keccak256("NONEXISTENT");
        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_GardenTypeDoesNotExist.selector, nonExistent));
        registry.isModuleAllowedForGardenType(nonExistent, MODULE_1);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                       getAllGardenTypeIds
    // ═══════════════════════════════════════════════════════════════════════

    function test_getAllGardenTypeIds() public view {
        bytes32[] memory ids = registry.getAllGardenTypeIds();
        assertEq(ids.length, 2);
        assertEq(ids[0], GARDEN_TYPE_1);
        assertEq(ids[1], GARDEN_TYPE_2);
    }

    function test_getAllGardenTypeIds_empty() public {
        // Deploy fresh registry to get empty garden type list
        FacetRegistryTestBase.setUp();
        // Re-read after fresh setup
        bytes32[] memory ids = registry.getAllGardenTypeIds();
        assertEq(ids.length, 0);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                      isGardenTypeRegistered
    // ═══════════════════════════════════════════════════════════════════════

    function test_isGardenTypeRegistered_true() public view {
        assertTrue(registry.isGardenTypeRegistered(GARDEN_TYPE_1));
        assertTrue(registry.isGardenTypeRegistered(GARDEN_TYPE_2));
    }

    function test_isGardenTypeRegistered_false() public view {
        assertFalse(registry.isGardenTypeRegistered(keccak256("NONEXISTENT")));
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                     getGardenTypeFacetCuts
    // ═══════════════════════════════════════════════════════════════════════

    function test_getGardenTypeFacetCuts_includesBaseAndModuleFacets() public view {
        IDiamondCut.FacetCut[] memory cuts = registry.getGardenTypeFacetCuts(GARDEN_TYPE_1);

        // 4 base facets + 1 from MODULE_1 + 1 from MODULE_2 = 6
        assertEq(cuts.length, 6);

        // All should be Add action
        for (uint256 i = 0; i < cuts.length; i++) {
            assertEq(uint8(cuts[i].action), uint8(IDiamondCut.FacetCutAction.Add));
        }

        // First 4 should be base facets
        assertEq(cuts[0].facetAddress, address(facetA));
        assertEq(cuts[1].facetAddress, address(facetB));
        assertEq(cuts[2].facetAddress, address(facetC));
        assertEq(cuts[3].facetAddress, address(facetD));

        // Module facets
        assertEq(cuts[4].facetAddress, address(facetE));
        assertEq(cuts[5].facetAddress, address(facetF));
    }

    function test_getGardenTypeFacetCuts_emptyGardenType_onlyBase() public view {
        IDiamondCut.FacetCut[] memory cuts = registry.getGardenTypeFacetCuts(GARDEN_TYPE_2);
        // Only 4 base facets
        assertEq(cuts.length, 4);
    }

    function test_getGardenTypeFacetCuts_selectorsCorrect() public view {
        IDiamondCut.FacetCut[] memory cuts = registry.getGardenTypeFacetCuts(GARDEN_TYPE_1);

        // facetE selectors
        assertEq(cuts[4].functionSelectors.length, 2);
        assertEq(cuts[4].functionSelectors[0], MockFacetE.funcE1.selector);
        assertEq(cuts[4].functionSelectors[1], MockFacetE.funcE2.selector);
    }

    function test_getGardenTypeFacetCuts_revert_doesNotExist() public {
        bytes32 nonExistent = keccak256("NONEXISTENT");
        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_GardenTypeDoesNotExist.selector, nonExistent));
        registry.getGardenTypeFacetCuts(nonExistent);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                       getGardenTypeFacets
    // ═══════════════════════════════════════════════════════════════════════

    function test_getGardenTypeFacets_includesBaseAndModuleFacets() public view {
        IFacetRegistry.Facet[] memory facets = registry.getGardenTypeFacets(GARDEN_TYPE_1);

        assertEq(facets.length, 6);

        // Base facets
        assertEq(facets[0].facetAddress, address(facetA));
        assertEq(facets[0].functionSelectors.length, 2);

        // Module facets
        assertEq(facets[4].facetAddress, address(facetE));
        assertEq(facets[5].facetAddress, address(facetF));
    }

    function test_getGardenTypeFacets_emptyGardenType_onlyBase() public view {
        IFacetRegistry.Facet[] memory facets = registry.getGardenTypeFacets(GARDEN_TYPE_2);
        assertEq(facets.length, 4);
    }

    function test_getGardenTypeFacets_revert_doesNotExist() public {
        bytes32 nonExistent = keccak256("NONEXISTENT");
        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_GardenTypeDoesNotExist.selector, nonExistent));
        registry.getGardenTypeFacets(nonExistent);
    }
}
