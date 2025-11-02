//SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";
import { BaseScript } from "../../Base.s.sol";
import { console } from "forge-std/Console.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";
import { Diamond } from "src/diamond/Diamond.sol";
import { UpgradeFacet } from "src/diamond/facets/baseFacets/UpgradeFacet.sol";
import { IDiamondCut } from "src/interfaces/IDiamondCut.sol";

contract UpgradeDiamond is Script {
    address internal gardenAddress = 0xB53d797EE9b946C8274d770770D156f6CE934141;

    function run() external {
        IDiamondCut.FacetCut[] memory facetCuts;
        uint256 registryVersion;
        bytes32 hashData;
        vm.startBroadcast();
        (facetCuts, registryVersion, hashData) = UpgradeFacet(gardenAddress).upgradeDetails();
        UpgradeFacet(gardenAddress).upgrade(hashData);
        vm.stopBroadcast();
    }
}
