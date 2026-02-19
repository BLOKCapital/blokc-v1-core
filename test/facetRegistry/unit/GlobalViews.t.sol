// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { FacetRegistryTestBase, MockFacetA, MockFacetB, MockFacetE } from "../FacetRegistryTestBase.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";

import {
    FacetRegistry_InvalidVersionRange,
    FacetRegistry_VersionOutOfBounds,
    FacetRegistry_FacetAddressIsZero
} from "src/facetRegistry/FacetRegistry.sol";

contract GlobalViewsTest is FacetRegistryTestBase {
    // ═══════════════════════════════════════════════════════════════════════
    //                            getFacets
    // ═══════════════════════════════════════════════════════════════════════

    function test_getFacets_returnsAll() public view {
        IFacetRegistry.Facet[] memory facets = registry.getFacets();
        assertEq(facets.length, 4);
        for (uint256 i = 0; i < 4; i++) {
            assertTrue(facets[i].facetAddress != address(0));
            assertEq(facets[i].functionSelectors.length, 2);
        }
    }

    function test_getFacets_afterAddingModuleFacet() public {
        _registerModule(MODULE_1);
        _addFacetToModule(MODULE_1, address(facetE), selectorsE);

        IFacetRegistry.Facet[] memory facets = registry.getFacets();
        assertEq(facets.length, 5);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                     getFacetFunctionSelectors
    // ═══════════════════════════════════════════════════════════════════════

    function test_getFacetFunctionSelectors_existingFacet() public view {
        bytes4[] memory sels = registry.getFacetFunctionSelectors(address(facetA));
        assertEq(sels.length, 2);
        assertEq(sels[0], MockFacetA.funcA1.selector);
        assertEq(sels[1], MockFacetA.funcA2.selector);
    }

    function test_getFacetFunctionSelectors_unregisteredFacet() public view {
        bytes4[] memory sels = registry.getFacetFunctionSelectors(address(0xDEAD));
        assertEq(sels.length, 0);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                        getFacetAddresses
    // ═══════════════════════════════════════════════════════════════════════

    function test_getFacetAddresses_base() public view {
        address[] memory addrs = registry.getFacetAddresses();
        assertEq(addrs.length, 4);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                         getFacetAddress
    // ═══════════════════════════════════════════════════════════════════════

    function test_getFacetAddress_existingSelector() public view {
        assertEq(registry.getFacetAddress(MockFacetA.funcA1.selector), address(facetA));
    }

    function test_getFacetAddress_unregisteredSelector() public view {
        assertEq(registry.getFacetAddress(bytes4(0xDEADDEAD)), address(0));
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                          getBaseFacets
    // ═══════════════════════════════════════════════════════════════════════

    function test_getBaseFacets() public view {
        address[4] memory base = registry.getBaseFacets();
        assertEq(base[0], address(facetA));
        assertEq(base[1], address(facetB));
        assertEq(base[2], address(facetC));
        assertEq(base[3], address(facetD));
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                    getFacetCutsByVersionRange
    // ═══════════════════════════════════════════════════════════════════════

    function test_getFacetCutsByVersionRange_allVersions() public view {
        IDiamondCut.FacetCut[] memory cuts = registry.getFacetCutsByVersionRange(1, 4);
        assertEq(cuts.length, 4);
    }

    function test_getFacetCutsByVersionRange_singleVersion() public view {
        IDiamondCut.FacetCut[] memory cuts = registry.getFacetCutsByVersionRange(1, 1);
        assertEq(cuts.length, 1);
        assertEq(cuts[0].facetAddress, address(facetA));
    }

    function test_getFacetCutsByVersionRange_afterModuleUpgrade() public {
        _registerModule(MODULE_1);
        _addFacetToModule(MODULE_1, address(facetE), selectorsE);

        uint256 version = registry.getCurrentVersion();
        IDiamondCut.FacetCut[] memory cuts = registry.getFacetCutsByVersionRange(version, version);
        assertEq(cuts.length, 1);
        assertEq(cuts[0].facetAddress, address(facetE));
    }

    function test_getFacetCutsByVersionRange_revert_startVersionZero() public {
        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_InvalidVersionRange.selector, 0, 4));
        registry.getFacetCutsByVersionRange(0, 4);
    }

    function test_getFacetCutsByVersionRange_revert_startGtEnd() public {
        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_InvalidVersionRange.selector, 3, 1));
        registry.getFacetCutsByVersionRange(3, 1);
    }

    function test_getFacetCutsByVersionRange_revert_endVersionOutOfBounds() public {
        uint256 current = registry.getCurrentVersion();
        vm.expectRevert(
            abi.encodeWithSelector(FacetRegistry_VersionOutOfBounds.selector, current + 1, current)
        );
        registry.getFacetCutsByVersionRange(1, current + 1);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                        isFacetRegistered
    // ═══════════════════════════════════════════════════════════════════════

    function test_isFacetRegistered_true() public view {
        assertTrue(registry.isFacetRegistered(address(facetA)));
    }

    function test_isFacetRegistered_false() public view {
        assertFalse(registry.isFacetRegistered(address(0xDEAD)));
    }

    function test_isFacetRegistered_afterRemoval() public {
        _registerModule(MODULE_1);
        _addFacetToModule(MODULE_1, address(facetE), selectorsE);
        assertTrue(registry.isFacetRegistered(address(facetE)));

        _removeFacetFromModule(MODULE_1, selectorsE);
        assertFalse(registry.isFacetRegistered(address(facetE)));
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                       isSelectorRegistered
    // ═══════════════════════════════════════════════════════════════════════

    function test_isSelectorRegistered_true() public view {
        assertTrue(registry.isSelectorRegistered(MockFacetA.funcA1.selector));
    }

    function test_isSelectorRegistered_false() public view {
        assertFalse(registry.isSelectorRegistered(bytes4(0xDEADDEAD)));
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                   isSelectorRegisteredWithFacet
    // ═══════════════════════════════════════════════════════════════════════

    function test_isSelectorRegisteredWithFacet_true() public view {
        assertTrue(registry.isSelectorRegisteredWithFacet(address(facetA), MockFacetA.funcA1.selector));
    }

    function test_isSelectorRegisteredWithFacet_false_wrongFacet() public view {
        assertFalse(registry.isSelectorRegisteredWithFacet(address(facetB), MockFacetA.funcA1.selector));
    }

    function test_isSelectorRegisteredWithFacet_false_unregisteredSelector() public view {
        assertFalse(registry.isSelectorRegisteredWithFacet(address(facetA), bytes4(0xDEADDEAD)));
    }

    function test_isSelectorRegisteredWithFacet_revert_zeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_FacetAddressIsZero.selector));
        registry.isSelectorRegisteredWithFacet(address(0), MockFacetA.funcA1.selector);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                        getCurrentVersion
    // ═══════════════════════════════════════════════════════════════════════

    function test_getCurrentVersion_initial() public view {
        assertEq(registry.getCurrentVersion(), 4);
    }

    function test_getCurrentVersion_afterUpgrade() public {
        _registerModule(MODULE_1);
        _addFacetToModule(MODULE_1, address(facetE), selectorsE);
        assertEq(registry.getCurrentVersion(), 5);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                          BASE_MODULE constant
    // ═══════════════════════════════════════════════════════════════════════

    function test_BASE_MODULE_constant() public view {
        assertEq(registry.BASE_MODULE(), keccak256("BASE"));
    }
}
