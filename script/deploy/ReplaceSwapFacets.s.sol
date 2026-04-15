//SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";
import { UniswapV3Facet } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3Facet.sol";
import { CamelotV3Facet } from "src/garden/facets/utilityFacets/arbitrumOne/camelotV3/CamelotV3Facet.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";

contract ReplaceSwapFacets is BaseScript {
    address FACET_REGISTRY_ADDRESS = 0x1e237507bb8520a253300b9e22bFccCd396E45cF;
    bytes32 constant MODULE_DEX = keccak256("DEX");

    function run() public broadcaster {
        setUp();

        IFacetRegistry registry = IFacetRegistry(FACET_REGISTRY_ADDRESS);

        // Uniswap V3
        UniswapV3Facet uniswapV3Facet = new UniswapV3Facet();
        bytes4[] memory uniswapV3Selectors = new bytes4[](4);
        uniswapV3Selectors[0] = uniswapV3Facet.uniswapV3Swap.selector;
        uniswapV3Selectors[1] = uniswapV3Facet.getSqrtTwapX96.selector;
        uniswapV3Selectors[2] = uniswapV3Facet.getCombinedTwapX96.selector;
        uniswapV3Selectors[3] = uniswapV3Facet.uniswapV3Quote.selector;
        console2.log("UniswapV3Facet deployed at:", address(uniswapV3Facet));

        // Camelot V3
        CamelotV3Facet camelotV3Facet = new CamelotV3Facet();
        bytes4[] memory camelotV3Selectors = new bytes4[](3);
        camelotV3Selectors[0] = camelotV3Facet.camelotV3Swap.selector;
        camelotV3Selectors[1] = camelotV3Facet.camelotV3GetSqrtTwapX96.selector;
        camelotV3Selectors[2] = camelotV3Facet.camelotV3Quote.selector;
        console2.log("CamelotV3Facet deployed at:", address(camelotV3Facet));

        IDiamondCut.FacetCut[] memory dexCuts = new IDiamondCut.FacetCut[](2);
        dexCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(uniswapV3Facet),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: uniswapV3Selectors
        });
        dexCuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(camelotV3Facet),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: camelotV3Selectors
        });

        if (!registry.isModuleRegistered(MODULE_DEX)) {
            registry.registerModule(MODULE_DEX);
            console2.log("DEX module registered");
        }
        registry.upgradeModule(MODULE_DEX, dexCuts);
    }
}
