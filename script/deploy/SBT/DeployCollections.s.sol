// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { BaseScript } from "script/Base.s.sol";
import { BaddieCollection } from "src/GardenSBT/Collection/BaddieCollection.sol";
import { BuilderCollection } from "src/GardenSBT/Collection/BuilderCollection.sol";
import { GardenCollection } from "src/GardenSBT/Collection/GardenCollection.sol";

import { SBTRegistry } from "src/GardenSBT/CollectionRegistry/SBTRegistry.sol";

import { console2 } from "forge-std/console2.sol";

contract DeployCollections is BaseScript {
    // ------------------------------
    // UPDATE BEFORE DEPLOYMENT
    // ------------------------------
    string constant BADDIE_CID = "bafybeibamcvn4b6zioon65phe56u7bpnygvmi67qv2id6be5p4ybjgynju";
    string constant BUILDER_CID = "bafybeibamcvn4b6zioon65phe56u7bpnygvmi67qv2id6be5p4ybjgynju";
    string constant GARDEN_CID = "bafybeidzu4jyntdof2mno5b3hf2cgtnj67jowdbacx7q3lfgw3y7w5teue";

    // parent-pass for gated collections (if any)
    address constant BADDIE_PASS = address(0);
    address constant BUILDER_PASS = address(0);
    address constant GARDEN_PASS = address(0);

    function run() external {
        vm.startBroadcast();

        // 1. Deploy Registry (with proper gardenFactory owner)
        SBTRegistry registry = new SBTRegistry(deployer);
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
