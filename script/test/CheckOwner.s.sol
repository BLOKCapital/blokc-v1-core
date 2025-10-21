//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { FacetRegistryBroadcaster } from "../../src/ccip/Hub/FacetRegistryBroadcaster.sol";

contract CheckOwner is Script {
    address constant BROADCASTER = 0x5d95017AE94397027f2fACC3Db08Ac9Ff82AC51e;
    
    function run() external view {
        console.log("=== CHECKING BROADCASTER OWNER ===");
        console.log("Broadcaster Address:", BROADCASTER);
        
        FacetRegistryBroadcaster broadcaster = FacetRegistryBroadcaster(payable(BROADCASTER));
        address owner = broadcaster.owner();
        
        console.log("Current Owner:", owner);
        console.log("");
        console.log("You need to use this owner's private key to call setGasLimit");
    }
}