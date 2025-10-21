//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { FacetRegistryBroadcaster } from "../../src/ccip/Hub/FacetRegistryBroadcaster.sol";

contract IncreaseGasLimit is Script {
    address constant BROADCASTER = 0x5d95017AE94397027f2fACC3Db08Ac9Ff82AC51e;
    uint256 constant NEW_GAS_LIMIT = 1500000; // 1.5M gas - should be sufficient for CCIP execution
    
    function run() external {
        console.log("=== INCREASING CCIP GAS LIMIT ===");
        console.log("Broadcaster Address:", BROADCASTER);
        console.log("Current Network: Arbitrum Mainnet");
        console.log("New Gas Limit:", NEW_GAS_LIMIT);
        console.log("");
        
        // Get private key from environment
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address signer = vm.addr(privateKey);
        console.log("Using signer:", signer);
        
        vm.startBroadcast(privateKey);
        
        FacetRegistryBroadcaster broadcaster = FacetRegistryBroadcaster(payable(BROADCASTER));
        
        // Call setGasLimit to increase gas for CCIP execution
        broadcaster.setGasLimit(NEW_GAS_LIMIT);
        
        vm.stopBroadcast();
        
        console.log("SUCCESS: Gas limit updated to", NEW_GAS_LIMIT);
        console.log("");
        console.log("=== NEXT STEPS ===");
        console.log("1. Test another CCIP broadcast");
        console.log("2. Monitor Base chain for successful execution");
        console.log("3. Check if selector mapping resolves");
        console.log("");
        console.log("The increased gas should resolve execution failures!");
    }
}