// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { console2 } from "forge-std/console2.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";
import { BaseScript } from "script/Base.s.sol";

contract CreateGarden is BaseScript {
    function run() public broadcaster {
        setUp();

        address factoryAddress = 0x5b0A5Ee185728C5Babc0B877A7eF4E9d47f32A77;
        address gardenAddress = GardenFactory(factoryAddress).createGarden(3, address(0), 0);
        console2.log("Garden deployed at:", gardenAddress);
    }
}
