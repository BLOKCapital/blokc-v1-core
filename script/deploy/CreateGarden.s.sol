// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";
import { BaseScript } from "script/Base.s.sol";

contract CreateGarden is BaseScript {
    function run() public broadcaster {
        setUp();

        address factoryAddress = 0x015a9664E332372a06CB625c4bC2D61657088faF;
        address gardenAddress = GardenFactory(factoryAddress).createGarden(3, address(0), 0);
        console.log("Garden deployed at:", gardenAddress);
    }
}
