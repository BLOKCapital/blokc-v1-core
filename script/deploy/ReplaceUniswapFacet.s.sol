// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.31;

import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";

import { UniswapV3Facet } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3Facet.sol";

import { IndexFacet } from "src/garden/facets/indexFacets/IndexFacet.sol";
import {
    RewardCollectionFacet
} from "src/garden/facets/utilityFacets/arbitrumOne/rewardCollection/RewardCollectionFacet.sol";

import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";

contract ReplaceUniswapV3Facet is BaseScript {
    address constant REGISTRY = 0x51Fb0731E6fE1F7DC520ac970A6Ef6980f70c126;

    function run() public broadcaster {
        setUp();
        UniswapV3Facet uniswapFacet = new UniswapV3Facet();
        bytes4[] memory uniswapFacetSelectors = new bytes4[](4);
        uniswapFacetSelectors[0] = UniswapV3Facet.uniswapV3Swap.selector;
        uniswapFacetSelectors[1] = UniswapV3Facet.getSqrtTwapX96.selector;
        uniswapFacetSelectors[2] = UniswapV3Facet.getCombinedTwapX96.selector;
        uniswapFacetSelectors[3] = UniswapV3Facet.uniswapV3Quote.selector;

        IndexFacet indexFacet = new IndexFacet();
        bytes4[] memory indexFacetSelectors = new bytes4[](4);
        indexFacetSelectors[0] = indexFacet.connectToIndex.selector;
        indexFacetSelectors[1] = indexFacet.disconnectFromIndex.selector;
        indexFacetSelectors[2] = indexFacet.rebalance.selector;
        indexFacetSelectors[3] = indexFacet.isConnectedToIndex.selector;

        RewardCollectionFacet rewardCollectionFacet = new RewardCollectionFacet();
        bytes4[] memory rewardCollectionFacetSelectors = new bytes4[](8);
        rewardCollectionFacetSelectors[0] = RewardCollectionFacet.name.selector;
        rewardCollectionFacetSelectors[1] = RewardCollectionFacet.symbol.selector;
        rewardCollectionFacetSelectors[2] = RewardCollectionFacet.tokenURI.selector;
        rewardCollectionFacetSelectors[3] = RewardCollectionFacet.transferFrom.selector;
        rewardCollectionFacetSelectors[4] = RewardCollectionFacet.mint.selector;
        rewardCollectionFacetSelectors[5] = RewardCollectionFacet.burn.selector;
        rewardCollectionFacetSelectors[6] = RewardCollectionFacet.ownerOf.selector;
        rewardCollectionFacetSelectors[7] = RewardCollectionFacet.balanceOf.selector;
        console2.log("RewardCollectionFacet deployed at:", address(rewardCollectionFacet));

        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](3);
        facetCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(uniswapFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: uniswapFacetSelectors
        });
        facetCuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(indexFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: indexFacetSelectors
        });
        facetCuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(rewardCollectionFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: rewardCollectionFacetSelectors
        });

        // TODO: Update moduleId to match the appropriate module
        bytes32 moduleId = keccak256("DEX");
        FacetRegistry(REGISTRY).upgradeModule(moduleId, facetCuts);
        console2.log("UniswapV3Facet replaced");
    }
}
