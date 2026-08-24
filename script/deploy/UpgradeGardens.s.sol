// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";
import { IUpgrade } from "src/garden/facets/baseFacets/upgrade/IUpgrade.sol";
import { IndexComponentRegistry } from "src/indices/IndexComponentRegistry.sol";

/// @dev approveTokens is an ApproveFacet function not part of any garden interface;
///      the diamond accepts the matching selector regardless of interface.
interface IApproveTokens {
    function approveTokens(address[] calldata tokens, address spender) external;
}

/**
 * @title UpgradeGardens
 * @notice Finishes the Phase G garden wiring on the fresh deployment:
 *         1. Per garden: two-step upgrade (upgradeDetails -> upgrade) to install the
 *            ApproveFacet that was just added to the INDEX module in the registry.
 *         2. Resolve the garden's component tokens from the fresh IndexComponentRegistry
 *            and grant the CumulativeRebalancer max allowance (ApproveFacet.approveTokens).
 *
 *         The Rebalancer pulls component balances from gardens via safeTransferFrom,
 *         which requires the garden (as token holder) to approve first — the missing
 *         production mechanism this script wires up.
 *
 *         Env (all required):
 *         - REBALANCER_ADDRESS
 *         - INDEX_COMPONENT_REGISTRY_ADDRESS
 */
contract UpgradeGardens is BaseScript {
    address internal constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    struct GardenSpec {
        address garden;
        bytes32[] symbols;
        string label;
    }

    function run() public broadcaster {
        setUp();

        address rebalancer = vm.envAddress("REBALANCER_ADDRESS");
        IndexComponentRegistry registry = IndexComponentRegistry(vm.envAddress("INDEX_COMPONENT_REGISTRY_ADDRESS"));

        bytes32[] memory s2 = _symbols(2);
        s2[0] = bytes32("BTC");
        s2[1] = bytes32("ETH");

        bytes32[] memory s5 = _symbols(5);
        s5[0] = bytes32("BTC");
        s5[1] = bytes32("ETH");
        s5[2] = bytes32("LINK");
        s5[3] = bytes32("UNI");
        s5[4] = bytes32("ARB");

        bytes32[] memory s10 = _symbols(10);
        s10[0] = bytes32("LINK");
        s10[1] = bytes32("UNI");
        s10[2] = bytes32("ARB");
        s10[3] = bytes32("AAVE");
        s10[4] = bytes32("GMX");
        s10[5] = bytes32("PENDLE");
        s10[6] = bytes32("GRT");
        s10[7] = bytes32("CRV");
        s10[8] = bytes32("ZRO");
        s10[9] = bytes32("DAI");

        GardenSpec[3] memory specs = [
            GardenSpec({ garden: 0xF5FdB99aB9464A3855417Ac8C69505c8F9784e34, symbols: s2, label: "BLOKC2" }),
            GardenSpec({ garden: 0x68AA9A57475F00bc5d8BE8CFA6CD1200C2478A79, symbols: s5, label: "BLOKC5" }),
            GardenSpec({ garden: 0x4c8e9eA85a5e95f2519338a96E48163bE251f1A0, symbols: s10, label: "BLOKC10" })
        ];

        for (uint256 i = 0; i < specs.length; i++) {
            GardenSpec memory spec = specs[i];
            console2.log("=== upgrading garden", spec.label, "===");

            // 1. Two-step upgrade installs the ApproveFacet (INDEX module v2).
            (, bytes32 hashData) = IUpgrade(spec.garden).upgradeDetails();
            IUpgrade(spec.garden).upgrade(hashData);
            console2.log("ApproveFacet installed");

            // 2. Resolve the garden's component tokens from the fresh registry, plus
            //    USDC (not a component of any launch index — pulled separately).
            address[] memory tokens = new address[](spec.symbols.length + 1);
            for (uint256 j = 0; j < spec.symbols.length; j++) {
                tokens[j] = registry.getComponentAddress(spec.symbols[j]);
            }
            tokens[spec.symbols.length] = USDC;

            // 3. Grant the Rebalancer max allowance to pull these tokens.
            IApproveTokens(spec.garden).approveTokens(tokens, rebalancer);
            console2.log("approved", spec.symbols.length + 1, "tokens to rebalancer", rebalancer);
        }
    }

    function _symbols(uint256 n) internal pure returns (bytes32[] memory symbols) {
        symbols = new bytes32[](n);
    }
}
