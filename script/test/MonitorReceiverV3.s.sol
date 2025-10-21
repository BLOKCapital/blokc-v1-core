//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { IFacetRegistry } from "../../src/interfaces/IFacetRegistry.sol";

contract MonitorReceiverV3 is Script {
    address constant REGISTRY = 0xf3527F208ee09da7498C7068430ce2c3F17231b5;
    address constant NEW_RECEIVER = 0x282ce4546171A68655b385F8752F77bd8c8cAd1F;
    bytes4 constant TEST_SELECTOR = 0xe93e98fd;
    address constant EXPECTED_FACET = 0x4200000000000000000000000000000000000006;

    function run() external view {
        console.log("=== MONITORING RECEIVER V3 RESULTS ===");
        console.log("New Receiver V3:", NEW_RECEIVER);
        console.log("Time:", block.timestamp);
        console.log("");
        
        IFacetRegistry registry = IFacetRegistry(REGISTRY);
        address currentMapping = registry.getFacetAddress(TEST_SELECTOR);
        
        console.log("Current Mapping:", currentMapping);
        console.log("Expected Facet:", EXPECTED_FACET);
        
        if (currentMapping == address(0)) {
            console.log("STATUS: PENDING - Still address(0)");
            console.log("Check BaseScan for ReceiverV3 events");
        } else if (currentMapping == EXPECTED_FACET) {
            console.log("STATUS: SUCCESS! - IERC165 fix worked!");
            console.log("CCIP execution is now working properly!");
        } else {
            console.log("STATUS: UNEXPECTED - Different address");
        }
        
        console.log("");
        console.log("Monitor BaseScan:");
        console.log("Address:", NEW_RECEIVER);
        console.log("Look for: CCIPMessageReceived, FacetUpdateReceived");
    }
}

// Run with: forge script script/test/MonitorReceiverV3.s.sol:MonitorReceiverV3 --rpc-url https://mainnet.base.org