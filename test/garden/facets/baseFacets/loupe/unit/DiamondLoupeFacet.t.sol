// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { DiamondTestBase } from "../../../../../base/DiamondTestBase.sol";
import { IDiamondLoupe } from "src/garden/facets/baseFacets/loupe/IDiamondLoupe.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";
import { IERC165 } from "src/interfaces/IERC165.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";
import { IUpgrade } from "src/garden/facets/baseFacets/upgrade/IUpgrade.sol";

contract DiamondLoupeFacetTest is DiamondTestBase {
    address public garden;
    IDiamondLoupe public loupe;

    function setUp() public override {
        super.setUp();
        _addGardenTypeEmpty(GARDEN_TYPE_1);
        garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);
        loupe = IDiamondLoupe(garden);
    }

    // ═════════════════════════════════════════════════════════════════
    //                     facets()
    // ═════════════════════════════════════════════════════════════════

    function test_facets_returnsFourBaseFacets() public view {
        IDiamondLoupe.Facet[] memory f = loupe.facets();
        assertEq(f.length, 4);
    }

    function test_facets_eachHasNonZeroAddress() public view {
        IDiamondLoupe.Facet[] memory f = loupe.facets();
        for (uint256 i = 0; i < f.length; i++) {
            assertTrue(f[i].facetAddress != address(0));
        }
    }

    function test_facets_eachHasSelectors() public view {
        IDiamondLoupe.Facet[] memory f = loupe.facets();
        for (uint256 i = 0; i < f.length; i++) {
            assertTrue(f[i].functionSelectors.length > 0);
        }
    }

    function test_facets_includesMoreAfterUpgrade() public {
        // Register module and upgrade garden
        _registerModule(MODULE_1);
        _addFacetToModule(MODULE_1, address(stubA), selsStubA);
        registry.addAllowedModule(GARDEN_TYPE_1, MODULE_1);
        _performUpgrade(garden, gardenOwner);

        IDiamondLoupe.Facet[] memory f = loupe.facets();
        assertEq(f.length, 5); // 4 base + 1 module facet
    }

    // ═════════════════════════════════════════════════════════════════
    //                     facetAddresses()
    // ═════════════════════════════════════════════════════════════════

    function test_facetAddresses_returnsFourBaseFacets() public view {
        address[] memory addrs = loupe.facetAddresses();
        assertEq(addrs.length, 4);
    }

    function test_facetAddresses_containsAllBaseFacets() public view {
        address[] memory addrs = loupe.facetAddresses();
        bool hasCut; bool hasLoupe; bool hasOwnership; bool hasUpgrade;
        for (uint256 i = 0; i < addrs.length; i++) {
            if (addrs[i] == address(diamondCutFacet)) hasCut = true;
            if (addrs[i] == address(diamondLoupeFacet)) hasLoupe = true;
            if (addrs[i] == address(ownershipFacet)) hasOwnership = true;
            if (addrs[i] == address(upgradeFacet)) hasUpgrade = true;
        }
        assertTrue(hasCut && hasLoupe && hasOwnership && hasUpgrade);
    }

    // ═════════════════════════════════════════════════════════════════
    //                     facetFunctionSelectors()
    // ═════════════════════════════════════════════════════════════════

    function test_facetFunctionSelectors_cutHasOneSelector() public view {
        bytes4[] memory sels = loupe.facetFunctionSelectors(address(diamondCutFacet));
        assertEq(sels.length, 1);
        assertEq(sels[0], IDiamondCut.diamondCut.selector);
    }

    function test_facetFunctionSelectors_loupeHasFiveSelectors() public view {
        bytes4[] memory sels = loupe.facetFunctionSelectors(address(diamondLoupeFacet));
        assertEq(sels.length, 5);
    }

    function test_facetFunctionSelectors_ownershipHasTwoSelectors() public view {
        bytes4[] memory sels = loupe.facetFunctionSelectors(address(ownershipFacet));
        assertEq(sels.length, 2);
    }

    function test_facetFunctionSelectors_upgradeHasThreeSelectors() public view {
        bytes4[] memory sels = loupe.facetFunctionSelectors(address(upgradeFacet));
        assertEq(sels.length, 3);
    }

    function test_facetFunctionSelectors_emptyForUnknownFacet() public view {
        bytes4[] memory sels = loupe.facetFunctionSelectors(address(0xDEAD));
        assertEq(sels.length, 0);
    }

    // ═════════════════════════════════════════════════════════════════
    //                     facetAddress()
    // ═════════════════════════════════════════════════════════════════

    function test_facetAddress_resolvesDiamondCut() public view {
        assertEq(loupe.facetAddress(IDiamondCut.diamondCut.selector), address(diamondCutFacet));
    }

    function test_facetAddress_resolvesOwner() public view {
        assertEq(loupe.facetAddress(IERC173.owner.selector), address(ownershipFacet));
    }

    function test_facetAddress_resolvesUpgrade() public view {
        assertEq(loupe.facetAddress(IUpgrade.upgrade.selector), address(upgradeFacet));
    }

    function test_facetAddress_returnsZeroForUnknownSelector() public view {
        assertEq(loupe.facetAddress(bytes4(0xDEADBEEF)), address(0));
    }

    // ═════════════════════════════════════════════════════════════════
    //                     supportsInterface (ERC-165)
    // ═════════════════════════════════════════════════════════════════

    function test_supportsInterface_erc165() public view {
        assertTrue(IERC165(garden).supportsInterface(type(IERC165).interfaceId));
    }

    function test_supportsInterface_diamondCut() public view {
        assertTrue(IERC165(garden).supportsInterface(type(IDiamondCut).interfaceId));
    }

    function test_supportsInterface_diamondLoupe() public view {
        assertTrue(IERC165(garden).supportsInterface(type(IDiamondLoupe).interfaceId));
    }

    function test_supportsInterface_erc173() public view {
        assertTrue(IERC165(garden).supportsInterface(type(IERC173).interfaceId));
    }

    function test_supportsInterface_upgrade() public view {
        assertTrue(IERC165(garden).supportsInterface(type(IUpgrade).interfaceId));
    }

    function test_supportsInterface_falseForUnknown() public view {
        assertFalse(IERC165(garden).supportsInterface(bytes4(0xDEADBEEF)));
    }
}
