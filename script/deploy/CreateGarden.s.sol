// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { console2 } from "forge-std/console2.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";
import { BaseScript } from "script/Base.s.sol";
import { UpgradeFacet } from "src/garden/facets/baseFacets/upgrade/UpgradeFacet.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";

contract CreateGarden is BaseScript {
    function run() public broadcaster {
        setUp();

        address factoryAddress = 0xb2f6612C527a85CA3C5C3EEC5fb4F4Cfe42CEE79;
        address gardenAddress = GardenFactory(factoryAddress).createGarden(1, keccak256("YIELD"));
        console2.log("Garden deployed at:", gardenAddress);

        // Install utility modules via upgrade (required after BASE-only deployment)
        (IDiamondCut.FacetCut[] memory facetCuts, bytes32 hashData) = UpgradeFacet(gardenAddress).upgradeDetails();
        console2.log("Installing utility modules...");
        console2.logBytes32(hashData);
        UpgradeFacet(gardenAddress).upgrade(hashData);
        console2.log("Utility modules installed successfully");
    }
}
