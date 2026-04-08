// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";
import { IndexCalculationRegistry } from "src/indices/IndexCalculationRegistry.sol";
import { IndexComponentRegistry } from "src/indices/IndexComponentRegistry.sol";
import { IndexFactory } from "src/indices/IndexFactory.sol";
import { MarketCapWeightedBlokc5Hardcoded } from "src/indices/indexCalculations/MarketCapWeightedBlokc5Hardcoded.sol";

contract DeployBlokc5Index is BaseScript {
    // Update these addresses from your existing deployment
    address indexComponentRegistryAddress = 0x361EC253B0055623544f218AD6AF06253A212374;
    address indexFactoryAddress = 0x983dC1CC4A089e8537C8EeA42eedEd0B2bC73152;
    address indexCalculationRegistryAddress = 0x7556E83147B4c29fC0E17ff2d96e6aB0Ac23e056;

    function run() public broadcaster {
        setUp();

        IndexComponentRegistry indexComponentRegistry = IndexComponentRegistry(indexComponentRegistryAddress);
        IndexFactory indexFactory = IndexFactory(indexFactoryAddress);
        IndexCalculationRegistry indexCalculationRegistry = IndexCalculationRegistry(indexCalculationRegistryAddress);

        // Deploy MarketCapWeightedBlokc5Hardcoded calculation strategy
        MarketCapWeightedBlokc5Hardcoded blokc5Calculation =
            new MarketCapWeightedBlokc5Hardcoded(address(indexComponentRegistry));
        console2.log("MarketCapWeightedBlokc5Hardcoded deployed at:", address(blokc5Calculation));

        // Register the calculation strategy
        indexCalculationRegistry.registerIndexCalculation(address(blokc5Calculation));

        // Define the 5 index components
        string[] memory indexSymbols = new string[](5);
        indexSymbols[0] = "BTC";
        indexSymbols[1] = "ETH";
        indexSymbols[2] = "LINK";
        indexSymbols[3] = "UNI";
        indexSymbols[4] = "ARB";

        // Deploy the BLOKC-5 index
        address indexAddress = indexFactory.deployIndex("BLOKC5_MCW_INDEX", address(blokc5Calculation), indexSymbols);
        console2.log("BLOKC-5 Index deployed at:", indexAddress);
    }
}
