//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { IFacetRegistry } from "../../src/interfaces/IFacetRegistry.sol";

contract QuickMonitor is Script {
    address constant REGISTRY = 0xf3527F208ee09da7498C7068430ce2c3F17231b5;
    bytes4 constant TEST_SELECTOR = 0xe93e98fd;
    address constant EXPECTED_FACET = 0x4200000000000000000000000000000000000006;

    function run() external view {
        console.log("=== MONITORING CCIP EXECUTION RESULT ===");
        console.log("Time:", block.timestamp);
        
        IFacetRegistry registry = IFacetRegistry(REGISTRY);
        address currentMapping = registry.getFacetAddress(TEST_SELECTOR);
        
        console.log("Current Mapping:", currentMapping);
        console.log("Expected Facet:", EXPECTED_FACET);
        
        if (currentMapping == address(0)) {
            console.log("STATUS: PENDING - Still address(0)");
            console.log("Wait more time or check if execution failed");
        } else if (currentMapping == EXPECTED_FACET) {
            console.log("STATUS: SUCCESS! - CCIP execution worked!");
        } else {
            console.log("STATUS: UNEXPECTED - Different address");
        }
    }
}

// Run with: forge script script/test/QuickMonitor.s.sol:QuickMonitor --rpc-url https://base-mainnet.public.blastapi.io