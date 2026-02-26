// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";

import { IndexFacet } from "src/garden/facets/indexFacets/IndexFacet.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";


contract RegisterIndexFacet is BaseScript {
    address constant FACET_REGISTRY = 0xf56e5573210Eaec46E29B4C5B9F8670b76730b6b;

    // Module IDs
    bytes32 constant MODULE_INDEX = keccak256("INDEX");

    // Garden type IDs
    bytes32 constant INDEX_GARDEN = keccak256("INDEX");

        function run() public broadcaster {
        setUp();

        FacetRegistry registry = FacetRegistry(FACET_REGISTRY);

        // =====================================================================
        // INDEX module (IndexFacet)
        // =====================================================================
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
            facetAddress: address(indexFacet), action: IDiamondCut.FacetCutAction.Add, functionSelectors:
        indexSelectors });

        if (!registry.isModuleRegistered(MODULE_INDEX)) {
            registry.registerModule(MODULE_INDEX);
            console2.log("INDEX module registered");
        }
        registry.upgradeModule(MODULE_INDEX, indexCuts);
        console2.log("INDEX module upgraded with IndexFacet");

        // =====================================================================
        // Garden types
        // =====================================================================
        // INDEX_GARDEN allowed modules: BASE (implicit), DEX_MODULE, WITHDRAW_MODULE, INDEX_MODULE
        if (!registry.isGardenTypeRegistered(INDEX_GARDEN)) {
            bytes32[] memory indexGardenModules = new bytes32[](3);
            indexGardenModules[0] = MODULE_DEX;
            indexGardenModules[1] = MODULE_WITHDRAW;
            indexGardenModules[2] = MODULE_INDEX;
            registry.addGardenType(INDEX_GARDEN, indexGardenModules);
            console2.log("INDEX_GARDEN type registered");
        }
    }
}