//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { FacetRegistryBroadcaster } from "../../src/ccip/Hub/FacetRegistryBroadcaster.sol";

contract UpdateToReceiverV3 is Script {
    address constant BROADCASTER = 0x5d95017AE94397027f2fACC3Db08Ac9Ff82AC51e;
    address constant NEW_RECEIVER = 0x282ce4546171A68655b385F8752F77bd8c8cAd1F;
    
    function run() external {
        console.log("=== UPDATING BROADCASTER TO RECEIVER V3 ===");
        console.log("Broadcaster:", BROADCASTER);
        console.log("New Receiver V3:", NEW_RECEIVER);
        console.log("Network: Arbitrum Mainnet");
        console.log("");
        
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address signer = vm.addr(privateKey);
        console.log("Using signer:", signer);
        
        vm.startBroadcast(privateKey);
        
        FacetRegistryBroadcaster broadcaster = FacetRegistryBroadcaster(payable(BROADCASTER));
        broadcaster.setReceiver(NEW_RECEIVER);
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("SUCCESS: Broadcaster updated to use ReceiverV3!");
        console.log("");
        console.log("=== KEY IMPROVEMENTS ===");
        console.log("1. Proper IERC165 interface support");
        console.log("2. Enhanced debug events for monitoring");
        console.log("3. Better CCIP router compatibility");
        console.log("");
        console.log("Ready for testing with fixed CCIP execution!");
    }
}