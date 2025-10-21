//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { FacetRegistryBroadcaster } from "../../src/ccip/Hub/FacetRegistryBroadcaster.sol";

contract IncreaseGasToMax is Script {
    address constant BROADCASTER = 0x5d95017AE94397027f2fACC3Db08Ac9Ff82AC51e;
    uint256 constant MAX_GAS_LIMIT = 2000000; // 2M gas (maximum allowed)
    
    function run() external {
        console.log("=== INCREASING GAS TO MAXIMUM ===");
        console.log("Broadcaster:", BROADCASTER);
        console.log("New Gas Limit:", MAX_GAS_LIMIT, "(2M - Maximum)");
        console.log("Previous:", "1.5M");
        console.log("");
        
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address signer = vm.addr(privateKey);
        console.log("Using signer:", signer);
        
        vm.startBroadcast(privateKey);
        
        FacetRegistryBroadcaster broadcaster = FacetRegistryBroadcaster(payable(BROADCASTER));
        broadcaster.setGasLimit(MAX_GAS_LIMIT);
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("SUCCESS: Gas limit set to maximum 2M!");
        console.log("This should resolve any remaining gas issues.");
    }
}