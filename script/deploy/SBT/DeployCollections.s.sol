// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import { BaddieCollection } from "src/GardenSBT/Collection/BaddieCollection.sol";
import { BuilderCollection } from "src/GardenSBT/Collection/BuilderCollection.sol";
import { GardenCollection } from "src/GardenSBT/Collection/GardenCollection.sol";

import { SBTRegistry } from "src/GardenSBT/CollectionRegistry/SBTRegistry.sol";

contract DeployCollections is Script {
    // ------------------------------
    // UPDATE BEFORE DEPLOYMENT
    // ------------------------------
    string constant BADDIE_CID = "bafybeibamcvn4b6zioon65phe56u7bpnygvmi67qv2id6be5p4ybjgynju";
    string constant BUILDER_CID = "bafybeibamcvn4b6zioon65phe56u7bpnygvmi67qv2id6be5p4ybjgynju";
    string constant GARDEN_CID = "bafybeidzu4jyntdof2mno5b3hf2cgtnj67jowdbacx7q3lfgw3y7w5teue";

    // parent-pass for gated collections (if any)
    address constant BADDIE_PASS  = 0xc826939f3C91f2491c14C1Aee7d3ACD93bDEC98d; 
    address constant BUILDER_PASS = 0xc826939f3C91f2491c14C1Aee7d3ACD93bDEC98d; 
    address constant GARDEN_PASS  = 0xc826939f3C91f2491c14C1Aee7d3ACD93bDEC98d; 

    function run() external {
        vm.startBroadcast();

        // 1. Deploy Registry (with proper gardenFactory owner)
        SBTRegistry registry = new SBTRegistry();
        console2.log("Registry deployed:", address(registry));

        // 2. Deploy each collection with correct params
        BaddieCollection baddie = new BaddieCollection(BADDIE_CID, BADDIE_PASS);
        BuilderCollection builder = new BuilderCollection(BUILDER_CID, BUILDER_PASS);
        GardenCollection garden = new GardenCollection(GARDEN_CID, GARDEN_PASS);

        console2.log("Baddie:", address(baddie));
        console2.log("Builder:", address(builder));
        console2.log("Garden:", address(garden));

        // 3. Transfer ownership to registry (REQUIRED)
        baddie.transferOwnership(address(registry));
        builder.transferOwnership(address(registry));
        garden.transferOwnership(address(registry));

        // 4. Register inside registry
        registry.registerCollection("BADDIE", address(baddie));
        registry.registerCollection("BUILDER", address(builder));
        registry.registerCollection("GARDEN", address(garden));

        vm.stopBroadcast();
    }
}
