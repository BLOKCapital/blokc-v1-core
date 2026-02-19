// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";
import { IndexCalculationRegistry } from "src/indices/IndexCalculationRegistry.sol";
import { IndexComponentRegistry } from "src/indices/IndexComponentRegistry.sol";
import { IndexFactory } from "src/indices/IndexFactory.sol";
import { MarketCapWeighted } from "src/indices/indexCalculations/MarketCapWeighted.sol";

contract DeployIndex is BaseScript {
    address gardenFactoryAddress = 0xd3098a203CC21b2A17dBc01D62A34838e104a3bC;

    function run() public broadcaster {
        setUp();
        IndexComponentRegistry indexComponentRegistry = new IndexComponentRegistry(deployer);
        console2.log("IndexComponentRegistry deployed at:", address(indexComponentRegistry));

        string[] memory symbols = new string[](6);

        symbols[0] = "BTC";
        symbols[1] = "ETH";
        symbols[2] = "USDC";
        symbols[3] = "LINK";
        symbols[4] = "UNI";
        symbols[5] = "ARB";

        IndexComponentRegistry.Component[] memory components = new IndexComponentRegistry.Component[](6);
        components[0] = IndexComponentRegistry.Component({
            symbol: "BTC",
            tokenAddress: 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f,
            priceFeedAddress: 0x6ce185860a4963106506C203335A2910413708e9,
            heartbeat: 3600
        });

        components[1] = IndexComponentRegistry.Component({
            symbol: "ETH",
            tokenAddress: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            priceFeedAddress: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
            heartbeat: 3600
        });

        components[2] = IndexComponentRegistry.Component({
            symbol: "USDC",
            tokenAddress: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
            priceFeedAddress: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
            heartbeat: 86_400
        });

        components[3] = IndexComponentRegistry.Component({
            symbol: "LINK",
            tokenAddress: 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4,
            priceFeedAddress: 0x86E53CF1B870786351Da77A57575e79CB55812CB,
            heartbeat: 3600
        });

        components[4] = IndexComponentRegistry.Component({
            symbol: "UNI",
            tokenAddress: 0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0,
            priceFeedAddress: 0x9C917083fDb403ab5ADbEC26Ee294f6EcAda2720,
            heartbeat: 86_400
        });

        components[5] = IndexComponentRegistry.Component({
            symbol: "ARB",
            tokenAddress: 0x912CE59144191C1204E64559FE8253a0e49E6548,
            priceFeedAddress: 0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6,
            heartbeat: 86_400
        });

        indexComponentRegistry.registerComponents(components);
        IndexCalculationRegistry indexCalculationRegistry = new IndexCalculationRegistry(deployer);
        console2.log("IndexCalculationRegistry deployed at:", address(indexCalculationRegistry));
        MarketCapWeighted marketCapWeighted =
            new MarketCapWeighted(address(indexComponentRegistry), 0x01590A36B357cc54d4c4DCA16631596E943C29FD);
        console2.log("MarketCapWeighted deployed at:", address(marketCapWeighted));
        indexCalculationRegistry.registerIndexCalculation(address(marketCapWeighted));
        IndexFactory indexFactory = new IndexFactory(
            deployer, address(indexCalculationRegistry), address(indexComponentRegistry), gardenFactoryAddress
        );
        console2.log("IndexFactory deployed at:", address(indexFactory));
        string[] memory indexSymbols = new string[](5);
        indexSymbols[0] = "BTC";
        indexSymbols[1] = "ETH";
        indexSymbols[2] = "ARB";
        indexSymbols[3] = "LINK";
        indexSymbols[4] = "UNI";

        address indexAddress = indexFactory.deployIndex("Index5", address(marketCapWeighted), indexSymbols);
        console2.log("Index5 deployed at:", indexAddress);
    }
}
