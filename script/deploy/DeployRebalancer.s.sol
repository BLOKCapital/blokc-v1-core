// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { BaseScript } from "script/Base.s.sol";
import { Rebalancer } from "src/rebalancer/Rebalancer.sol";
import { console2 } from "forge-std/console2.sol";

/**
 * @title DeployRebalancer
 * @notice Deploys the Rebalancer contract on Arbitrum One and configures all DEXs.
 *         The contract is registry-driven — no DEX-specific code is hardcoded.
 *         Adding a new DEX is a single `setDexConfig()` call from the DAO.
 */
contract DeployRebalancer is BaseScript {
    function run() public broadcaster {
        setUp();

        // =====================================================================
        // Deployed Registry Addresses (Arbitrum One)
        // =====================================================================
        address indexFactory = 0x91da26BF1a4adDa42355B80502785d3F026d7074;
        address componentRegistry = 0x3F8291D2Fb3f5C4391DDbc36C4Ee0B1F48274977;
        address poolRegistry = 0xA3178280c191dD46c551b91c651F337E47594d85;
        address facetRegistry = 0xcD06FE7cdCacAed1806E2c29E411d4bD05A51Ef3;

        // =====================================================================
        // Token Addresses (Arbitrum One)
        // =====================================================================
        address usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

        Rebalancer rebalancer = new Rebalancer{ salt: salt }(
            deployer,
            indexFactory,
            componentRegistry,
            poolRegistry,
            facetRegistry,
            usdc
        );

        console2.log("Rebalancer deployed at:", address(rebalancer));
        console2.log("Owner (DAO):", deployer);

        // =====================================================================
        // Configure DEXs (DAO calls setDexConfig per DEX)
        // =====================================================================
        // Uniswap V3
        rebalancer.setDexConfig(
            keccak256("UNISWAP_V3"),
            0xE592427A0AEce92De3Edee1F18E0157C05861564, // router
            0x06eb18FC187Ec0Bf4687e6783DC8cDcB2AD8F97B, // DEX facet (for quoting)
            bytes4(keccak256("exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))")),
            Rebalancer.DexType.V3_CONCENTRATED
        );
        console2.log("Configured Uniswap V3");

        // Camelot V2
        rebalancer.setDexConfig(
            keccak256("CAMELOT_V2"),
            0xc873fEcbd354f5A56E00E710B90EF4201db2448d, // router
            0x06eb18FC187Ec0Bf4687e6783DC8cDcB2AD8F97B, // DEX facet (for quoting)
            bytes4(keccak256("swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256,uint256,address[],address,address,uint256)")),
            Rebalancer.DexType.V2_CONSTANT_PRODUCT
        );
        console2.log("Configured Camelot V2");

        // Camelot V3
        rebalancer.setDexConfig(
            keccak256("CAMELOT_V3"),
            0x1F721E2E82F6676FCE4eA07A5958cF098D339e18, // router
            0x06eb18FC187Ec0Bf4687e6783DC8cDcB2AD8F97B, // DEX facet (for quoting)
            bytes4(keccak256("exactInputSingle((address,address,address,uint256,uint256,uint256,uint160))")),
            Rebalancer.DexType.V3_CONCENTRATED
        );
        console2.log("Configured Camelot V3");

        // Uniswap V2
        rebalancer.setDexConfig(
            keccak256("UNISWAP_V2"),
            0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24, // router
            0x06eb18FC187Ec0Bf4687e6783DC8cDcB2AD8F97B, // DEX facet (for quoting)
            bytes4(keccak256("swapExactTokensForTokens(uint256,uint256,address[],address,uint256)")),
            Rebalancer.DexType.V2_CONSTANT_PRODUCT
        );
        console2.log("Configured Uniswap V2");

        console2.log("");
        console2.log("Next steps:");
        console2.log("1. DAO: rebalancer.addIndexToType(keccak256(\"BLOKC2\"), <blokc2-index-address>)");
        console2.log("2. DAO: rebalancer.addIndexToType(keccak256(\"BLOKC5\"), <blokc5-index-address>)");
        console2.log("3. Garden owners: approve(token).approve(rebalancer, type(uint256).max) for each component + USDC");
        console2.log("4. Anyone: rebalancer.cumulativeRebalance(keccak256(\"BLOKC2\")) after 24h cooldown");

        console2.log("");
        console2.log("To add a new DEX in the future:");
        console2.log("   rebalancer.setDexConfig(DEX_ID, routerAddress, quoteFacetAddress, DEX_TYPE)");
        console2.log("No code changes required for V2/V3-style DEXs.");
    }
}
