//SPDX-License-Identifier: MIT License
pragma solidity ^0.8.31;

import { Script } from "forge-std/Script.sol";
import { BaseScript } from "script/Base.s.sol";
import { IndexFacet } from "src/garden/facets/indexFacets/IndexFacet.sol";
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";
import { UpgradeFacet } from "src/garden/facets/baseFacets/upgrade/UpgradeFacet.sol";
import { console2 } from "forge-std/console2.sol";

contract AddIndexFacet is BaseScript {
    function run() public broadcaster {
        setUp();
        address FACET_REGISTRY = 0x51Fb0731E6fE1F7DC520ac970A6Ef6980f70c126;

        address GARDEN_ADDRESS = 0xc1B38456bfEF0AD6c92D95d853bc97b5Af182133;

        IndexFacet indexFacet = new IndexFacet();
        bytes4[] memory indexFacetSelectors = new bytes4[](4);
        indexFacetSelectors[0] = indexFacet.connectToIndex.selector;
        indexFacetSelectors[1] = indexFacet.disconnectFromIndex.selector;
        indexFacetSelectors[2] = indexFacet.rebalance.selector;
        indexFacetSelectors[3] = indexFacet.isConnectedToIndex.selector;

        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](1);
        facetCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(indexFacet),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: indexFacetSelectors
        });

        // TODO: Update moduleId to match the appropriate module for IndexFacet
        bytes32 moduleId = keccak256("DEX");
        FacetRegistry(FACET_REGISTRY).upgradeModule(moduleId, facetCuts);
        console2.log("IndexFacet registered in FacetRegistry at:", FACET_REGISTRY);

        (, bytes32 hashData) = UpgradeFacet(GARDEN_ADDRESS).upgradeDetails();
        console2.logBytes32(hashData);
        UpgradeFacet(GARDEN_ADDRESS).upgrade(hashData);
        console2.log("IndexFacet added to Garden");
    }
}
