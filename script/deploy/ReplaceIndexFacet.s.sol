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
        bytes4[] memory indexSelectors = new bytes4[](7);
        indexSelectors[0] = indexFacet.connectToIndex.selector;
        indexSelectors[1] = indexFacet.disconnectFromIndex.selector;
        indexSelectors[2] = indexFacet.rebalanceIntent.selector;
        indexSelectors[3] = indexFacet.rebalance.selector;
        indexSelectors[4] = indexFacet.isConnectedToIndex.selector;
        indexSelectors[5] = indexFacet.getConnectedIndex.selector;
        indexSelectors[6] = indexFacet.hasPendingIntent.selector;
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
    }
}
