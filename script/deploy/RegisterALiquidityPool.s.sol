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
        address liquidityPoolRegistryAddress = 0xA3178280c191dD46c551b91c651F337E47594d85;
        LiquidityPoolRegistry liquidityPoolRegistry = LiquidityPoolRegistry(liquidityPoolRegistryAddress);

        // =====================================================================
        // Token Addresses (Arbitrum One)
        // =====================================================================

        address usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // Native USDC
        address wbtc = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;

        // =====================================================================
        // DEX Identifiers
        // =====================================================================
        bytes32 uniswapV3 = keccak256("UNISWAP_V3");

        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: 0xac70bD92F89e6739B3a08Db9B6081a923912f73D,
                tokenA: wbtc,
                tokenB: usdc,
                dexId: uniswapV3,
                pairName: "WBTC/USDC"
            })
        );
    }
}
