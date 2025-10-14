// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { FacetRegistryBroadcaster } from "src/ccip/Hub/FacetRegistryBroadcaster.sol";

contract ArbitrumDeployment is Script {
    address internal deployer;

    // Arbitrum One CCIP Router address
    address constant ARBITRUM_CCIP_ROUTER = 0x141fa059441E0ca23ce184B6A78bafD2A517DdE8;
    
    // Base Chain Selector for CCIP
    uint64 constant BASE_CHAIN_SELECTOR = 15971525489660198786;

    function run() public {
        deployer = msg.sender;
        
        console.log("Deploying to Arbitrum One...");
        console.log("Deployer:", deployer);

        // Deploy FacetRegistryBroadcaster directly (no proxy needed)
        FacetRegistryBroadcaster broadcaster = new FacetRegistryBroadcaster(
            deployer, // initialOwner
            ARBITRUM_CCIP_ROUTER, // ccipRouter
            BASE_CHAIN_SELECTOR // destinationChainSelector
        );
        console.log("FacetRegistryBroadcaster:", address(broadcaster));

        console.log("Destination Chain Selector set to Base:", BASE_CHAIN_SELECTOR);

        
      //////////////////////////////////////////////////////////////////////////////
        console.log("FacetRegistryBroadcaster:", address(broadcaster));
        console.log("CCIP Router Used:", ARBITRUM_CCIP_ROUTER);
       
        console.log("Owner:", deployer);

        console.log(" Deploy Base contracts using BaseDeployment.s.sol");
        console.log("Set receiver address in broadcaster using:");
        console.log("broadcaster.setReceiver(<FacetRegistryReceiver_address>)");
    }
}