//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { FacetRegistryReceiverV3 } from "../../src/ccip/Spoke/FacetRegistryReceiverV3.sol";

contract DeployReceiverV3 is Script {
    function run() external {
        console.log("=== DEPLOYING IMPROVED RECEIVER V3 ===");
        console.log("Network: Base Mainnet");
        console.log("Fixing IERC165 interface support issue");
        console.log("");
        
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);
        console.log("Deployer:", deployer);
        
        vm.startBroadcast(privateKey);
        
        // Deploy improved receiver with proper IERC165 support
        FacetRegistryReceiverV3 receiverV3 = new FacetRegistryReceiverV3();
        
        // Set the facet registry
        receiverV3.setFacetRegistry(0xf3527F208ee09da7498C7068430ce2c3F17231b5);
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("SUCCESS: ReceiverV3 deployed at:", address(receiverV3));
        console.log("");
        console.log("=== IMPROVEMENTS IN V3 ===");
        console.log("1. Proper IERC165 interface support");
        console.log("2. Enhanced debug events (CCIPMessageReceived)");
        console.log("3. Better interface compliance for CCIP routers");
        console.log("");
        console.log("=== NEXT STEPS ===");
        console.log("1. Update broadcaster to use new receiver");
        console.log("2. Test CCIP message with improved receiver");
        console.log("3. Monitor for successful execution");
    }
}