// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.31;

import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";

import { IndexFacet } from "src/garden/facets/indexFacets/IndexFacet.sol";

import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";

contract RegisterUtilityFacets is BaseScript {
    address constant FACET_REGISTRY = 0x51F061273398b93369F3C99520813656c779f293;

    // Module IDs
    bytes32 constant MODULE_INDEX = keccak256("INDEX");

    function run() public broadcaster {
        setUp();

        IFacetRegistry registry = IFacetRegistry(FACET_REGISTRY);

        // =====================================================================
        // INDEX module (IndexFacet)
        // =====================================================================
        IndexFacet indexFacet = new IndexFacet();
        bytes4[] memory indexSelectors = new bytes4[](6);
        indexSelectors[0] = indexFacet.connectToIndex.selector;
        indexSelectors[1] = indexFacet.disconnectFromIndex.selector;
        indexSelectors[2] = indexFacet.rebalance.selector;
        indexSelectors[3] = indexFacet.isConnectedToIndex.selector;
        indexSelectors[4] = indexFacet.getConnectedIndex.selector;
        indexSelectors[5] = indexFacet.getLastRebalanceTimestamp.selector;
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
