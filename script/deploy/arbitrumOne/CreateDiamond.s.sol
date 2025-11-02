// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/Console.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";

contract CreateSimpleDiamond is Script {
    function run() external {
        address factoryAddress = 0xaBbBDD1d5a4E731b6384DD0c622a8C24B26a60c1;
        vm.startBroadcast();
        address gardenAddress = GardenFactory(factoryAddress).createGarden(2);
        console.log("Garden deployed at:", gardenAddress);
        vm.stopBroadcast();
    }
}
