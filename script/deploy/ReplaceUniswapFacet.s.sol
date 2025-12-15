// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.31;

import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";

import { UniswapV3Facet } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3Facet.sol";

import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";

contract ReplaceUniswapV3Facet is BaseScript {
    address constant REGISTRY = 0x7aC04e3ED7e529B852d9963494D6d176B1068546;

    function run() public broadcaster {
        setUp();
        UniswapV3Facet uniswapFacet = new UniswapV3Facet();
        bytes4[] memory uniswapFacetSelectors = new bytes4[](4);
        uniswapFacetSelectors[0] = UniswapV3Facet.uniswapV3ExactInputSingle.selector;
        uniswapFacetSelectors[1] = UniswapV3Facet.uniswapV3ExactInput.selector;
        uniswapFacetSelectors[2] = UniswapV3Facet.uniswapV3ExactOutputSingle.selector;
        uniswapFacetSelectors[3] = UniswapV3Facet.uniswapV3ExactOutput.selector;

        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](1);
        facetCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(uniswapFacet),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: uniswapFacetSelectors
        });

        FacetRegistry(REGISTRY).upgradeFacetRegistry(facetCuts);
        console2.log("UniswapV3Facet replaced");
    }
}
