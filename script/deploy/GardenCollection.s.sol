//SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";
import {
    RewardCollectionFacet
} from "src/garden/facets/utilityFacets/arbitrumOne/rewardCollection/RewardCollectionFacet.sol";
import { UpgradeFacet } from "src/garden/facets/baseFacets/upgrade/UpgradeFacet.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";

contract RewardCollection is BaseScript {
    function run() public broadcaster {
        setUp();

        address facetRegistry = 0xe7973b76aF83f42C4415DF4Ef8BC24973a2dc44C;
        RewardCollectionFacet rewardCollectionFacet = new RewardCollectionFacet();
        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](1);
        bytes4[] memory rewardCollectionFacetSelectors = new bytes4[](15);
        rewardCollectionFacetSelectors[0] = RewardCollectionFacet.supportsInterface.selector;
        rewardCollectionFacetSelectors[1] = RewardCollectionFacet.balanceOf.selector;
        rewardCollectionFacetSelectors[2] = RewardCollectionFacet.ownerOf.selector;
        rewardCollectionFacetSelectors[3] = RewardCollectionFacet.approve.selector;
        rewardCollectionFacetSelectors[4] = RewardCollectionFacet.getApproved.selector;
        rewardCollectionFacetSelectors[5] = RewardCollectionFacet.setApprovalForAll.selector;
        rewardCollectionFacetSelectors[6] = RewardCollectionFacet.isApprovedForAll.selector;
        rewardCollectionFacetSelectors[7] = RewardCollectionFacet.transferFrom.selector;
        rewardCollectionFacetSelectors[8] = bytes4(keccak256("safeTransferFrom(address,address,uint256)"));
        rewardCollectionFacetSelectors[9] = bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)"));
        rewardCollectionFacetSelectors[10] = RewardCollectionFacet.name.selector;
        rewardCollectionFacetSelectors[11] = RewardCollectionFacet.symbol.selector;
        rewardCollectionFacetSelectors[12] = RewardCollectionFacet.tokenURI.selector;
        rewardCollectionFacetSelectors[13] = RewardCollectionFacet.mint.selector;
        rewardCollectionFacetSelectors[14] = RewardCollectionFacet.burn.selector;
        facetCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(rewardCollectionFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: rewardCollectionFacetSelectors
        });
        // TODO: Update moduleId to match the appropriate module
        bytes32 moduleId = keccak256("YIELD");
        FacetRegistry(facetRegistry).upgradeModule(moduleId, facetCuts);

        address garden = 0x372BfF4709A905975AE0266b7BF493aD367B3a50;

        (,,, bytes32 hashData) = UpgradeFacet(garden).upgradeDetails();
        console2.logBytes32(hashData);
        UpgradeFacet(garden).upgrade(hashData);
    }
}
