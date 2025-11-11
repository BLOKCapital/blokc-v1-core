// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { BaseScript } from "script/Base.s.sol";
import { FacetRegistryBroadcaster } from "src/ccip/Hub/BaseRegistryBroadcaster.sol";

contract ArbitrumDeployment is BaseScript {
    address internal registryDeployer;

    // Arbitrum One CCIP Router address
    address constant ARBITRUM_CCIP_ROUTER = 0x141fa059441E0ca23ce184B6A78bafD2A517DdE8;

    // Base Chain Selector for CCIP
    uint64 constant BASE_CHAIN_SELECTOR = 15_971_525_489_660_198_786;

    function run() public broadcaster {
        setUp();
        registryDeployer = msg.sender;

        console.log("Deploying to Arbitrum One...");
        console.log("registryDeployer:", registryDeployer);

        // Deploy FacetRegistryBroadcaster directly (no proxy needed)
        FacetRegistryBroadcaster broadcaster = new FacetRegistryBroadcaster(
            registryDeployer, // initialOwner
            ARBITRUM_CCIP_ROUTER, // ccipRouter
            BASE_CHAIN_SELECTOR // destinationChainSelector
        );
        console.log("FacetRegistryBroadcaster:", address(broadcaster));

        console.log("Destination Chain Selector set to Base:", BASE_CHAIN_SELECTOR);

        //////////////////////////////////////////////////////////////////////////////
        console.log("FacetRegistryBroadcaster:", address(broadcaster));
        console.log("CCIP Router Used:", ARBITRUM_CCIP_ROUTER);

        console.log("Owner:", registryDeployer);

        console.log(" Deploy Base contracts using BaseDeployment.s.sol");
        console.log("Set receiver address in broadcaster using:");
        console.log("broadcaster.setReceiver(<FacetRegistryReceiver_address>)");
    }
}
