//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { FacetRegistryBroadcaster } from "../../src/ccip/Hub/FacetRegistryBroadcaster.sol";

contract TestWithHigherGas is Script {
    address constant BROADCASTER = 0x5d95017AE94397027f2fACC3Db08Ac9Ff82AC51e;
    address constant TEST_FACET = 0x4200000000000000000000000000000000000006;
    bytes4 constant TEST_SELECTOR = 0xe93e98fd;
    
    function run() external {
        console.log("=== TESTING CCIP WITH 1.5M GAS LIMIT ===");
        console.log("Broadcaster:", BROADCASTER);
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
        
        // Broadcast facet update with new gas limit
        broadcaster.broadcastFacetUpdate(TEST_FACET, selectors, FacetRegistryBroadcaster.FacetAction.Add);
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("SUCCESS: CCIP message sent with 1.5M gas limit!");
        console.log("");
        console.log("=== MONITORING INSTRUCTIONS ===");
        console.log("1. Wait 10-20 minutes for CCIP processing");
        console.log("2. Check Base chain registry for correct mapping");
        console.log("3. The selector should now map to the facet address");
        console.log("4. If successful, the execution failure is resolved!");
    }
}