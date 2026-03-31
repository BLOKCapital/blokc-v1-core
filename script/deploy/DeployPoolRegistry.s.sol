//SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Script } from "forge-std/Script.sol";
import { BaseScript } from "script/Base.s.sol";
import { LiquidityPoolRegistry } from "src/liquidityPoolRegistry/LiquidityPoolRegistry.sol";
import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";
import { console2 } from "forge-std/console2.sol";

contract DeployLiquidityPoolRegistry is BaseScript {
    function run() public broadcaster {
        setUp();
        LiquidityPoolRegistry liquidityPoolRegistry = new LiquidityPoolRegistry(deployer);
        console2.log("LiquidityPoolRegistry deployed at:", address(liquidityPoolRegistry));

        // =====================================================================
        // Token Addresses (Arbitrum One)
        // =====================================================================
        address weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        address usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // Native USDC
        address usdce = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; // Bridged USDC.e
        address usdt = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
        address wbtc = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
        address arb = 0x912CE59144191C1204E64559FE8253a0e49E6548;
        address dai = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
        address gmx = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a;
        address link = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
        address uni = 0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0;
        address pendle = 0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8;
        address rdnt = 0x3082CC23568eA640225c2467653dB90e9250AaA0;
        address magic = 0x539bdE0d7Dbd336b79148AA742883198BBF60342;
        address grail = 0x3d9907F9a368ad0a51Be60f7Da3b97cf940982D8;

        // =====================================================================
        // DEX Identifiers
        // =====================================================================
        bytes32 uniswapV3 = keccak256("UNISWAP_V3");
        bytes32 uniswapV2 = keccak256("UNISWAP_V2");
        bytes32 camelotV2 = keccak256("CAMELOT_V2");
        bytes32 camelotV3 = keccak256("CAMELOT_V3");

        // =====================================================================
        //  UNISWAP V3 POOLS
        // =====================================================================

        // 1. WETH/USDC - 0.05% swapFee (~$75M TVL)
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0xC6962004f452bE9203591991D15f6b388e09E8D0,
                tokenA: usdc,
                tokenB: weth,
                dexId: uniswapV3,
                pairName: "WETH/USDC",
                swapFee: 500
            })
        );

        // 2. WETH/USDC - 0.3% swapFee (~$10M TVL)
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0xc473e2aEE3441BF9240Be85eb122aBB059A3B57c,
                tokenA: usdc,
                tokenB: weth,
                dexId: uniswapV3,
                pairName: "WETH/USDC",
                swapFee: 3000
            })
        );

        // 3. WETH/USDC.e - 0.05% swapFee
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443,
                tokenA: usdce,
                tokenB: weth,
                dexId: uniswapV3,
                pairName: "WETH/USDC.e",
                swapFee: 500
            })
        );

        // 4. WETH/USDT - 0.05% swapFee
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0x641C00A822e8b671738d32a431a4Fb6074E5c79d,
                tokenA: usdt,
                tokenB: weth,
                dexId: uniswapV3,
                pairName: "WETH/USDT",
                swapFee: 500
            })
        );

        // 5. WBTC/WETH - 0.05% swapFee
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0x2f5e87C9312fa29aed5c179E456625D79015299c,
                tokenA: wbtc,
                tokenB: weth,
                dexId: uniswapV3,
                pairName: "WBTC/WETH",
                swapFee: 500
            })
        );

        // 6. ARB/WETH - 0.05% swapFee
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0xC6F780497A95e246EB9449f5e4770916DCd6396A,
                tokenA: arb,
                tokenB: weth,
                dexId: uniswapV3,
                pairName: "ARB/WETH",
                swapFee: 500
            })
        );

        // 7. ARB/WETH - 0.3% swapFee
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0x92c63d0e701CAAe670C9415d91C474F686298f00,
                tokenA: arb,
                tokenB: weth,
                dexId: uniswapV3,
                pairName: "ARB/WETH",
                swapFee: 3000
            })
        );

        // 8. LINK/WETH - 0.3% swapFee
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0x468b88941e7Cc0B88c1869d68ab6b570bCEF62Ff,
                tokenA: link,
                tokenB: weth,
                dexId: uniswapV3,
                pairName: "LINK/WETH",
                swapFee: 3000
            })
        );

        // 9. UNI/WETH - 0.3% swapFee
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0xC24f7d8E51A64dc1238880BD00bb961D54cbeb29,
                tokenA: uni,
                tokenB: weth,
                dexId: uniswapV3,
                pairName: "UNI/WETH",
                swapFee: 3000
            })
        );

        // 10. GMX/WETH - 1% swapFee
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0x80A9ae39310abf666A87C743d6ebBD0E8C42158E,
                tokenA: gmx,
                tokenB: weth,
                dexId: uniswapV3,
                pairName: "GMX/WETH",
                swapFee: 10_000
            })
        );

        // 11. PENDLE/WETH - 0.3% swapFee
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0xdbaeB7f0DFe3a0AAFD798CCECB5b22E708f7852c,
                tokenA: pendle,
                tokenB: weth,
                dexId: uniswapV3,
                pairName: "PENDLE/WETH",
                swapFee: 3000
            })
        );

        // 12. RDNT/WETH - 0.3% swapFee
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0x446BF9748B4eA044dd759d9B9311C70491dF8F29,
                tokenA: rdnt,
                tokenB: weth,
                dexId: uniswapV3,
                pairName: "RDNT/WETH",
                swapFee: 3000
            })
        );

        // 13. MAGIC/WETH - 1% swapFee
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0x7e7FB3CCEcA5F2ac952eDF221fd2a9f62E411980,
                tokenA: magic,
                tokenB: weth,
                dexId: uniswapV3,
                pairName: "MAGIC/WETH",
                swapFee: 10_000
            })
        );

        // 14. USDC/USDT - 0.01% swapFee (stablecoin pair)
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0xbE3aD6a5669Dc0B8b12FeBC03608860C31E2eef6,
                tokenA: usdc,
                tokenB: usdt,
                dexId: uniswapV3,
                pairName: "USDC/USDT",
                swapFee: 100
            })
        );

        // 15. DAI/USDC - 0.01% swapFee (stablecoin pair)
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0xF0428617433652c9dc6D1093A42AdFbF30D29f74,
                tokenA: dai,
                tokenB: usdc,
                dexId: uniswapV3,
                pairName: "DAI/USDC",
                swapFee: 100
            })
        );

        // 16. WETH/USDT - 0.01% swapFee (tight spread)
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0x42161084d0672e1d3F26a9B53E653bE2084ff19C,
                tokenA: usdt,
                tokenB: weth,
                dexId: uniswapV3,
                pairName: "WETH/USDT",
                swapFee: 100
            })
        );

        // 17. WBTC/USDT - 0.05% swapFee
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0x5969EFddE3cF5C0D9a88aE51E47d721096A97203,
                tokenA: wbtc,
                tokenB: usdt,
                dexId: uniswapV3,
                pairName: "WBTC/USDT",
                swapFee: 500
            })
        );

        // =====================================================================
        //  CAMELOT V3 POOLS (Algebra - Dynamic swapFees)
        //  swapFee: 0 indicates dynamic swapFee managed by the protocol
        // =====================================================================

        // 18. WETH/USDC - Camelot V3 (highest TVL on Camelot)
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0xB1026b8e7276e7AC75410F1fcbbe21796e8f7526,
                tokenA: usdc,
                tokenB: weth,
                dexId: camelotV3,
                pairName: "WETH/USDC",
                swapFee: 0
            })
        );

        // 19. WETH/USDT - Camelot V3
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0x7CcCBA38E2D959fe135e79AEBB57CCb27B128358,
                tokenA: usdt,
                tokenB: weth,
                dexId: camelotV3,
                pairName: "WETH/USDT",
                swapFee: 0
            })
        );

        // 20. ARB/WETH - Camelot V3
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0xe51635ae8136aBAc44906A8f230C2D235E9c195F,
                tokenA: arb,
                tokenB: weth,
                dexId: camelotV3,
                pairName: "ARB/WETH",
                swapFee: 0
            })
        );

        // 21. ARB/USDC - Camelot V3
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0xfaE2AE0a9f87FD35b5b0E24B47BAC796A7EEfEa1,
                tokenA: arb,
                tokenB: usdc,
                dexId: camelotV3,
                pairName: "ARB/USDC",
                swapFee: 0
            })
        );

        // 22. WBTC/WETH - Camelot V3
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0xd845f7D4f4DeB9Ff5bCf09D140Ef13718F6f6C71,
                tokenA: wbtc,
                tokenB: weth,
                dexId: camelotV3,
                pairName: "WBTC/WETH",
                swapFee: 0
            })
        );

        // 23. GRAIL/WETH - Camelot V3
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0x60451B6aC55E3C5F0f3aeE31519670EcC62DC28f,
                tokenA: grail,
                tokenB: weth,
                dexId: camelotV3,
                pairName: "GRAIL/WETH",
                swapFee: 0
            })
        );

        // 24. PENDLE/WETH - Camelot V3
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0xE461f84C3fE6BCDd1162Eb0Ef4284F3bB6e4CAD3,
                tokenA: pendle,
                tokenB: weth,
                dexId: camelotV3,
                pairName: "PENDLE/WETH",
                swapFee: 0
            })
        );

        // 25. GMX/USDC - Camelot V3
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0xB79Af3DadC07E905a148B14382Fe8ED7528623f2,
                tokenA: gmx,
                tokenB: usdc,
                dexId: camelotV3,
                pairName: "GMX/USDC",
                swapFee: 0
            })
        );

        // =====================================================================
        //  CAMELOT V2 POOLS (AMM - Constant Product)
        //  swapFee: 3000 represents the default 0.3% swap Fee
        // =====================================================================

        // 26. WETH/USDC - Camelot V2
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0x84652bb2539513BAf36e225c930Fdd8eaa63CE27,
                tokenA: usdc,
                tokenB: weth,
                dexId: camelotV2,
                pairName: "WETH/USDC",
                swapFee: 3000
            })
        );

        // 27. ARB/WETH - Camelot V2
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0xa6c5C7D189fA4eB5Af8ba34E63dCDD3a635D433f,
                tokenA: arb,
                tokenB: weth,
                dexId: camelotV2,
                pairName: "ARB/WETH",
                swapFee: 3000
            })
        );

        // 28. PENDLE/WETH - Camelot V2
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0xBfCa4230115DE8341F3A3d5e8845fFb3337B2Be3,
                tokenA: pendle,
                tokenB: weth,
                dexId: camelotV2,
                pairName: "PENDLE/WETH",
                swapFee: 3000
            })
        );

        // =====================================================================
        //  UNISWAP V2 POOLS (Constant Product)
        //  swapFee: 3000 represents the flat 0.3% swap swapFee
        //  Factory: 0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9
        // =====================================================================

        // 29. WETH/USDC - Uniswap V2 (~$80K TVL)
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0xF64Dfe17C8b87F012FCf50FbDA1D62bfA148366a,
                tokenA: usdc,
                tokenB: weth,
                dexId: uniswapV2,
                pairName: "WETH/USDC",
                swapFee: 3000
            })
        );

        // 30. WETH/DAI - Uniswap V2 (~$30K TVL)
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0x692a0B300366D1042679397e40f3d2cb4b8F7D30,
                tokenA: dai,
                tokenB: weth,
                dexId: uniswapV2,
                pairName: "WETH/DAI",
                swapFee: 3000
            })
        );

        // 31. DAI/USDC - Uniswap V2 (stablecoin pair, useful for routing)
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0x8edd9aEABdf2e63f76f4c4B7F36AEFa14D3cC6BC,
                tokenA: dai,
                tokenB: usdc,
                dexId: uniswapV2,
                pairName: "DAI/USDC",
                swapFee: 3000
            })
        );
    }
}
