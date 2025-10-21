//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { IFacetRegistry } from "../../src/interfaces/IFacetRegistry.sol";
import { FacetRegistryReceiverFixed } from "../../src/ccip/Spoke/FacetRegistryReceiverFixed.sol";

contract DeepDebug is Script {
    address constant REGISTRY = 0xf3527F208ee09da7498C7068430ce2c3F17231b5;
    address constant RECEIVER_FIXED = 0x6e22496823F243693cD5718dd8EC0bf531968574;
    address constant BASE_CCIP_ROUTER = 0x881e3A65B4d4a04dD529061dd0071cf975F58bCD;
    bytes4 constant TEST_SELECTOR = 0xe93e98fd;
    address constant EXPECTED_FACET = 0x4200000000000000000000000000000000000006;

    function run() external view {
        console.log("=== DEEP CCIP EXECUTION DEBUG ===");
        console.log("Timestamp:", block.timestamp);
        console.log("");
        
        IFacetRegistry registry = IFacetRegistry(REGISTRY);
        FacetRegistryReceiverFixed receiver = FacetRegistryReceiverFixed(RECEIVER_FIXED);
        
        // 1. Check Registry State
        console.log("=== 1. REGISTRY STATE ===");
        address currentMapping = registry.getFacetAddress(TEST_SELECTOR);
        console.log("Current mapping:", currentMapping);
        console.log("Expected facet:", EXPECTED_FACET);
        console.log("Is address(0):", currentMapping == address(0));
        
        // 2. Check Receiver Configuration
        console.log("\n=== 2. RECEIVER CONFIGURATION ===");
        address receiverRegistry = address(receiver.facetRegistry());
        address receiverRouter = receiver.getRouter();
        console.log("Receiver registry:", receiverRegistry);
        console.log("Expected registry:", REGISTRY);
        console.log("Registry match:", receiverRegistry == REGISTRY);
        console.log("Receiver router:", receiverRouter);
        console.log("Expected router:", BASE_CCIP_ROUTER);
        console.log("Router match:", receiverRouter == BASE_CCIP_ROUTER);
        
        // 3. Check Interface Support
        console.log("\n=== 3. INTERFACE SUPPORT ===");
        bool supportsIAny2EVM = receiver.supportsInterface(0x85572ffb);
        bool supportsIERC165 = receiver.supportsInterface(0x01ffc9a7);
        console.log("IAny2EVMMessageReceiver:", supportsIAny2EVM);
        console.log("IERC165:", supportsIERC165);
        
        // 4. Check Recent Events (we need to look at BaseScan for this)
        console.log("\n=== 4. DIAGNOSTIC SUMMARY ===");
        if (currentMapping == address(0)) {
            console.log("ISSUE: Selector still maps to address(0)");
            console.log("");
            console.log("POSSIBLE CAUSES:");
            console.log("1. CCIP message never reached receiver");
            console.log("2. Receiver execution reverted silently");
            console.log("3. Registry operation failed");
            console.log("4. Message decoding corruption");
            console.log("5. Access control issues");
            console.log("");
            console.log("NEXT DEBUGGING STEPS:");
            console.log("1. Check BaseScan for receiver transactions");
            console.log("2. Look for CCIPDebugInfo events");
            console.log("3. Check for failed transactions to receiver");
            console.log("4. Verify CCIP message ID on Chainlink Explorer");
        } else if (currentMapping == EXPECTED_FACET) {
            console.log("SUCCESS: Mapping is correct!");
        } else {
            console.log("UNEXPECTED: Mapping to different address");
        }
        
        console.log("\n=== 5. BASESCAN INVESTIGATION ===");
        console.log("Check BaseScan for:");
        console.log("Address:", RECEIVER_FIXED);
        console.log("Look for transactions from CCIP router");
        console.log("Search for events: CCIPDebugInfo, FacetUpdateReceived");
        console.log("Time window: Last 30 minutes");
    }
}