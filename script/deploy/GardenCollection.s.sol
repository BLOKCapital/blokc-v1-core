//SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";
import {
    GardenCollectionFacet
} from "src/garden/facets/utilityFacets/arbitrumOne/gardenCollection/GardenCollectionFacet.sol";
import { UpgradeFacet } from "src/garden/facets/baseFacets/upgrade/UpgradeFacet.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";

contract GardenCollection is BaseScript {
    function run() public broadcaster {
        setUp();

        address facetRegistry = 0xe7973b76aF83f42C4415DF4Ef8BC24973a2dc44C;
        GardenCollectionFacet gardenCollectionFacet = new GardenCollectionFacet();
        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](1);
        bytes4[] memory gardenCollectionFacetSelectors = new bytes4[](15);
        gardenCollectionFacetSelectors[0] = GardenCollectionFacet.supportsInterface.selector;
        gardenCollectionFacetSelectors[1] = GardenCollectionFacet.balanceOf.selector;
        gardenCollectionFacetSelectors[2] = GardenCollectionFacet.ownerOf.selector;
        gardenCollectionFacetSelectors[3] = GardenCollectionFacet.approve.selector;
        gardenCollectionFacetSelectors[4] = GardenCollectionFacet.getApproved.selector;
        gardenCollectionFacetSelectors[5] = GardenCollectionFacet.setApprovalForAll.selector;
        gardenCollectionFacetSelectors[6] = GardenCollectionFacet.isApprovedForAll.selector;
        gardenCollectionFacetSelectors[7] = GardenCollectionFacet.transferFrom.selector;
        gardenCollectionFacetSelectors[8] = bytes4(keccak256("safeTransferFrom(address,address,uint256)"));
        gardenCollectionFacetSelectors[9] = bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)"));
        gardenCollectionFacetSelectors[10] = GardenCollectionFacet.name.selector;
        gardenCollectionFacetSelectors[11] = GardenCollectionFacet.symbol.selector;
        gardenCollectionFacetSelectors[12] = GardenCollectionFacet.tokenURI.selector;
        gardenCollectionFacetSelectors[13] = GardenCollectionFacet.mint.selector;
        gardenCollectionFacetSelectors[14] = GardenCollectionFacet.burn.selector;
        facetCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(gardenCollectionFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: gardenCollectionFacetSelectors
        });
        FacetRegistry(facetRegistry).upgradeFacetRegistry(facetCuts);

        address garden = 0x372BfF4709A905975AE0266b7BF493aD367B3a50;

        (,,, bytes32 hashData) = UpgradeFacet(garden).upgradeDetails();
        console2.logBytes32(hashData);
        UpgradeFacet(garden).upgrade(hashData);
    }
}
