// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";
import { IndexCalculationRegistry } from "src/indices/IndexCalculationRegistry.sol";
import { IndexComponentRegistry } from "src/indices/IndexComponentRegistry.sol";
import { IndexFactory } from "src/indices/IndexFactory.sol";
import { MarketCapWeighted } from "src/indices/indexCalculations/MarketCapWeighted.sol";
import { HardcodedCirculatingSupply } from "src/indices/HardcodedCirculatingSupply.sol";

contract DeployIndex is BaseScript {
    address gardenFactoryAddress = 0xA6c558f50c435896aEDe997091bD06ef6cAd3603;

    function run() public broadcaster {
        setUp();
        IndexComponentRegistry indexComponentRegistry = new IndexComponentRegistry(deployer);
        console2.log("IndexComponentRegistry deployed at:", address(indexComponentRegistry));

        // =====================================================================
        // 13 Components: BTC, ETH, USDC + BLOKC-10 altcoins
        // (LINK, UNI, ARB, AAVE, GMX, PENDLE, GRT, CRV, RDNT, DAI)
        // =====================================================================
        IndexComponentRegistry.Component[] memory components = new IndexComponentRegistry.Component[](16);

        // --- Core assets ---
        components[0] = IndexComponentRegistry.Component({
            symbol: bytes32("BTC"),
            tokenAddress: 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f,
            priceFeedAddress: 0x6ce185860a4963106506C203335A2910413708e9,
            heartbeat: 86_400
        });

        components[1] = IndexComponentRegistry.Component({
            symbol: bytes32("ETH"),
            tokenAddress: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            priceFeedAddress: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
            heartbeat: 86_400
        });

        components[2] = IndexComponentRegistry.Component({
            symbol: bytes32("USDC"),
            tokenAddress: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
            priceFeedAddress: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
            heartbeat: 86_400
        });

        components[3] = IndexComponentRegistry.Component({
            symbol: bytes32("LINK"),
            tokenAddress: 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4,
            priceFeedAddress: 0x86E53CF1B870786351Da77A57575e79CB55812CB,
            heartbeat: 3600
        });

        components[4] = IndexComponentRegistry.Component({
            symbol: bytes32("UNI"),
            tokenAddress: 0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0,
            priceFeedAddress: 0x9C917083fDb403ab5ADbEC26Ee294f6EcAda2720,
            heartbeat: 86_400
        });

        components[5] = IndexComponentRegistry.Component({
            symbol: bytes32("ARB"),
            tokenAddress: 0x912CE59144191C1204E64559FE8253a0e49E6548,
            priceFeedAddress: 0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6,
            heartbeat: 86_400
        });

        components[6] = IndexComponentRegistry.Component({
            symbol: bytes32("AAVE"),
            tokenAddress: 0xba5DdD1f9d7F570dc94a51479a000E3BCE967196,
            priceFeedAddress: 0xaD1d5344AaDE45F43E596773Bcc4c423EAbdD034,
            heartbeat: 86_400
        });

        components[7] = IndexComponentRegistry.Component({
            symbol: bytes32("GMX"),
            tokenAddress: 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a,
            priceFeedAddress: 0xDB98056FecFff59D032aB628337A4887110df3dB,
            heartbeat: 86_400
        });

        components[8] = IndexComponentRegistry.Component({
            symbol: bytes32("PENDLE"),
            tokenAddress: 0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8,
            priceFeedAddress: 0x66853E19d73c0F9301fe099c324A1E9726953433,
            heartbeat: 86_400
        });

        components[9] = IndexComponentRegistry.Component({
            symbol: bytes32("GRT"),
            tokenAddress: 0x9623063377AD1B27544C965cCd7342f7EA7e88C7,
            priceFeedAddress: 0x0F38D86FceF4955B705F35c9e41d1A16e0637c73,
            heartbeat: 86_400
        });

        components[10] = IndexComponentRegistry.Component({
            symbol: bytes32("CRV"),
            tokenAddress: 0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978,
            priceFeedAddress: 0xaebDA2c976cfd1eE1977Eac079B4382acb849325,
            heartbeat: 3600
        });

        components[11] = IndexComponentRegistry.Component({
            symbol: bytes32("ZRO"),
            tokenAddress: 0x6985884C4392D348587B19cb9eAAf157F13271cd,
            priceFeedAddress: 0x1940fEd49cDBC397941f2D336eb4994D599e568B,
            heartbeat: 3600
        });

        components[12] = IndexComponentRegistry.Component({
            symbol: bytes32("DAI"),
            tokenAddress: 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1,
            priceFeedAddress: 0xc5C8E77B397E531B8EC06BFb0048328B30E9eCfB,
            heartbeat: 86_400
        });

        indexComponentRegistry.registerComponents(components);

        IndexCalculationRegistry indexCalculationRegistry = new IndexCalculationRegistry(deployer);
        console2.log("IndexCalculationRegistry deployed at:", address(indexCalculationRegistry));

        HardcodedCirculatingSupply circulatingSupply = new HardcodedCirculatingSupply(deployer);
        console2.log("HardcodedCirculatingSupply deployed at:", address(circulatingSupply));

        // Seed supplies for all 12 index-eligible tokens (BTC + ETH for BLOKC2/5, altcoins for BLOKC10)
        bytes32[] memory supplySymbols = new bytes32[](12);
        uint256[] memory supplies = new uint256[](12);

        supplySymbols[0] = bytes32("BTC");
        supplies[0] = 19_867_331;
        supplySymbols[1] = bytes32("ETH");
        supplies[1] = 120_691_190;
        supplySymbols[2] = bytes32("LINK");
        supplies[2] = 727_099_970;
        supplySymbols[3] = bytes32("UNI");
        supplies[3] = 633_561_604;
        supplySymbols[4] = bytes32("ARB");
        supplies[4] = 6_040_824_145;
        supplySymbols[5] = bytes32("AAVE");
        supplies[5] = 15_164_313;
        supplySymbols[6] = bytes32("GMX");
        supplies[6] = 10_383_466;
        supplySymbols[7] = bytes32("PENDLE");
        supplies[7] = 166_727_478;
        supplySymbols[8] = bytes32("GRT");
        supplies[8] = 10_776_016_812;
        supplySymbols[9] = bytes32("CRV");
        supplies[9] = 1_496_145_688;
        supplySymbols[10] = bytes32("RDNT");
        supplies[10] = 1_292_073_967;
        supplySymbols[11] = bytes32("DAI");
        supplies[11] = 4_413_758_153;

        circulatingSupply.setSupplies(supplySymbols, supplies);
        console2.log("Seeded circulating supplies for 12 tokens");

        // =====================================================================
        // Deploy MarketCapWeighted using HardcodedCirculatingSupply
        // (same MarketCapWeighted contract — no hardcoded variant needed)
        // =====================================================================
        MarketCapWeighted marketCapWeighted =
            new MarketCapWeighted(address(indexComponentRegistry), address(circulatingSupply));
        console2.log("MarketCapWeighted deployed at:", address(marketCapWeighted));

        indexCalculationRegistry.registerIndexCalculation(address(marketCapWeighted));

        IndexFactory indexFactory = new IndexFactory(
            deployer, address(indexCalculationRegistry), address(indexComponentRegistry), gardenFactoryAddress
        );
        console2.log("IndexFactory deployed at:", address(indexFactory));

        //deploy BLOKC2
        bytes32[] memory symbols2 = new bytes32[](2);
        symbols2[0] = bytes32("BTC");
        symbols2[1] = bytes32("ETH");
        indexFactory.deployIndex("BLOKC2", address(marketCapWeighted), symbols2);

        //deploy BLOKC5
        bytes32[] memory symbols5 = new bytes32[](5);
        symbols5[0] = bytes32("BTC");
        symbols5[1] = bytes32("ETH");
        symbols5[2] = bytes32("LINK");
        symbols5[3] = bytes32("UNI");
        symbols5[4] = bytes32("ARB");
        indexFactory.deployIndex("BLOKC5", address(marketCapWeighted), symbols5);

        //deploy BLOKC10
        bytes32[] memory symbols10 = new bytes32[](10);
        symbols10[0] = bytes32("LINK");
        symbols10[1] = bytes32("UNI");
        symbols10[2] = bytes32("ARB");
        symbols10[3] = bytes32("AAVE");
        symbols10[4] = bytes32("GMX");
        symbols10[5] = bytes32("PENDLE");
        symbols10[6] = bytes32("GRT");
        symbols10[7] = bytes32("CRV");
        symbols10[8] = bytes32("RDNT");
        symbols10[9] = bytes32("DAI");
        indexFactory.deployIndex("BLOKC10", address(marketCapWeighted), symbols10);
    }
}
