//SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";

import { IndexCalculationRegistry } from "src/indices/IndexCalculationRegistry.sol";
import { IndexComponentRegistry } from "src/indices/IndexComponentRegistry.sol";
import { IndexFactory } from "src/indices/IndexFactory.sol";
import { MarketCapWeightedHardcoded } from "src/indices/indexCalculations/MarketCapWeightedHardcoded.sol";

contract DeployIndex2 is BaseScript {
    function run() public broadcaster {
        setUp();

        address indexComponentRegistryAddress = 0xD8614dc6eE0230e21D591B3825a75A282EeaE2fB;
        address indexFactoryAddress = 0x37E983b2369BEE476C808696E5e9d64eA244A7A2;
        address IndexCalculationRegistryAddress = 0x35301d622E99428d6Ff6f207c4d3Bb87DEF68db3;

        IndexComponentRegistry indexComponentRegistry = IndexComponentRegistry(indexComponentRegistryAddress);
        IndexFactory indexFactory = IndexFactory(indexFactoryAddress);
        IndexCalculationRegistry indexCalculationRegistry = IndexCalculationRegistry(IndexCalculationRegistryAddress);

        MarketCapWeightedHardcoded marketCapWeightedHardcoded =
            new MarketCapWeightedHardcoded(address(indexComponentRegistry));
        console2.log("MarketCapWeightedHardcoded deployed at:", address(marketCapWeightedHardcoded));

        indexCalculationRegistry.registerIndexCalculation(address(marketCapWeightedHardcoded));

        string[] memory indexSymbols = new string[](2);
        indexSymbols[0] = "BTC";
        indexSymbols[1] = "ETH";

        address indexAddress =
            indexFactory.deployIndex("MCW_INDEX2_ETH_BTC", address(marketCapWeightedHardcoded), indexSymbols);
        console2.log("Index2 deployed at:", indexAddress);
    }
}
