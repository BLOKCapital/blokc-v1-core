// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";

contract CreateSimpleDiamond is Script {
    function run() external {
        address factoryAddress = 0x6764F610F1C70Ac319ebc0F41B6ebb5202F5712f;
        vm.startBroadcast();
        address gardenAddress = GardenFactory(factoryAddress).createGarden(2);
        console.log("Garden deployed at:", gardenAddress);
        vm.stopBroadcast();
    }
}
