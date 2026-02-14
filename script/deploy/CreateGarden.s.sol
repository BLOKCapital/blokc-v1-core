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

        address factoryAddress = 0x15720E9ebC78956c54842C58fAD7B5c6aFdBA1d6;
        address gardenAddress = GardenFactory(factoryAddress).createGarden(3, address(0), 0, keccak256("INDEX"));
        console2.log("Garden deployed at:", gardenAddress);

        // Try to upgrade if upgrades are available
        try UpgradeFacet(gardenAddress).upgradeDetails() returns (
            IDiamondCut.FacetCut[] memory facetCuts, bytes32 hashData
        ) {
            if (facetCuts.length > 0) {
                console2.log("Upgrades available, applying upgrade...");
                console2.logBytes32(hashData);
                UpgradeFacet(gardenAddress).upgrade(hashData);
                console2.log("Upgrade applied successfully");
            } else {
                console2.log("No upgrades available - garden is already at latest version");
            }
        } catch {
            console2.log("No upgrades available - garden is already at latest version");
        }
    }
}
