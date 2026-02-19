// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import {
    FacetRegistryTestBase,
    MockFacetA,
    MockFacetB,
    MockFacetC,
    MockFacetD
} from "../FacetRegistryTestBase.sol";
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";

import {
    FacetRegistry_IncorrectBaseFacetsLength,
    FacetRegistry_BaseFacetAddressIsZero,
    FacetRegistry_DuplicateBaseFacetAddress,
    FacetRegistry_BaseFacetSelectorsEmpty,
    FacetRegistry_FacetIsNotContract,
    FacetRegistry_CannotAddFunctionThatAlreadyExists
} from "src/facetRegistry/FacetRegistry.sol";

contract ConstructorTest is FacetRegistryTestBase {
    // ─── Success Cases ──────────────────────────────────────────────────

    function test_constructor_setsOwner() public view {
        assertEq(registry.owner(), owner);
    }

    function test_constructor_registersBaseModule() public view {
        assertTrue(registry.isModuleRegistered(BASE_MODULE));
    }

    function test_constructor_baseModuleIsFirstModuleId() public view {
        bytes32[] memory moduleIds = registry.getAllModuleIds();
        assertEq(moduleIds.length, 1);
        assertEq(moduleIds[0], BASE_MODULE);
    }

    function test_constructor_setsBaseFacets() public view {
        address[4] memory baseFacets = registry.getBaseFacets();
        assertEq(baseFacets[0], address(facetA));
        assertEq(baseFacets[1], address(facetB));
        assertEq(baseFacets[2], address(facetC));
        assertEq(baseFacets[3], address(facetD));
    }

    function test_constructor_registersAllFacets() public view {
        address[] memory facetAddresses = registry.getFacetAddresses();
        assertEq(facetAddresses.length, 4);
    }

    function test_constructor_registersFacetSelectors() public view {
        bytes4[] memory selsA = registry.getFacetFunctionSelectors(address(facetA));
        assertEq(selsA.length, 2);
        assertEq(selsA[0], MockFacetA.funcA1.selector);
        assertEq(selsA[1], MockFacetA.funcA2.selector);
    }

    function test_constructor_setsGlobalVersion() public view {
        // 4 base facets = 4 version increments
        assertEq(registry.getCurrentVersion(), 4);
    }

    function test_constructor_setsBaseModuleVersion() public view {
        assertEq(registry.getModuleVersion(BASE_MODULE), 4);
    }

    function test_constructor_baseFacetsBelongToBaseModule() public view {
        assertEq(registry.getFacetModule(address(facetA)), BASE_MODULE);
        assertEq(registry.getFacetModule(address(facetB)), BASE_MODULE);
        assertEq(registry.getFacetModule(address(facetC)), BASE_MODULE);
        assertEq(registry.getFacetModule(address(facetD)), BASE_MODULE);
    }

    function test_constructor_baseFacetsInBaseModuleAddresses() public view {
        address[] memory moduleAddrs = registry.getModuleFacetAddresses(BASE_MODULE);
        assertEq(moduleAddrs.length, 4);
        assertEq(moduleAddrs[0], address(facetA));
        assertEq(moduleAddrs[1], address(facetB));
        assertEq(moduleAddrs[2], address(facetC));
        assertEq(moduleAddrs[3], address(facetD));
    }

    function test_constructor_selectorToFacetMapping() public view {
        assertEq(registry.getFacetAddress(MockFacetA.funcA1.selector), address(facetA));
        assertEq(registry.getFacetAddress(MockFacetA.funcA2.selector), address(facetA));
        assertEq(registry.getFacetAddress(MockFacetB.funcB1.selector), address(facetB));
    }

    function test_constructor_facetCutHistory() public view {
        IDiamondCut.FacetCut[] memory cuts = registry.getFacetCutsByVersionRange(1, 4);
        assertEq(cuts.length, 4);

        assertEq(cuts[0].facetAddress, address(facetA));
        assertEq(uint8(cuts[0].action), uint8(IDiamondCut.FacetCutAction.Add));
        assertEq(cuts[0].functionSelectors.length, 2);

        assertEq(cuts[3].facetAddress, address(facetD));
    }

    function test_constructor_moduleFacetCutHistory() public view {
        IDiamondCut.FacetCut[] memory cuts = registry.getModuleFacetCutsByVersionRange(BASE_MODULE, 1, 4);
        assertEq(cuts.length, 4);
        assertEq(cuts[0].facetAddress, address(facetA));
        assertEq(cuts[3].facetAddress, address(facetD));
    }

    function test_constructor_allSelectorsRegistered() public view {
        assertTrue(registry.isSelectorRegistered(MockFacetA.funcA1.selector));
        assertTrue(registry.isSelectorRegistered(MockFacetA.funcA2.selector));
        assertTrue(registry.isSelectorRegistered(MockFacetB.funcB1.selector));
        assertTrue(registry.isSelectorRegistered(MockFacetB.funcB2.selector));
        assertTrue(registry.isSelectorRegistered(MockFacetC.funcC1.selector));
        assertTrue(registry.isSelectorRegistered(MockFacetC.funcC2.selector));
        assertTrue(registry.isSelectorRegistered(MockFacetD.funcD1.selector));
        assertTrue(registry.isSelectorRegistered(MockFacetD.funcD2.selector));
    }

    function test_constructor_allFacetsRegistered() public view {
        assertTrue(registry.isFacetRegistered(address(facetA)));
        assertTrue(registry.isFacetRegistered(address(facetB)));
        assertTrue(registry.isFacetRegistered(address(facetC)));
        assertTrue(registry.isFacetRegistered(address(facetD)));
    }

    // ─── Revert Cases ───────────────────────────────────────────────────

    function test_constructor_revert_incorrectSelectorArrayLength() public {
        address[4] memory baseFacets =
            [address(facetA), address(facetB), address(facetC), address(facetD)];

        bytes4[][] memory sels = new bytes4[][](3); // wrong length
        sels[0] = selectorsA;
        sels[1] = selectorsB;
        sels[2] = selectorsC;

        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_IncorrectBaseFacetsLength.selector, 3));
        new FacetRegistry(owner, baseFacets, sels);
    }

    function test_constructor_revert_zeroAddressBaseFacet() public {
        address[4] memory baseFacets =
            [address(0), address(facetB), address(facetC), address(facetD)];

        bytes4[][] memory sels = new bytes4[][](4);
        sels[0] = selectorsA;
        sels[1] = selectorsB;
        sels[2] = selectorsC;
        sels[3] = selectorsD;

        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_BaseFacetAddressIsZero.selector, address(0)));
        new FacetRegistry(owner, baseFacets, sels);
    }

    function test_constructor_revert_zeroAddressBaseFacet_middlePosition() public {
        address[4] memory baseFacets =
            [address(facetA), address(facetB), address(0), address(facetD)];

        bytes4[][] memory sels = new bytes4[][](4);
        sels[0] = selectorsA;
        sels[1] = selectorsB;
        sels[2] = selectorsC;
        sels[3] = selectorsD;

        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_BaseFacetAddressIsZero.selector, address(0)));
        new FacetRegistry(owner, baseFacets, sels);
    }

    function test_constructor_revert_duplicateBaseFacets() public {
        address[4] memory baseFacets =
            [address(facetA), address(facetA), address(facetC), address(facetD)];

        bytes4[][] memory sels = new bytes4[][](4);
        sels[0] = selectorsA;
        sels[1] = selectorsB;
        sels[2] = selectorsC;
        sels[3] = selectorsD;

        vm.expectRevert(
            abi.encodeWithSelector(FacetRegistry_DuplicateBaseFacetAddress.selector, address(facetA))
        );
        new FacetRegistry(owner, baseFacets, sels);
    }

    function test_constructor_revert_duplicateBaseFacets_nonAdjacent() public {
        address[4] memory baseFacets =
            [address(facetA), address(facetB), address(facetC), address(facetA)];

        bytes4[][] memory sels = new bytes4[][](4);
        sels[0] = selectorsA;
        sels[1] = selectorsB;
        sels[2] = selectorsC;
        sels[3] = selectorsD;

        vm.expectRevert(
            abi.encodeWithSelector(FacetRegistry_DuplicateBaseFacetAddress.selector, address(facetA))
        );
        new FacetRegistry(owner, baseFacets, sels);
    }

    function test_constructor_revert_emptySelectorsForBaseFacet() public {
        address[4] memory baseFacets =
            [address(facetA), address(facetB), address(facetC), address(facetD)];

        bytes4[][] memory sels = new bytes4[][](4);
        sels[0] = selectorsA;
        sels[1] = new bytes4[](0); // empty
        sels[2] = selectorsC;
        sels[3] = selectorsD;

        vm.expectRevert(
            abi.encodeWithSelector(FacetRegistry_BaseFacetSelectorsEmpty.selector, address(facetB))
        );
        new FacetRegistry(owner, baseFacets, sels);
    }

    function test_constructor_revert_facetIsNotContract() public {
        address notAContract = address(0x1234);
        address[4] memory baseFacets =
            [notAContract, address(facetB), address(facetC), address(facetD)];

        bytes4[][] memory sels = new bytes4[][](4);
        sels[0] = selectorsA;
        sels[1] = selectorsB;
        sels[2] = selectorsC;
        sels[3] = selectorsD;

        vm.expectRevert(
            abi.encodeWithSelector(FacetRegistry_FacetIsNotContract.selector, notAContract)
        );
        new FacetRegistry(owner, baseFacets, sels);
    }

    function test_constructor_revert_duplicateSelectorsAcrossBaseFacets() public {
        address[4] memory baseFacets =
            [address(facetA), address(facetB), address(facetC), address(facetD)];

        bytes4[][] memory sels = new bytes4[][](4);
        sels[0] = selectorsA;
        sels[1] = selectorsA; // duplicate selectors from facetA
        sels[2] = selectorsC;
        sels[3] = selectorsD;

        vm.expectRevert(
            abi.encodeWithSelector(
                FacetRegistry_CannotAddFunctionThatAlreadyExists.selector, selectorsA[0]
            )
        );
        new FacetRegistry(owner, baseFacets, sels);
    }

    function test_constructor_getFacets_returnsAllBaseInfo() public view {
        IFacetRegistry.Facet[] memory facets = registry.getFacets();
        assertEq(facets.length, 4);
        for (uint256 i = 0; i < 4; i++) {
            assertEq(facets[i].functionSelectors.length, 2);
        }
    }
}
