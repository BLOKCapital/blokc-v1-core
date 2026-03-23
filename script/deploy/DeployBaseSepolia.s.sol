// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

// ============================================================================
// DeployBaseSepolia — end-to-end test deployment for the optimal-path engine
// ============================================================================
// Deploys three contracts and wires them together:
//
//   LiquidityPoolRegistry  ← stores pool metadata, indexed by directional poolId
//   DexQuoteRegistry       ← maps dexId → (quoteSelector, paramCount)
//   UniswapV3QuoteRouter   ← standalone V3 spot-price quoter
//   MockV3Pool             ← synthetic WETH/USDC pool (no real liquidity needed)
//
// After deployment update engine/config.staging.json with the printed values
// and run: cre workflow simulate --target staging-settings
// ============================================================================

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import { LiquidityPoolRegistry } from "src/liquidityPoolRegistry/LiquidityPoolRegistry.sol";
import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";
import { DexQuoteRegistry } from "src/utils/DexQuoteRegistry.sol";
import { UniswapV3QuoteRouter } from "src/utils/UniswapV3QuoteRouter.sol";
import { MockV3Pool } from "test/mock/MockV3Pool.sol";

contract DeployBaseSepolia is Script {
    // =========================================================================
    // Base Sepolia token addresses
    // =========================================================================

    /// @dev WETH on Base Sepolia (same precompile address as all OP-stack chains)
    address constant WETH = 0x4200000000000000000000000000000000000006;

    /// @dev Native USDC on Base Sepolia (Circle's official deployment)
    address constant USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;

    // =========================================================================
    // DEX identifiers — must match the values used in the Go engine (core.go)
    // =========================================================================

    bytes32 constant UNISWAP_V3 = keccak256("UNISWAP_V3");

    // =========================================================================
    // MockV3Pool price: USDC / WETH at ~3 000 USDC per WETH
    //   token0 = USDC (0x036C... < 0x4200...), token1 = WETH
    //   raw price = token1 / token0 = 1e18 / 3 000e6 ≈ 3.333e8
    //   sqrtPriceX96 = sqrt(3.333e8) * 2^96 ≈ 18 257 * 2^96 ≈ 1.447e33
    // =========================================================================

    uint160 constant SQRT_PRICE_X96 = 1_446_000_000_000_000_000_000_000_000_000_000;

    // =========================================================================
    // run()
    // =========================================================================

    function run() external {
        bytes32 rawKey = vm.envBytes32("PRIVATE_KEY");
        address deployer = vm.rememberKey(uint256(rawKey));

        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);

        vm.startBroadcast(deployer);

        // ------------------------------------------------------------------
        // 1. LiquidityPoolRegistry
        // ------------------------------------------------------------------
        LiquidityPoolRegistry poolRegistry = new LiquidityPoolRegistry(deployer);
        console2.log("\n[1] LiquidityPoolRegistry:", address(poolRegistry));

        // ------------------------------------------------------------------
        // 2. DexQuoteRegistry (replaces full FacetRegistry for this test)
        // ------------------------------------------------------------------
        DexQuoteRegistry dexRegistry = new DexQuoteRegistry();
        console2.log("[2] DexQuoteRegistry:      ", address(dexRegistry));

        // ------------------------------------------------------------------
        // 3. UniswapV3QuoteRouter  (the dexFacetAddress the engine calls)
        // ------------------------------------------------------------------
        UniswapV3QuoteRouter quoteRouter = new UniswapV3QuoteRouter(address(poolRegistry));
        console2.log("[3] UniswapV3QuoteRouter:  ", address(quoteRouter));

        // ------------------------------------------------------------------
        // 4. Register UNISWAP_V3 in DexQuoteRegistry
        //    paramCount = 5: (poolAddress, amountIn, tokenIn, tokenOut, twapInterval)
        // ------------------------------------------------------------------
        bytes4 quoteSelector = quoteRouter.uniswapV3QuoteExactInputForPool.selector;
        dexRegistry.setDexQuoteSelector(UNISWAP_V3, quoteSelector, 5);
        console2.log("[4] UNISWAP_V3 registered  selector:", vm.toString(bytes32(quoteSelector)));

        // ------------------------------------------------------------------
        // 5. MockV3Pool — USDC (token0) / WETH (token1)
        //    USDC address 0x036C... < WETH 0x4200... so token0 = USDC ✓
        // ------------------------------------------------------------------
        MockV3Pool mockPool = new MockV3Pool(USDC, WETH, SQRT_PRICE_X96);
        console2.log("[5] MockV3Pool:             ", address(mockPool));
        console2.log("    token0 (USDC):", mockPool.token0());
        console2.log("    token1 (WETH):", mockPool.token1());
        console2.log("    sqrtPriceX96: ~3000 USDC per WETH");

        // ------------------------------------------------------------------
        // 6. Register MockV3Pool in LiquidityPoolRegistry
        //    tokenA / tokenB are auto-sorted inside addPool; pairName is
        //    displayed as WETH/USDC (quote/base perspective).
        // ------------------------------------------------------------------
        poolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: address(mockPool),
                tokenA: WETH,
                tokenB: USDC,
                dexId: UNISWAP_V3,
                pairName: "WETH/USDC",
                fee: 500
            })
        );
        console2.log("[6] Pool registered in LiquidityPoolRegistry");

        vm.stopBroadcast();

        // ------------------------------------------------------------------
        // 7. Print config.staging.json snippet — copy this into the engine config
        // ------------------------------------------------------------------
        console2.log("\n======================================================");
        console2.log("Copy the following into engine/config.staging.json:");
        console2.log("======================================================");
        console2.log("{");
        console2.log('  "schedule": "0 */10 * * * *",');
        console2.log('  "intent": "optimalpath",');
        console2.log('  "optimalPath": {');
        console2.log('    "chainSelector": 10344971235874465080,');
        console2.log('    "poolRegistryAddress":  "%s",', address(poolRegistry));
        console2.log('    "facetRegistryAddress": "%s",', address(dexRegistry));
        console2.log('    "dexFacetAddress":      "%s",', address(quoteRouter));
        console2.log('    "swapAmount": "1000000000000000000",');
        console2.log('    "tokenPairs": [');
        console2.log("      {");
        console2.log('        "quoteToken": "%s",', WETH);
        console2.log('        "baseToken":  "%s"', USDC);
        console2.log("      }");
        console2.log("    ]");
        console2.log("  }");
        console2.log("}");
        console2.log("======================================================");
    }
}
