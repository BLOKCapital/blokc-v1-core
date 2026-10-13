// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";
import { IGardenFactory } from "src/interfaces/IGardenFactory.sol";
import { IUpgrade } from "src/garden/facets/baseFacets/upgrade/IUpgrade.sol";
import { IIndex } from "src/garden/facets/indexFacets/IIndex.sol";

/// @dev configureIndexModule is a public IndexFacet function not part of IIndex;
///      the diamond accepts the matching selector regardless of interface.
interface IIndexConfigurator {
    function configureIndexModule(address indexFactory, address indexComponentRegistry, address poolRegistry) external;
}

/// @dev configureFeeModule is a public FeeFacet function (fee sessions are mandatory
///      before connect — FeeFacet_FeeModuleNotConfigured otherwise).
interface IFeeConfigurator {
    function configureFeeModule(address feeRegistry, address treasuryRegistry, address onboarderRegistry) external;
}

/// @dev approveTokens is a public ApproveFacet function (INDEX module) — grants the
///      CumulativeRebalancer pull allowances. Must run BEFORE connect: approvals are
///      blocked while a fee session (recorded basis) is active.
interface IApprover {
    function approveTokens(address[] calldata tokens, address spender) external;
}

/**
 * @title DeployGardens
 * @notice Creates the three launch INDEX gardens (one per index) on the fresh
 *         GardenFactory: createGarden -> two-step module upgrade -> configure the
 *         INDEX module -> configure the FEES module -> grant rebalancer allowances ->
 *         connect to the index.
 *
 *         Garden indices: 1 (BLOKC2), 2 (BLOKC5), 3 (BLOKC10).
 *         All gardens are deployer-owned (no DAO transfer at deploy time).
 *
 *         Env (all required):
 *         - GARDEN_FACTORY_ADDRESS
 *         - INDEX_FACTORY_ADDRESS
 *         - INDEX_COMPONENT_REGISTRY_ADDRESS
 *         - POOL_REGISTRY_ADDRESS
 *         - BLOKC2_INDEX_ADDRESS / BLOKC5_INDEX_ADDRESS / BLOKC10_INDEX_ADDRESS
 *         - FEE_REGISTRY_ADDRESS / TREASURY_REGISTRY_ADDRESS / ONBOARDER_REGISTRY_ADDRESS
 *         - REBALANCER_ADDRESS (granted max pull allowances on every component + USDC)
 */
contract DeployGardens is BaseScript {
    bytes32 internal constant INDEX_GARDEN = keccak256("INDEX");

    /// @dev The 13 registered component symbols — allowances cover every token the
    ///      Rebalancer may pull (including USDC, which is a registered component).
    bytes32[13] internal COMPONENT_SYMBOLS = [
        bytes32("BTC"),
        bytes32("ETH"),
        bytes32("USDC"),
        bytes32("LINK"),
        bytes32("UNI"),
        bytes32("ARB"),
        bytes32("AAVE"),
        bytes32("GMX"),
        bytes32("PENDLE"),
        bytes32("GRT"),
        bytes32("CRV"),
        bytes32("ZRO"),
        bytes32("DAI")
    ];

    struct GardenSpec {
        uint256 factoryIndex;
        address indexAddress;
        string label;
    }

    function run() public broadcaster {
        setUp();

        address factoryAddress = vm.envAddress("GARDEN_FACTORY_ADDRESS");
        address indexFactory = vm.envAddress("INDEX_FACTORY_ADDRESS");
        address componentRegistry = vm.envAddress("INDEX_COMPONENT_REGISTRY_ADDRESS");
        address poolRegistry = vm.envAddress("POOL_REGISTRY_ADDRESS");
        address feeRegistry = vm.envAddress("FEE_REGISTRY_ADDRESS");
        address treasuryRegistry = vm.envAddress("TREASURY_REGISTRY_ADDRESS");
        address onboarderRegistry = vm.envAddress("ONBOARDER_REGISTRY_ADDRESS");
        address rebalancer = vm.envAddress("REBALANCER_ADDRESS");

        GardenSpec[3] memory specs = [
            GardenSpec(1, vm.envAddress("BLOKC2_INDEX_ADDRESS"), "BLOKC2"),
            GardenSpec(2, vm.envAddress("BLOKC5_INDEX_ADDRESS"), "BLOKC5"),
            GardenSpec(3, vm.envAddress("BLOKC10_INDEX_ADDRESS"), "BLOKC10")
        ];

        for (uint256 i = 0; i < specs.length; i++) {
            GardenSpec memory spec = specs[i];
            console2.log("=== creating garden", spec.label, "===");

            address garden = IGardenFactory(factoryAddress).createGarden(spec.factoryIndex, INDEX_GARDEN);
            console2.log("garden created at:", garden);

            // Two-step module install: read the pending cuts + hash, then apply.
            (, bytes32 hashData) = IUpgrade(garden).upgradeDetails();
            IUpgrade(garden).upgrade(hashData);
            console2.log("modules upgraded");

            // Wire the INDEX module to the fresh index infrastructure.
            IIndexConfigurator(garden).configureIndexModule(indexFactory, componentRegistry, poolRegistry);
            console2.log("INDEX module configured");

            // Wire the FEES module — mandatory before connect (canonical-validated).
            IFeeConfigurator(garden).configureFeeModule(feeRegistry, treasuryRegistry, onboarderRegistry);
            console2.log("FEES module configured");

            // Grant the Rebalancer pull allowances BEFORE connect (approvals are blocked
            // while a fee session is active; allowances persist across sessions)
            address[] memory tokens = new address[](13);
            for (uint256 j = 0; j < 13; j++) {
                tokens[j] = IComponentLookup(componentRegistry).getComponentAddress(COMPONENT_SYMBOLS[j]);
            }
            IApprover(garden).approveTokens(tokens, rebalancer);
            console2.log("rebalancer allowances granted");

            // Connect to the freshly deployed index contract.
            IIndex(garden).connectToIndex(spec.indexAddress);
            console2.log("connected to index:", spec.indexAddress);
        }
    }
}

/// @dev getComponentAddress is a public IndexComponentRegistry function.
interface IComponentLookup {
    function getComponentAddress(bytes32 symbol) external view returns (address);
}
