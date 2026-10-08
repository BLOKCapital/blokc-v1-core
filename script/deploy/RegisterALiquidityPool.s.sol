//SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Script } from "forge-std/Script.sol";
import { BaseScript } from "script/Base.s.sol";
import { LiquidityPoolRegistry } from "src/liquidityPoolRegistry/LiquidityPoolRegistry.sol";
import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";
import { console2 } from "forge-std/console2.sol";

/// @dev Minimal pair interface — every pool the registry seeds exposes token0()/token1().
interface IMinimalPair {
    function token0() external view returns (address);
    function token1() external view returns (address);
}

/// @notice Manual one-off helper: registers a single pool on the LIVE beta-1 registry
///         (0xF0F7B0a68B777539Ff7d416eEAC56E0FB3e8B30C). Adjust poolAddress/tokens to taste;
///         the token0()/token1() check prevents USDC.e-vs-native-USDC misregistrations.
contract RegisterALiquidityPool is BaseScript {
    function run() public broadcaster {
        setUp();
        address liquidityPoolRegistryAddress = 0xF0F7B0a68B777539Ff7d416eEAC56E0FB3e8B30C;
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

        // WBTC/USDC 0.05% — canonical via factory.getPool(WBTC, USDC, 500).
        // The previous version of this script seeded the USDC.e pool 0xac70bD92...
        // as if it were native USDC; the token check below would have caught it.
        address poolAddress = 0x0E4831319A50228B9e450861297aB92dee15B44F;
        address token0 = IMinimalPair(poolAddress).token0();
        address token1 = IMinimalPair(poolAddress).token1();
        require(
            (token0 == wbtc && token1 == usdc) || (token0 == usdc && token1 == wbtc),
            "pool token0/token1 mismatch with registration"
        );

        liquidityPoolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: poolAddress, tokenA: wbtc, tokenB: usdc, dexId: uniswapV3, pairName: "WBTC/USDC"
            })
        );
    }
}
