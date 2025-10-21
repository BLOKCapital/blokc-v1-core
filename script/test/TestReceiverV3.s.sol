//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { FacetRegistryBroadcaster } from "../../src/ccip/Hub/FacetRegistryBroadcaster.sol";

contract TestReceiverV3 is Script {
    address constant BROADCASTER = 0x5d95017AE94397027f2fACC3Db08Ac9Ff82AC51e;
    address constant TEST_FACET = 0x4200000000000000000000000000000000000006;
    bytes4 constant TEST_SELECTOR = 0x12345678;
    
    function run() external {
        console.log("=== TESTING CCIP WITH RECEIVER V3 ===");
        console.log("Broadcaster:", BROADCASTER);
        console.log("New Receiver V3: 0x282ce4546171A68655b385F8752F77bd8c8cAd1F");
        console.log("Gas Limit: 1.5M");
        console.log("Test Facet:", TEST_FACET);
        console.log("Test Selector:", vm.toString(abi.encodePacked(TEST_SELECTOR)));
        console.log("");
        
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address signer = vm.addr(privateKey);
        console.log("Using signer:", signer);
        
        vm.startBroadcast(privateKey);
        
        FacetRegistryBroadcaster broadcaster = FacetRegistryBroadcaster(payable(BROADCASTER));
        
        // Create selector array
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = TEST_SELECTOR;
        
        // Broadcast facet update with ReceiverV3
        broadcaster.broadcastFacetUpdate(TEST_FACET, selectors, FacetRegistryBroadcaster.FacetAction.Add);
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("SUCCESS: CCIP message sent to ReceiverV3!");
        console.log("");
        console.log("=== EXPECTED IMPROVEMENTS ===");
        console.log("1. CCIP router should now accept the receiver");
        console.log("2. Message should execute successfully on Base");
        console.log("3. You should see CCIPMessageReceived events");
        console.log("4. Selector should map to correct facet address");
        console.log("");
        console.log("Monitor BaseScan: 0x282ce4546171A68655b385F8752F77bd8c8cAd1F");
    }
}