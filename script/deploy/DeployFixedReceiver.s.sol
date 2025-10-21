// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { BaseScript } from "script/Base.s.sol";
import { console } from "forge-std/console.sol";
import { FacetRegistryReceiverFixed } from "src/ccip/Spoke/FacetRegistryReceiverFixed.sol";

contract DeployFixedReceiver is BaseScript {
    
    function run() public broadcaster {
        setUp();
        
        console.log("=== Deploying FIXED Receiver with Security Improvements ===");
        console.log("Network: Base Mainnet");
        console.log("Deployer:", msg.sender);
        
        // Deploy the fixed receiver
        FacetRegistryReceiverFixed fixedReceiver = new FacetRegistryReceiverFixed();
        console.log("Fixed Receiver deployed at:", address(fixedReceiver));
        
        // Configure with the same facet registry
        address facetRegistry = 0xf3527F208ee09da7498C7068430ce2c3F17231b5;
        console.log("Configuring with facet registry:", facetRegistry);
        
        fixedReceiver.setFacetRegistry(facetRegistry);
        console.log("Facet registry configured");
        
        // Verify configuration
        address configuredRegistry = address(fixedReceiver.facetRegistry());
        console.log("Verified registry address:", configuredRegistry);
        
        if (configuredRegistry == facetRegistry) {
            console.log("SUCCESS: Fixed receiver deployed and configured");
            console.log("Key improvements:");
            console.log("1. Input validation prevents address(0) facets");
            console.log("2. Remove operations blocked via CCIP");
            console.log("3. Enhanced debug events for monitoring");
        } else {
            console.log("ERROR: Registry configuration failed");
        }
        
        console.log("Next: Update broadcaster to use:", address(fixedReceiver));
    }
}