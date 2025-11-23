//SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { GardenFactory } from "src/factory/GardenFactory.sol";
import { BaseScript } from "../../Base.s.sol";
import { console2 } from "forge-std/console2.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployGardenFactory is BaseScript {
    GardenFactory internal factoryImpl;
    TransparentUpgradeableProxy internal factoryProxy;

    function run() public broadcaster {
        setUp();
        address facetRegistry = 0x87ba7413Ad16fbC3bfC47FDB8b000318145d3fD8;
        address protocolStatus = 0x71E2cBE71482BA0B990803F55717aF75E9c2b487;
        // --- Deploy GardenFactory implementation & transparent proxy ---
        factoryImpl = new GardenFactory{ salt: salt }();

        bytes memory factoryInitData =
            abi.encodeWithSelector(GardenFactory.initialize.selector, deployer, facetRegistry, protocolStatus);

        factoryProxy = new TransparentUpgradeableProxy{ salt: salt }(address(factoryImpl), deployer, factoryInitData);

        console2.log("GardenFactory proxy deployed at:", address(factoryProxy));
        console2.log("GardenFactory implementation at:", address(factoryImpl));
    }
}
