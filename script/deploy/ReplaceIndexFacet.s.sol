//SPDX-License-Identifier: MIT License
pragma solidity ^0.8.31;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { BaseScript } from "script/Base.s.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";
import { IndexFacet } from "src/garden/facets/indexFacets/IndexFacet.sol";

contract ReplaceIndexFacet is BaseScript {
    bytes32 constant MODULE_INDEX = keccak256("INDEX");

    function run() public broadcaster {
        setUp();
        address FACET_REGISTRY = 0x1e237507bb8520a253300b9e22bFccCd396E45cF;
        IFacetRegistry registry = IFacetRegistry(FACET_REGISTRY);

        IndexFacet indexFacet = new IndexFacet();
        bytes4[] memory indexSelectors = new bytes4[](8);
        indexSelectors[0] = indexFacet.configureIndexModule.selector;
        indexSelectors[1] = indexFacet.connectToIndex.selector;
        indexSelectors[2] = indexFacet.disconnectFromIndex.selector;
        indexSelectors[3] = indexFacet.rebalanceIntent.selector;
        indexSelectors[4] = indexFacet.rebalance.selector;
        indexSelectors[5] = indexFacet.isConnectedToIndex.selector;
        indexSelectors[6] = indexFacet.getConnectedIndex.selector;
        indexSelectors[7] = indexFacet.hasPendingIntent.selector;
        console2.log("IndexFacet deployed at:", address(indexFacet));

        IDiamondCut.FacetCut[] memory indexCuts = new IDiamondCut.FacetCut[](1);
        indexCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(indexFacet),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: indexSelectors
        });

        if (!registry.isModuleRegistered(MODULE_INDEX)) {
            registry.registerModule(MODULE_INDEX);
            console2.log("INDEX module registered");
        }
        registry.upgradeModule(MODULE_INDEX, indexCuts);
        console2.log("INDEX module upgraded with IndexFacet");

        // Point the upgraded diamonds at the protocol components. The IndexFacet no longer
        // carries compile-time registry addresses — each garden diamond stores them in
        // IndexStorage.Layout, set here by the owner (this call is per-garden: run it for
        // every INDEX-type garden, as its owner).
        //   IndexFactory(0x91da26...), IndexComponentRegistry(0x3F8291...), LiquidityPoolRegistry(0xA31782...)
        // console2.log("Call configureIndexModule(indexFactory, indexComponentRegistry, poolRegistry) on each INDEX
        // garden");
    }
}
