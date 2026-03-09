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
        // Token Addresses (Ethereum Mainnet)
        // =====================================================================
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        address wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        address dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        address uni = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
        address link = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
        address mkr = 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2;
        address wsteth = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

        // =====================================================================
        // DEX Identifiers
        // =====================================================================
        bytes32 uniswapV3 = keccak256("UNISWAP_V3");
        bytes32 uniswapV2 = keccak256("UNISWAP_V2");

        // =====================================================================
        //  UNISWAP V3 POOLS
        // =====================================================================

        // 1. USDC/WETH - 0.05% fee (~$71M TVL, highest TVL V3 pool)
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640,
                tokenA: usdc,
                tokenB: weth,
                dexId: uniswapV3,
                pairName: "USDC/WETH",
                fee: 500
            })
        );

        // 2. USDC/WETH - 0.3% fee (~$47M TVL)
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8,
                tokenA: usdc,
                tokenB: weth,
                dexId: uniswapV3,
                pairName: "USDC/WETH",
                fee: 3000
            })
        );

        // 3. WETH/USDT - 0.05% fee
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0x11b815efB8f581194ae79006d24E0d814B7697F6,
                tokenA: usdt,
                tokenB: weth,
                dexId: uniswapV3,
                pairName: "WETH/USDT",
                fee: 500
            })
        );

        // 4. WETH/USDT - 0.3% fee (~$79M TVL)
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0x4e68Ccd3E89f51C3074ca5072bbAC773960dFa36,
                tokenA: usdt,
                tokenB: weth,
                dexId: uniswapV3,
                pairName: "WETH/USDT",
                fee: 3000
            })
        );

        // 5. WBTC/WETH - 0.3% fee (~$59M TVL)
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0xCBCdF9626bC03E24f779434178A73a0B4bad62eD,
                tokenA: wbtc,
                tokenB: weth,
                dexId: uniswapV3,
                pairName: "WBTC/WETH",
                fee: 3000
            })
        );

        // 6. WBTC/WETH - 0.05% fee
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0x4585FE77225b41b697C938B018E2Ac67Ac5a20c0,
                tokenA: wbtc,
                tokenB: weth,
                dexId: uniswapV3,
                pairName: "WBTC/WETH",
                fee: 500
            })
        );

        // 7. DAI/WETH - 0.3% fee
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0xC2e9F25Be6257c210d7Adf0D4Cd6E3E881ba25f8,
                tokenA: dai,
                tokenB: weth,
                dexId: uniswapV3,
                pairName: "DAI/WETH",
                fee: 3000
            })
        );

        // 8. UNI/WETH - 0.3% fee
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0x1d42064Fc4Beb5F8aAF85F4617AE8b3b5B8Bd801,
                tokenA: uni,
                tokenB: weth,
                dexId: uniswapV3,
                pairName: "UNI/WETH",
                fee: 3000
            })
        );

        // 9. LINK/WETH - 0.3% fee
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0xa6Cc3C2531FdaA6Ae1A3CA84c2855806728693e8,
                tokenA: link,
                tokenB: weth,
                dexId: uniswapV3,
                pairName: "LINK/WETH",
                fee: 3000
            })
        );

        // 10. USDC/USDT - 0.01% fee (stablecoin pair)
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0x7858E59e0C01EA06Df3aF3D20aC7B0003275D4Bf,
                tokenA: usdc,
                tokenB: usdt,
                dexId: uniswapV3,
                pairName: "USDC/USDT",
                fee: 100
            })
        );

        // 11. DAI/USDC - 0.01% fee (stablecoin pair)
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0x6c6Bc977E13Df9b0de53b251522280BB72383700,
                tokenA: dai,
                tokenB: usdc,
                dexId: uniswapV3,
                pairName: "DAI/USDC",
                fee: 100
            })
        );

        // 12. wstETH/WETH - 0.01% fee (LST pair)
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0x109830a1AAaD605BbF02a9dFA7B0B92EC2FB7dAa,
                tokenA: wsteth,
                tokenB: weth,
                dexId: uniswapV3,
                pairName: "wstETH/WETH",
                fee: 100
            })
        );

        // =====================================================================
        //  UNISWAP V2 POOLS (Constant Product)
        //  fee: 3000 represents the flat 0.3% swap fee
        //  Factory: 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
        // =====================================================================

        // 13. USDC/WETH - Uniswap V2 (~$50M TVL)
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc,
                tokenA: usdc,
                tokenB: weth,
                dexId: uniswapV2,
                pairName: "USDC/WETH",
                fee: 3000
            })
        );

        // 14. WETH/USDT - Uniswap V2 (~$14M TVL)
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852,
                tokenA: usdt,
                tokenB: weth,
                dexId: uniswapV2,
                pairName: "WETH/USDT",
                fee: 3000
            })
        );

        // 15. DAI/WETH - Uniswap V2
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0xA478c2975Ab1Ea89e8196811F51A7B7Ade33eB11,
                tokenA: dai,
                tokenB: weth,
                dexId: uniswapV2,
                pairName: "DAI/WETH",
                fee: 3000
            })
        );

        // 16. WBTC/WETH - Uniswap V2
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0xBb2b8038a1640196FbE3e38816F3e67Cba72D940,
                tokenA: wbtc,
                tokenB: weth,
                dexId: uniswapV2,
                pairName: "WBTC/WETH",
                fee: 3000
            })
        );

        // 17. UNI/WETH - Uniswap V2 (~$5M TVL)
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0xd3d2E2692501A5c9Ca623199D38826e513033a17,
                tokenA: uni,
                tokenB: weth,
                dexId: uniswapV2,
                pairName: "UNI/WETH",
                fee: 3000
            })
        );

        // 18. LINK/WETH - Uniswap V2 (~$2.8M TVL)
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0xa2107FA5B38d9bbd2C461D6EDf11B11A50F6b974,
                tokenA: link,
                tokenB: weth,
                dexId: uniswapV2,
                pairName: "LINK/WETH",
                fee: 3000
            })
        );

        // 19. MKR/WETH - Uniswap V2 (~$1.85M TVL)
        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0xC2aDdA861F89bBB333c90c492cB837741916A225,
                tokenA: mkr,
                tokenB: weth,
                dexId: uniswapV2,
                pairName: "MKR/WETH",
                fee: 3000
            })
        );
    }
}
