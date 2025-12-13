// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";
import { BaseScript } from "script/Base.s.sol";

contract CreateGarden is BaseScript {
    function run() public broadcaster {
        setUp();

        address factoryAddress = 0xBcf477512137613e418EbBe47BE3CC5e86C5d592;
        address gardenAddress = GardenFactory(factoryAddress).createGarden(3, address(0), 0);
        console.log("Garden deployed at:", gardenAddress);
    }
}
