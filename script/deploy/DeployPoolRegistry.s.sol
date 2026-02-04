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

        bytes32 protocolId = keccak256("UNISWAP_V3");
        address wethAddress = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

        //WETH/USDC - Uniswap V3
        address poolAddressWethUsdc = 0xC6962004f452bE9203591991D15f6b388e09E8D0;
        address usdcAddress = 0xC6962004f452bE9203591991D15f6b388e09E8D0;
        string memory pairName1 = "WETH/USDC";

        ILiquidityPoolRegistry.AddPoolParams memory params1 = ILiquidityPoolRegistry.AddPoolParams({
            poolAddress: poolAddressWethUsdc,
            tokenA: usdcAddress,
            tokenB: wethAddress,
            dexId: protocolId,
            pairName: pairName1,
            fee: 500
        });

        liquidityPoolRegistry.addPool(params1);

        // WETH/WBTC - Uniswap V3
        address poolAddressWethWbtc = 0x905dfCD5649217c42684f23958568e533C711Aa3;
        address wbtcAddress = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
        string memory pairName2 = "WETH/WBTC";

        ILiquidityPoolRegistry.AddPoolParams memory params2 = ILiquidityPoolRegistry.AddPoolParams({
            poolAddress: poolAddressWethWbtc,
            tokenA: wbtcAddress,
            tokenB: wethAddress,
            dexId: protocolId,
            pairName: pairName2,
            fee: 3000
        });

        liquidityPoolRegistry.addPool(params2);

        // WETH/LINK - Uniswap V3
        address poolAddressWethLink = 0x468b88941e7Cc0B88c1869d68ab6b570bCEF62Ff;
        address linkAddress = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
        string memory pairName3 = "WETH/LINK";

        ILiquidityPoolRegistry.AddPoolParams memory params3 = ILiquidityPoolRegistry.AddPoolParams({
            poolAddress: poolAddressWethLink,
            tokenA: linkAddress,
            tokenB: wethAddress,
            dexId: protocolId,
            pairName: pairName3,
            fee: 3000
        });

        liquidityPoolRegistry.addPool(params3);

        //WETH/ARB - Uniswap V3
        address poolAddressWethArb = 0xC6F780497A95e246EB9449f5e4770916DCd6396A;
        address arbAddress = 0x912CE59144191C1204E64559FE8253a0e49E6548;
        string memory pairName4 = "WETH/ARB";

        ILiquidityPoolRegistry.AddPoolParams memory params4 = ILiquidityPoolRegistry.AddPoolParams({
            poolAddress: poolAddressWethArb,
            tokenA: arbAddress,
            tokenB: wethAddress,
            dexId: protocolId,
            pairName: pairName4,
            fee: 500
        });

        liquidityPoolRegistry.addPool(params4);

        // WETH/UNI - Uniswap V3
        address poolAddressWethUni = 0xC24f7d8E51A64dc1238880BD00bb961D54cbeb29;
        address uniAddress = 0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0;
        string memory pairName5 = "WETH/UNI";

        ILiquidityPoolRegistry.AddPoolParams memory params5 = ILiquidityPoolRegistry.AddPoolParams({
            poolAddress: poolAddressWethUni,
            tokenA: uniAddress,
            tokenB: wethAddress,
            dexId: protocolId,
            pairName: pairName5,
            fee: 3000
        });

        liquidityPoolRegistry.addPool(params5);
    }
}
