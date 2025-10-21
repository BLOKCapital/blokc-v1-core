// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { BaseScript } from "script/Base.s.sol";
import { console } from "forge-std/console.sol";
import { FacetRegistryReceiverDebug } from "src/ccip/Spoke/FacetRegistryReceiverDebug.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";

contract DeployDebugReceiver is BaseScript {
    
    function run() public broadcaster {
        setUp();
        
        console.log("=== Deploying Enhanced Debug Receiver ===");
        console.log("Network: Base Mainnet");
        console.log("Deployer:", msg.sender);
        
        // Deploy the debug receiver
        FacetRegistryReceiverDebug debugReceiver = new FacetRegistryReceiverDebug();
        console.log("Debug Receiver deployed at:", address(debugReceiver));
        
        // Configure with the same facet registry as the original receiver
        address facetRegistry = 0xf3527F208ee09da7498C7068430ce2c3F17231b5; // From our tests
        console.log("Configuring with facet registry:", facetRegistry);
        
        debugReceiver.setFacetRegistry(facetRegistry);
        console.log("Facet registry configured");
        
        // Verify configuration
        address configuredRegistry = address(debugReceiver.facetRegistry());
        console.log("Verified registry address:", configuredRegistry);
        
        if (configuredRegistry == facetRegistry) {
            console.log("SUCCESS: Debug receiver deployed and configured");
        } else {
            console.log("ERROR: Registry configuration failed");
        }
        
        console.log("Next step: Update broadcaster to use address:", address(debugReceiver));
    }
}