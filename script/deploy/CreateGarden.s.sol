// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { console2 } from "forge-std/console2.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";
import { BaseScript } from "script/Base.s.sol";
import { UpgradeFacet } from "src/garden/facets/baseFacets/upgrade/UpgradeFacet.sol";

contract CreateGarden is BaseScript {
    function run() public broadcaster {
        setUp();

        address factoryAddress = 0x51Ab0Cc9898CD10EC5522e0D520Ae634d0165C62;
        address gardenAddress = GardenFactory(factoryAddress).createGarden(3, address(0), 0, keccak256("default"));
        (, bytes32 hashData) = UpgradeFacet(gardenAddress).upgradeDetails();
        console2.logBytes32(hashData);
        UpgradeFacet(gardenAddress).upgrade(hashData);
        console2.log("Garden deployed at:", gardenAddress);
    }
}
