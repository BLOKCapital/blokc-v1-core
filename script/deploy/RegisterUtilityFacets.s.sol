// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.31;

import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";

import { WithdrawFacet } from "src/garden/facets/utilityFacets/arbitrumOne/withdraw/WithdrawFacet.sol";
import { UniswapV3Facet } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3Facet.sol";
import { AaveV3Facet } from "src/garden/facets/utilityFacets/arbitrumOne/aaveV3/AaveV3Facet.sol";
import {
    GardenCollectionFacet
} from "src/garden/facets/utilityFacets/arbitrumOne/gardenCollection/GardenCollectionFacet.sol";

import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";

contract RegisterUtilityFacets is BaseScript {
    address constant FACET_REGISTRY = 0x5fe7C66E3B8979175fA26cC88AD2f52a10A96162;

    function run() public broadcaster {
        setUp();
        // --- Register utility facets ---
        WithdrawFacet withdrawFacet = new WithdrawFacet();
        bytes4[] memory withdrawFacetSelectors = new bytes4[](1);
        withdrawFacetSelectors[0] = withdrawFacet.withdrawUsdc.selector;

        console2.log("WithdrawFacet deployed at:", address(withdrawFacet));

        UniswapV3Facet uniswapFacet = new UniswapV3Facet();
        bytes4[] memory uniswapFacetSelectors = new bytes4[](6);
        uniswapFacetSelectors[0] = UniswapV3Facet.uniswapV3ExactInputSingle.selector;
        uniswapFacetSelectors[1] = UniswapV3Facet.uniswapV3ExactInput.selector;
        uniswapFacetSelectors[2] = UniswapV3Facet.uniswapV3ExactOutputSingle.selector;
        uniswapFacetSelectors[3] = UniswapV3Facet.uniswapV3ExactOutput.selector;
        uniswapFacetSelectors[4] = UniswapV3Facet.getSqrtTwapX96.selector;
        uniswapFacetSelectors[5] = UniswapV3Facet.getCombinedTwapX96.selector;

        console2.log("UniswapV3Facet deployed at:", address(uniswapFacet));

        AaveV3Facet aaveFacet = new AaveV3Facet();
        bytes4[] memory aaveFacetSelectors = new bytes4[](3);
        aaveFacetSelectors[0] = AaveV3Facet.getReserveData.selector;
        aaveFacetSelectors[1] = AaveV3Facet.lend.selector;
        aaveFacetSelectors[2] = AaveV3Facet.withdraw.selector;

        console2.log("AaveV3Facet deployed at:", address(aaveFacet));

        GardenCollectionFacet gardenCollectionFacet = new GardenCollectionFacet();
        bytes4[] memory gardenCollectionFacetSelectors = new bytes4[](8);
        gardenCollectionFacetSelectors[0] = GardenCollectionFacet.name.selector;
        gardenCollectionFacetSelectors[1] = GardenCollectionFacet.symbol.selector;
        gardenCollectionFacetSelectors[2] = GardenCollectionFacet.tokenURI.selector;
        gardenCollectionFacetSelectors[3] = GardenCollectionFacet.transferFrom.selector;
        gardenCollectionFacetSelectors[4] = GardenCollectionFacet.mint.selector;
        gardenCollectionFacetSelectors[5] = GardenCollectionFacet.burn.selector;
        gardenCollectionFacetSelectors[6] = GardenCollectionFacet.ownerOf.selector;
        gardenCollectionFacetSelectors[7] = GardenCollectionFacet.balanceOf.selector;
        console2.log("GardenCollectionFacet deployed at:", address(gardenCollectionFacet));

        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](4);
        facetCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(withdrawFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: withdrawFacetSelectors
        });
        facetCuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(uniswapFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: uniswapFacetSelectors
        });
        facetCuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(aaveFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: aaveFacetSelectors
        });
        facetCuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(gardenCollectionFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: gardenCollectionFacetSelectors
        });

        FacetRegistry(FACET_REGISTRY).upgradeFacetRegistry(facetCuts);
        console2.log("Utility facets registered");
    }
}
