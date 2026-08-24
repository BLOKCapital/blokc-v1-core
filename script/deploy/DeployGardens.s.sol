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

/**
 * @title DeployGardens
 * @notice Creates the three launch INDEX gardens (one per index) on the fresh
 *         GardenFactory: createGarden -> two-step module upgrade -> configure
 *         the INDEX module -> connect to the index.
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
 */
contract DeployGardens is BaseScript {
    bytes32 internal constant INDEX_GARDEN = keccak256("INDEX");

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

            // Connect to the freshly deployed index contract.
            IIndex(garden).connectToIndex(spec.indexAddress);
            console2.log("connected to index:", spec.indexAddress);
        }
    }
}
