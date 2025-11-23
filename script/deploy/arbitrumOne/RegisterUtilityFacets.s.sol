// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.20;

import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";

import { BaseScript } from "../../Base.s.sol";
import { console2 } from "forge-std/console2.sol";

import { WithdrawFacet } from "src/diamond/facets/utilityFacets/arbitrumOne/withdraw/WithdrawFacet.sol";
import { UniswapV3Facet } from "src/diamond/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3Facet.sol";
import { AaveV3Facet } from "src/diamond/facets/utilityFacets/arbitrumOne/aaveV3/AaveV3Facet.sol";
import { CCTPFacet } from "src/diamond/facets/utilityFacets/arbitrumOne/cctp/CCTPFacet.sol";

contract RegisterUtilityFacets is BaseScript {
    address constant registryProxy = 0x2f2Cdd5D37093fd73DfF8F9752b96e87afb47D98;

    function run() public broadcaster {
        setUp();
        // --- Register utility facets ---
        WithdrawFacet withdrawFacet = new WithdrawFacet();
        bytes4[] memory withdrawFacetSelectors = new bytes4[](1);
        withdrawFacetSelectors[0] = withdrawFacet.withdrawUSDC.selector;

        FacetRegistry(registryProxy).addFunctions(address(withdrawFacet), withdrawFacetSelectors);
        console2.log("WithdrawFacet deployed at:", address(withdrawFacet));

        UniswapV3Facet uniswapFacet = new UniswapV3Facet();
        bytes4[] memory uniswapFacetSelectors = new bytes4[](6);
        uniswapFacetSelectors[0] = UniswapV3Facet.swapExactInputSingleHop.selector;
        uniswapFacetSelectors[1] = UniswapV3Facet.swapExactInputMultiHop.selector;
        uniswapFacetSelectors[2] = UniswapV3Facet.swapExactOutputSingleHop.selector;
        uniswapFacetSelectors[3] = UniswapV3Facet.swapExactOutputMultiHop.selector;
        uniswapFacetSelectors[4] = UniswapV3Facet.getSqrtTwapX96.selector;
        uniswapFacetSelectors[5] = UniswapV3Facet.getCombinedTwapX96.selector;

        FacetRegistry(registryProxy).addFunctions(address(uniswapFacet), uniswapFacetSelectors);
        console2.log("UniswapV3Facet deployed at:", address(uniswapFacet));

        AaveV3Facet aaveFacet = new AaveV3Facet();
        bytes4[] memory aaveFacetSelectors = new bytes4[](3);
        aaveFacetSelectors[0] = AaveV3Facet.getReserveData.selector;
        aaveFacetSelectors[1] = AaveV3Facet.lend.selector;
        aaveFacetSelectors[2] = AaveV3Facet.withdraw.selector;

        FacetRegistry(registryProxy).addFunctions(address(aaveFacet), aaveFacetSelectors);
        console2.log("AaveV3Facet deployed at:", address(aaveFacet));
    }
}
