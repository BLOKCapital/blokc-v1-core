// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";
import { BaseScript } from "../../Base.s.sol";

contract CreateDiamond is BaseScript {
    function run() public broadcaster {
        setUp();
        address factoryAddress = 0x7F54Bc6708b9D76F0B7c9dd46Af6d3dC5d3b40a7;
        address gardenAddress = GardenFactory(factoryAddress).createGarden(3);
        console.log("Garden deployed at:", gardenAddress);
    }
}
