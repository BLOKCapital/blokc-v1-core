// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.20;

import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";

import { UniswapV3Facet } from "src/diamond/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3Facet.sol";

contract ReplaceUniswapV3Facet is BaseScript {
    address constant registryProxy = 0xE011b5C63191cB238b7ed95FAd0e5945F78ef77f;

    function run() public broadcaster {
        setUp();
        bytes4[] memory uniswapFacetSelectors = new bytes4[](4);
        uniswapFacetSelectors[0] = UniswapV3Facet.swapExactInputSingleHop.selector;
        uniswapFacetSelectors[1] = UniswapV3Facet.swapExactInputMultiHop.selector;
        uniswapFacetSelectors[2] = UniswapV3Facet.getSqrtTwapX96.selector;
        uniswapFacetSelectors[3] = UniswapV3Facet.getCombinedTwapX96.selector;

        // FacetRegistry(registryProxy).removeFunctions(address(0), uniswapFacetSelectors);

        FacetRegistry(registryProxy).addFunctions(0x9F2b077F51e651392A4Bd8684294AF5fFa6305a0, uniswapFacetSelectors);
    }
}
