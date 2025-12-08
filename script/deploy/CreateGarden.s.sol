// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";
import { BaseScript } from "script/Base.s.sol";

contract CreateGarden is BaseScript {
    function run() public broadcaster {
        setUp();

        address factoryAddress = 0xB16AA42eB452513e8Bc15952ab6c30b296dedFc7;
        address gardenAddress = GardenFactory(factoryAddress).createGarden(3, address(0), 0);
        console.log("Garden deployed at:", gardenAddress);
    }
}
