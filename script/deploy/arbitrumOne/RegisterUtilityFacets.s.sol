// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.20;

import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";

import { BaseScript } from "../../Base.s.sol";
import { console2 } from "forge-std/console2.sol";

import { WithdrawFacet } from "src/diamond/facets/utilityFacets/arbitrumOne/WithdrawFacet.sol";
import { UniswapFacet } from "src/diamond/facets/utilityFacets/arbitrumOne/UniswapFacet.sol";
import { AaveFacet } from "src/diamond/facets/utilityFacets/arbitrumOne/AaveFacet.sol";
import { CCTPFacet } from "src/diamond/facets/utilityFacets/arbitrumOne/CCTPFacet.sol";

contract RegisterUtilityFacets is BaseScript {
    address constant registryProxy = 0xE011b5C63191cB238b7ed95FAd0e5945F78ef77f;

    function run() public broadcaster {
        setUp();
        // --- Register utility facets ---
        WithdrawFacet withdrawFacet = new WithdrawFacet();
        bytes4[] memory withdrawFacetSelectors = new bytes4[](1);
        withdrawFacetSelectors[0] = withdrawFacet.withdrawUSDC.selector;

        FacetRegistry(registryProxy).addFunctions(address(withdrawFacet), withdrawFacetSelectors);
        console2.log("WithdrawFacet deployed at:", address(withdrawFacet));

        UniswapFacet uniswapFacet = new UniswapFacet();
        bytes4[] memory uniswapFacetSelectors = new bytes4[](4);
        uniswapFacetSelectors[0] = UniswapFacet.swapExactInputSingleHop.selector;
        uniswapFacetSelectors[1] = UniswapFacet.swapExactInputMultiHop.selector;
        uniswapFacetSelectors[2] = UniswapFacet.getSqrtTwapX96.selector;
        uniswapFacetSelectors[3] = UniswapFacet.getCombinedTwapX96.selector;

        FacetRegistry(registryProxy).addFunctions(address(uniswapFacet), uniswapFacetSelectors);
        console2.log("UniswapFacet deployed at:", address(uniswapFacet));

        AaveFacet aaveFacet = new AaveFacet();
        bytes4[] memory aaveFacetSelectors = new bytes4[](3);
        aaveFacetSelectors[0] = AaveFacet.aaveReserveData.selector;
        aaveFacetSelectors[1] = AaveFacet.lendToAave.selector;
        aaveFacetSelectors[2] = AaveFacet.withdrawFromAave.selector;

        FacetRegistry(registryProxy).addFunctions(address(aaveFacet), aaveFacetSelectors);
        console2.log("AaveFacet deployed at:", address(aaveFacet));
    }
}
