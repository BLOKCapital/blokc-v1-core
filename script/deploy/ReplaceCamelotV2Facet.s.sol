//SPDX-License-Identifier: MIT License
pragma solidity ^0.8.31;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { BaseScript } from "script/Base.s.sol";
import { CamelotV2Facet } from "src/garden/facets/utilityFacets/arbitrumOne/camelotV2/CamelotV2Facet.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";

contract ReplaceCamelotV2Facet is BaseScript {
    bytes32 constant MODULE_DEX = keccak256("DEX");

    function run() public broadcaster {
        setUp();
        address FACET_REGISTRY = 0x1e237507bb8520a253300b9e22bFccCd396E45cF;
        IFacetRegistry registry = IFacetRegistry(FACET_REGISTRY);

        CamelotV2Facet camelotV2Facet = new CamelotV2Facet();
        bytes4[] memory camelotV2Selectors = new bytes4[](2);
        camelotV2Selectors[0] = camelotV2Facet.camelotV2Swap.selector;
        camelotV2Selectors[1] = camelotV2Facet.camelotV2Quote.selector;
        console2.log("CamelotV2Facet deployed at:", address(camelotV2Facet));

        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](1);
        facetCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(camelotV2Facet),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: camelotV2Selectors
        });

        if (!registry.isModuleRegistered(MODULE_DEX)) {
            registry.registerModule(MODULE_DEX);
            console2.log("DEX module registered");
        }
        registry.upgradeModule(MODULE_DEX, facetCuts);
        console2.log("DEX module upgraded with CamelotV2 facet");
    }
}
