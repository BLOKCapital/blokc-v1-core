// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▛▀▜▌▐▛▚▖     ▐▌   ▐▌ ▐▌▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { BaseScript } from "script/Base.s.sol";
import { IndexComponentRegistry } from "src/indices/IndexComponentRegistry.sol";
import { IndexCalculationRegistry } from "src/indices/IndexCalculationRegistry.sol";
import { MarketCapWeighted } from "src/indices/indexCalculations/MarketCapWeighted.sol";
import { IndexFactory } from "src/indices/IndexFactory.sol";
import { Rebalancer } from "src/rebalancer/Rebalancer.sol";
import {
    UniswapV3DepthQuoteFacet
} from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3DepthQuoteFacet.sol";
import { console2 } from "forge-std/console2.sol";

/**
 * @title MigrateRegistryAndIndices
 * @notice Phase-1 migration script: deploys the fixed IndexComponentRegistry (time-decay
 *         deviation guard — no permanent FeedFrozenError), new calculation contracts, a new
 *         IndexFactory with identically-composed BLOKC2/5/10 indices, the liquidity-aware
 *         Uniswap V3 depth quote facet, and a new Rebalancer wired to all of the above plus
 *         the EXISTING pool registry.
 *
 *         The existing IndexCalculationRegistry and HardcodedCirculatingSupply are REUSED
 *         (owner-registrable / registry-independent respectively) — only contracts holding an
 *         immutable reference to the component registry are redeployed.
 *
 *         Env (all required unless noted):
 *           GARDEN_FACTORY_ADDRESS          live GardenFactory
 *           INDEX_CALCULATION_REGISTRY      live IndexCalculationRegistry (owner must be deployer)
 *           CIRCULATING_SUPPLY_ADDRESS      live HardcodedCirculatingSupply
 *           POOL_REGISTRY_ADDRESS           live LiquidityPoolRegistry (unchanged)
 *           FACET_REGISTRY_ADDRESS          live FacetRegistry
 *           UNISWAP_V2_QUOTE_FACET_ADDRESS  live stock quote facets for the other DEXes
 *           CAMELOT_V2_QUOTE_FACET_ADDRESS
 *           CAMELOT_V3_QUOTE_FACET_ADDRESS
 *           MAX_GARDENS_PER_BATCH           optional, default 10
 */
contract MigrateRegistryAndIndices is BaseScript {
    // Component set — identical feeds/heartbeats to the live registry so the new indices
    // compute identical weights. The registration itself doubles as a feed-freshness proof:
    // a feed without fresh valid rounds reverts here.
    function _components(IndexComponentRegistry.Component[] memory comps) internal pure {
        comps[0] = IndexComponentRegistry.Component({
            symbol: bytes32("BTC"),
            tokenAddress: 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f,
            priceFeedAddress: 0x6ce185860a4963106506C203335A2910413708e9,
            heartbeat: 86_400
        });
        comps[1] = IndexComponentRegistry.Component({
            symbol: bytes32("ETH"),
            tokenAddress: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            priceFeedAddress: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612,
            heartbeat: 86_400
        });
        comps[2] = IndexComponentRegistry.Component({
            symbol: bytes32("USDC"),
            tokenAddress: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
            priceFeedAddress: 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3,
            heartbeat: 86_400
        });
        comps[3] = IndexComponentRegistry.Component({
            symbol: bytes32("LINK"),
            tokenAddress: 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4,
            priceFeedAddress: 0x86E53CF1B870786351Da77A57575e79CB55812CB,
            heartbeat: 3600
        });
        comps[4] = IndexComponentRegistry.Component({
            symbol: bytes32("UNI"),
            tokenAddress: 0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0,
            priceFeedAddress: 0x9C917083fDb403ab5ADbEC26Ee294f6EcAda2720,
            heartbeat: 86_400
        });
        comps[5] = IndexComponentRegistry.Component({
            symbol: bytes32("ARB"),
            tokenAddress: 0x912CE59144191C1204E64559FE8253a0e49E6548,
            priceFeedAddress: 0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6,
            heartbeat: 86_400
        });
        comps[6] = IndexComponentRegistry.Component({
            symbol: bytes32("AAVE"),
            tokenAddress: 0xba5DdD1f9d7F570dc94a51479a000E3BCE967196,
            priceFeedAddress: 0xaD1d5344AaDE45F43E596773Bcc4c423EAbdD034,
            heartbeat: 86_400
        });
        comps[7] = IndexComponentRegistry.Component({
            symbol: bytes32("GMX"),
            tokenAddress: 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a,
            priceFeedAddress: 0xDB98056FecFff59D032aB628337A4887110df3dB,
            heartbeat: 86_400
        });
        comps[8] = IndexComponentRegistry.Component({
            symbol: bytes32("PENDLE"),
            tokenAddress: 0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8,
            priceFeedAddress: 0x66853E19d73c0F9301fe099c324A1E9726953433,
            heartbeat: 86_400
        });
        comps[9] = IndexComponentRegistry.Component({
            symbol: bytes32("GRT"),
            tokenAddress: 0x9623063377AD1B27544C965cCd7342f7EA7e88C7,
            priceFeedAddress: 0x0F38D86FceF4955B705F35c9e41d1A16e0637c73,
            heartbeat: 86_400
        });
        comps[10] = IndexComponentRegistry.Component({
            symbol: bytes32("CRV"),
            tokenAddress: 0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978,
            priceFeedAddress: 0xaebDA2c976cfd1eE1977Eac079B4382acb849325,
            heartbeat: 3600
        });
        comps[11] = IndexComponentRegistry.Component({
            symbol: bytes32("ZRO"),
            tokenAddress: 0x6985884C4392D348587B19cb9eAAf157F13271cd,
            priceFeedAddress: 0x1940fEd49cDBC397941f2D336eb4994D599e568B,
            heartbeat: 3600
        });
        comps[12] = IndexComponentRegistry.Component({
            symbol: bytes32("DAI"),
            tokenAddress: 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1,
            priceFeedAddress: 0xc5C8E77B397E531B8EC06BFb0048328B30E9eCfB,
            heartbeat: 86_400
        });
    }

    function _setBands(IndexComponentRegistry registry) internal {
        registry.setDeviationTimeout(1 hours);
        registry.setMaxDeviationBps(bytes32("BTC"), 1000);
        registry.setMaxDeviationBps(bytes32("ETH"), 1000);
        registry.setMaxDeviationBps(bytes32("USDC"), 200);
        registry.setMaxDeviationBps(bytes32("DAI"), 200);
        registry.setMaxDeviationBps(bytes32("LINK"), 2500);
        registry.setMaxDeviationBps(bytes32("UNI"), 2500);
        registry.setMaxDeviationBps(bytes32("ARB"), 2500);
        registry.setMaxDeviationBps(bytes32("AAVE"), 2500);
        registry.setMaxDeviationBps(bytes32("GMX"), 2500);
        registry.setMaxDeviationBps(bytes32("PENDLE"), 2500);
        registry.setMaxDeviationBps(bytes32("GRT"), 2500);
        registry.setMaxDeviationBps(bytes32("CRV"), 2500);
        registry.setMaxDeviationBps(bytes32("ZRO"), 2500);
    }

    function run() public broadcaster {
        setUp();
        address gardenFactory = vm.envAddress("GARDEN_FACTORY_ADDRESS");
        address calcRegistryAddr = vm.envAddress("INDEX_CALCULATION_REGISTRY");
        address circulatingSupply = vm.envAddress("CIRCULATING_SUPPLY_ADDRESS");
        address poolRegistry = vm.envAddress("POOL_REGISTRY_ADDRESS");
        address facetRegistry = vm.envAddress("FACET_REGISTRY_ADDRESS");

        // ── 1. Fixed component registry + 13 components + bands ──────────────
        IndexComponentRegistry registry = new IndexComponentRegistry(deployer);
        console2.log("NEW IndexComponentRegistry:", address(registry));

        IndexComponentRegistry.Component[] memory comps = new IndexComponentRegistry.Component[](13);
        _components(comps);
        registry.registerComponents(comps);
        _setBands(registry);
        console2.log("Registered 13 components, deviation bands + 1h timeout set");

        // ── 2. Calculation contracts against the NEW registry ────────────────
        MarketCapWeighted marketCapWeighted = new MarketCapWeighted(address(registry), circulatingSupply);
        console2.log("NEW MarketCapWeighted:", address(marketCapWeighted));

        IndexCalculationRegistry calcRegistry = IndexCalculationRegistry(calcRegistryAddr);
        calcRegistry.registerIndexCalculation(address(marketCapWeighted));
        console2.log("Registered calc on EXISTING IndexCalculationRegistry");

        // ── 3. New factory + identically-composed indices
        // ────────────────────
        IndexFactory indexFactory = new IndexFactory(deployer, calcRegistryAddr, address(registry), gardenFactory);
        console2.log("NEW IndexFactory:", address(indexFactory));

        bytes32[] memory symbols2 = new bytes32[](2);
        symbols2[0] = bytes32("BTC");
        symbols2[1] = bytes32("ETH");
        address blokc2 = indexFactory.deployIndex("BLOKC2", address(marketCapWeighted), symbols2);
        console2.log("NEW BLOKC2 index:", blokc2);

        bytes32[] memory symbols5 = new bytes32[](5);
        symbols5[0] = bytes32("LINK");
        symbols5[1] = bytes32("UNI");
        symbols5[2] = bytes32("ARB");
        symbols5[3] = bytes32("AAVE");
        symbols5[4] = bytes32("PENDLE");
        address blokc5 = indexFactory.deployIndex("BLOKC5", address(marketCapWeighted), symbols5);
        console2.log("NEW BLOKC5 index:", blokc5);

        bytes32[] memory symbols10 = new bytes32[](10);
        symbols10[0] = bytes32("LINK");
        symbols10[1] = bytes32("UNI");
        symbols10[2] = bytes32("ARB");
        symbols10[3] = bytes32("AAVE");
        symbols10[4] = bytes32("GMX");
        symbols10[5] = bytes32("PENDLE");
        symbols10[6] = bytes32("GRT");
        symbols10[7] = bytes32("CRV");
        symbols10[8] = bytes32("ZRO");
        symbols10[9] = bytes32("DAI");
        address blokc10 = indexFactory.deployIndex("BLOKC10", address(marketCapWeighted), symbols10);
        console2.log("NEW BLOKC10 index:", blokc10);

        // ── 4. Depth-aware quote facet + new Rebalancer
        // ──────────────────────
        UniswapV3DepthQuoteFacet depthFacet = new UniswapV3DepthQuoteFacet();
        console2.log("NEW UniswapV3DepthQuoteFacet:", address(depthFacet));

        address usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
        Rebalancer rebalancer =
            new Rebalancer(deployer, address(indexFactory), address(registry), poolRegistry, facetRegistry, usdc);
        console2.log("NEW Rebalancer:", address(rebalancer));

        rebalancer.setDexConfig(
            keccak256("UNISWAP_V3"),
            0xE592427A0AEce92De3Edee1F18E0157C05861564,
            address(depthFacet), // liquidity-aware
            bytes4(keccak256("exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))")),
            Rebalancer.DexType.V3_CONCENTRATED
        );
        rebalancer.setDexConfig(
            keccak256("CAMELOT_V2"),
            0xc873fEcbd354f5A56E00E710B90EF4201db2448d,
            vm.envAddress("CAMELOT_V2_QUOTE_FACET_ADDRESS"),
            bytes4(
                keccak256(
                    "swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256,uint256,address[],address,address,uint256)"
                )
            ),
            Rebalancer.DexType.V2_CONSTANT_PRODUCT
        );
        rebalancer.setDexConfig(
            keccak256("CAMELOT_V3"),
            0x1F721E2E82F6676FCE4eA07A5958cF098D339e18,
            vm.envAddress("CAMELOT_V3_QUOTE_FACET_ADDRESS"),
            bytes4(keccak256("exactInputSingle((address,address,address,uint256,uint256,uint256,uint160))")),
            Rebalancer.DexType.V3_CONCENTRATED
        );
        rebalancer.setDexConfig(
            keccak256("UNISWAP_V2"),
            0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24,
            vm.envAddress("UNISWAP_V2_QUOTE_FACET_ADDRESS"),
            bytes4(keccak256("swapExactTokensForTokens(uint256,uint256,address[],address,uint256)")),
            Rebalancer.DexType.V2_STANDARD
        );
        console2.log("Configured 4 DEXes (UNISWAP_V3 -> depth facet)");

        uint256 batch = vm.envOr("MAX_GARDENS_PER_BATCH", uint256(10));
        rebalancer.setMaxGardensPerBatch(keccak256("BLOKC2"), batch);
        rebalancer.setMaxGardensPerBatch(keccak256("BLOKC5"), batch);
        rebalancer.setMaxGardensPerBatch(keccak256("BLOKC10"), batch);
        console2.log("Batch size set:", batch);

        rebalancer.addIndexToType(keccak256("BLOKC2"), blokc2);
        rebalancer.addIndexToType(keccak256("BLOKC5"), blokc5);
        rebalancer.addIndexToType(keccak256("BLOKC10"), blokc10);
        console2.log("Registered 3 index types on the NEW rebalancer");

        console2.log("");
        console2.log("=== Phase 1 complete. Next: MigrateGardens (phase 3), then RetireOldRebalancer (phase 4) ===");
    }
}
