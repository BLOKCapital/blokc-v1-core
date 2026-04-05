// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { DiamondTestBase } from "../../../../../base/DiamondTestBase.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";

contract DiamondCutFacetTest is DiamondTestBase {
    address public garden;

    function setUp() public override {
        super.setUp();
        _addGardenTypeEmpty(GARDEN_TYPE_1);
        garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);
    }

    // ═════════════════════════════════════════════════════════════════
    //                     diamondCut — ALWAYS REVERTS
    // ═════════════════════════════════════════════════════════════════

    function test_diamondCut_alwaysReverts() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](0);

        vm.prank(gardenOwner);
        vm.expectRevert(abi.encodeWithSignature("DiamondCutFacet_DiamondCutNotAllowed()"));
        IDiamondCut(garden).diamondCut(cuts, address(0), "");
    }

    function test_diamondCut_revertsEvenWithValidCuts() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(stubA), action: IDiamondCut.FacetCutAction.Add, functionSelectors: selsStubA
        });

        vm.prank(gardenOwner);
        vm.expectRevert(abi.encodeWithSignature("DiamondCutFacet_DiamondCutNotAllowed()"));
        IDiamondCut(garden).diamondCut(cuts, address(0), "");
    }

    function test_diamondCut_revertsForNonOwner() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](0);

        // Non-owner should revert with access control error (before reaching the intentional revert)
        vm.prank(nonOwner);
        vm.expectRevert();
        IDiamondCut(garden).diamondCut(cuts, address(0), "");
    }
}
