//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { IFacetRegistry } from "../../src/interfaces/IFacetRegistry.sol";

contract CheckLatestRegistry is Script {
    address constant REGISTRY = 0xf3527F208ee09da7498C7068430ce2c3F17231b5;
    address constant TEST_FACET = 0x4200000000000000000000000000000000000006;
    
    // Latest test selectors
    bytes4 constant LATEST_SELECTOR = 0x12345678; // From TestReceiverV3.s.sol
    bytes4 constant ORIGINAL_SELECTOR = 0xe93e98fd; // Original working one
    
    function run() external view {
        IFacetRegistry registry = IFacetRegistry(REGISTRY);
        
        console.log("=== CHECKING LATEST REGISTRY STATE ===");
        console.log("Registry:", REGISTRY);
        console.log("Test Facet:", TEST_FACET);
        console.log("");
        
        // Check latest selector from script
        console.log("=== LATEST SELECTOR CHECK ===");
        address latestMapping = registry.getFacetAddress(LATEST_SELECTOR);
        console.log("Selector 0x12345678 maps to:", latestMapping);
        
        if (latestMapping == TEST_FACET) {
            console.log("SUCCESS: Latest selector correctly mapped!");
        } else if (latestMapping == address(0)) {
            console.log("ISSUE: Latest selector NOT in registry (address 0)");
        } else {
            console.log("UNEXPECTED: Latest selector maps to wrong address");
        }
        
        // Check original working selector
        console.log("");
        console.log("=== ORIGINAL SELECTOR CHECK ===");
        address originalMapping = registry.getFacetAddress(ORIGINAL_SELECTOR);
        console.log("Selector 0xe93e98fd maps to:", originalMapping);
        
        if (originalMapping == TEST_FACET) {
            console.log("SUCCESS: Original selector still correctly mapped!");
        } else if (originalMapping == address(0)) {
            console.log("ISSUE: Original selector lost (address 0)");
        } else {
            console.log("UNEXPECTED: Original selector maps to wrong address");
        }
        
        // Check if facet is registered at all
        console.log("");
        console.log("=== FACET REGISTRATION CHECK ===");
        bool isFacetRegistered = registry.isFacetRegistered(TEST_FACET);
        console.log("Is test facet registered:", isFacetRegistered);
        
        if (isFacetRegistered) {
            bytes4[] memory selectors = registry.getFacetFunctionSelectors(TEST_FACET);
            console.log("Number of selectors for facet:", selectors.length);
            
            for (uint i = 0; i < selectors.length; i++) {
                console.log("Selector", i, ":", vm.toString(abi.encodePacked(selectors[i])));
            }
        }
        
        console.log("");
        console.log("=== SUMMARY ===");
        if (latestMapping == TEST_FACET) {
            console.log("CCIP execution was SUCCESSFUL - registry updated!");
        } else {
            console.log("CCIP execution FAILED - registry not updated");
        }
    }
}