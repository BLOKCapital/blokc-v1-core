// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";
import { IndexCalculationRegistry } from "src/indices/IndexCalculationRegistry.sol";
import { IndexComponentRegistry } from "src/indices/IndexComponentRegistry.sol";
import { IndexFactory } from "src/indices/IndexFactory.sol";
import { Index } from "src/indices/Index.sol";
import { MarketCapWeighted } from "src/indices/indexCalculations/MarketCapWeighted.sol";

contract DeployIndex is BaseScript {
    function run() public broadcaster {
        setUp();
        IndexComponentRegistry indexComponentRegistry = new IndexComponentRegistry(deployer);
        console2.log("IndexComponentRegistry deployed at:", address(indexComponentRegistry));
        address[] memory componentAddresses = new address[](5);
        address[] memory priceFeedAddresses = new address[](5);
        string[] memory symbols = new string[](5);
        symbols[0] = "BTC";
        componentAddresses[0] = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
        priceFeedAddresses[0] = 0x6ce185860a4963106506C203335A2910413708e9;

        symbols[1] = "ETH";
        componentAddresses[1] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        priceFeedAddresses[1] = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;

        symbols[2] = "USDC";
        componentAddresses[2] = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
        priceFeedAddresses[2] = 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3;

        symbols[3] = "LINK";
        componentAddresses[3] = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
        priceFeedAddresses[3] = 0x86E53CF1B870786351Da77A57575e79CB55812CB;

        symbols[4] = "UNI";
        componentAddresses[4] = 0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0;
        priceFeedAddresses[4] = 0x9C917083fDb403ab5ADbEC26Ee294f6EcAda2720;

        symbols[5] = "AAVE";
        componentAddresses[5] = 0xba5DdD1f9d7F570dc94a51479a000E3BCE967196;
        priceFeedAddresses[5] = 0xaD1d5344AaDE45F43E596773Bcc4c423EAbdD034;

        indexComponentRegistry.registerComponents(componentAddresses, priceFeedAddresses, symbols);
        IndexCalculationRegistry indexCalculationRegistry = new IndexCalculationRegistry(deployer);
        console2.log("IndexCalculationRegistry deployed at:", address(indexCalculationRegistry));
        MarketCapWeighted marketCapWeighted = new MarketCapWeighted(address(indexComponentRegistry));
        console2.log("MarketCapWeighted deployed at:", address(marketCapWeighted));
        indexCalculationRegistry.registerIndexCalculation(address(marketCapWeighted));
        IndexFactory indexFactory =
            new IndexFactory(deployer, address(indexCalculationRegistry), address(indexComponentRegistry));
        console2.log("IndexFactory deployed at:", address(indexFactory));
        address indexAddress = indexFactory.deployIndex("Index5", address(marketCapWeighted), componentAddresses);
        console2.log("Index5 deployed at:", indexAddress);
    }
}
