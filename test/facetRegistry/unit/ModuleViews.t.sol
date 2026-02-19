// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { FacetRegistryTestBase, MockFacetE, MockFacetF } from "../FacetRegistryTestBase.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";

import {
    FacetRegistry_ModuleDoesNotExist,
    FacetRegistry_InvalidVersionRange,
    FacetRegistry_VersionOutOfBounds
} from "src/facetRegistry/FacetRegistry.sol";

contract ModuleViewsTest is FacetRegistryTestBase {
    function setUp() public override {
        super.setUp();
        _registerModule(MODULE_1);
        _addFacetToModule(MODULE_1, address(facetE), selectorsE);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                         getModuleFacets
    // ═══════════════════════════════════════════════════════════════════════

    function test_getModuleFacets_success() public view {
        IFacetRegistry.Facet[] memory facets = registry.getModuleFacets(MODULE_1);
        assertEq(facets.length, 1);
        assertEq(facets[0].facetAddress, address(facetE));
        assertEq(facets[0].functionSelectors.length, 2);
        assertEq(facets[0].functionSelectors[0], MockFacetE.funcE1.selector);
        assertEq(facets[0].functionSelectors[1], MockFacetE.funcE2.selector);
    }

    function test_getModuleFacets_baseModule() public view {
        IFacetRegistry.Facet[] memory facets = registry.getModuleFacets(BASE_MODULE);
        assertEq(facets.length, 4);
    }

    function test_getModuleFacets_emptyModule() public {
        _registerModule(MODULE_2);
        IFacetRegistry.Facet[] memory facets = registry.getModuleFacets(MODULE_2);
        assertEq(facets.length, 0);
    }

    function test_getModuleFacets_revert_moduleDoesNotExist() public {
        bytes32 nonExistent = keccak256("NONEXISTENT");
        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_ModuleDoesNotExist.selector, nonExistent));
        registry.getModuleFacets(nonExistent);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                      getModuleFacetAddresses
    // ═══════════════════════════════════════════════════════════════════════

    function test_getModuleFacetAddresses_success() public view {
        address[] memory addrs = registry.getModuleFacetAddresses(MODULE_1);
        assertEq(addrs.length, 1);
        assertEq(addrs[0], address(facetE));
    }

    function test_getModuleFacetAddresses_revert_moduleDoesNotExist() public {
        bytes32 nonExistent = keccak256("NONEXISTENT");
        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_ModuleDoesNotExist.selector, nonExistent));
        registry.getModuleFacetAddresses(nonExistent);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                  getModuleFacetCutsByVersionRange
    // ═══════════════════════════════════════════════════════════════════════

    function test_getModuleFacetCutsByVersionRange_singleVersion() public view {
        uint256 mVersion = registry.getModuleVersion(MODULE_1);
        IDiamondCut.FacetCut[] memory cuts =
            registry.getModuleFacetCutsByVersionRange(MODULE_1, mVersion, mVersion);
        assertEq(cuts.length, 1);
        assertEq(cuts[0].facetAddress, address(facetE));
    }

    function test_getModuleFacetCutsByVersionRange_multipleVersions() public {
        _addFacetToModule(MODULE_1, address(facetF), selectorsF);

        IDiamondCut.FacetCut[] memory cuts =
            registry.getModuleFacetCutsByVersionRange(MODULE_1, 1, 2);
        assertEq(cuts.length, 2);
        assertEq(cuts[0].facetAddress, address(facetE));
        assertEq(cuts[1].facetAddress, address(facetF));
    }

    function test_getModuleFacetCutsByVersionRange_baseModule() public view {
        IDiamondCut.FacetCut[] memory cuts =
            registry.getModuleFacetCutsByVersionRange(BASE_MODULE, 1, 4);
        assertEq(cuts.length, 4);
    }

    function test_getModuleFacetCutsByVersionRange_revert_moduleDoesNotExist() public {
        bytes32 nonExistent = keccak256("NONEXISTENT");
        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_ModuleDoesNotExist.selector, nonExistent));
        registry.getModuleFacetCutsByVersionRange(nonExistent, 1, 1);
    }

    function test_getModuleFacetCutsByVersionRange_revert_invalidRange_startZero() public {
        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_InvalidVersionRange.selector, 0, 1));
        registry.getModuleFacetCutsByVersionRange(MODULE_1, 0, 1);
    }

    function test_getModuleFacetCutsByVersionRange_revert_invalidRange_startGtEnd() public {
        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_InvalidVersionRange.selector, 3, 1));
        registry.getModuleFacetCutsByVersionRange(MODULE_1, 3, 1);
    }

    function test_getModuleFacetCutsByVersionRange_revert_versionOutOfBounds() public {
        uint256 mVersion = registry.getModuleVersion(MODULE_1);
        vm.expectRevert(
            abi.encodeWithSelector(FacetRegistry_VersionOutOfBounds.selector, mVersion + 1, mVersion)
        );
        registry.getModuleFacetCutsByVersionRange(MODULE_1, 1, mVersion + 1);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                         getModuleVersion
    // ═══════════════════════════════════════════════════════════════════════

    function test_getModuleVersion_base() public view {
        assertEq(registry.getModuleVersion(BASE_MODULE), 4);
    }

    function test_getModuleVersion_afterUpgrade() public view {
        assertEq(registry.getModuleVersion(MODULE_1), 1);
    }

    function test_getModuleVersion_revert_moduleDoesNotExist() public {
        bytes32 nonExistent = keccak256("NONEXISTENT");
        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_ModuleDoesNotExist.selector, nonExistent));
        registry.getModuleVersion(nonExistent);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                         getAllModuleIds
    // ═══════════════════════════════════════════════════════════════════════

    function test_getAllModuleIds_afterRegistration() public view {
        bytes32[] memory ids = registry.getAllModuleIds();
        assertEq(ids.length, 2); // BASE + MODULE_1
        assertEq(ids[0], BASE_MODULE);
        assertEq(ids[1], MODULE_1);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                          getFacetModule
    // ═══════════════════════════════════════════════════════════════════════

    function test_getFacetModule_baseFacet() public view {
        assertEq(registry.getFacetModule(address(facetA)), BASE_MODULE);
    }

    function test_getFacetModule_moduleFacet() public view {
        assertEq(registry.getFacetModule(address(facetE)), MODULE_1);
    }

    function test_getFacetModule_unregisteredFacet() public view {
        assertEq(registry.getFacetModule(address(0xDEAD)), bytes32(0));
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                        isModuleRegistered
    // ═══════════════════════════════════════════════════════════════════════

    function test_isModuleRegistered_true() public view {
        assertTrue(registry.isModuleRegistered(BASE_MODULE));
        assertTrue(registry.isModuleRegistered(MODULE_1));
    }

    function test_isModuleRegistered_false() public view {
        assertFalse(registry.isModuleRegistered(keccak256("NONEXISTENT")));
    }
}
