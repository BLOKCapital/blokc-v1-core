// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/Console.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";

contract CreateSimpleDiamond is Script {
    function run() external {
        address factoryAddress = 0x7951acCabF82944AC825DADD55e1c1C4A3B7f5f2;
        vm.startBroadcast();
        GardenFactory(factoryAddress).createGarden(2);
        vm.stopBroadcast();
    }
}
