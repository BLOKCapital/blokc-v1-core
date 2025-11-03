// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/Console.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";

contract CreateSimpleDiamond is Script {
    function run() external {
        address factoryAddress = 0x950B29f718b406e7318771a97E1C5A19D7A23b3e;
        vm.startBroadcast();
        address gardenAddress = GardenFactory(factoryAddress).createGarden(2);
        console.log("Garden deployed at:", gardenAddress);
        vm.stopBroadcast();
    }
}
