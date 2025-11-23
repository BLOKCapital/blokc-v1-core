//SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";
import { BaseScript } from "../../Base.s.sol";
import { console } from "forge-std/Console.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";
import { Diamond } from "src/diamond/Diamond.sol";
import { UpgradeFacet } from "src/diamond/facets/baseFacets/upgrade/UpgradeFacet.sol";
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";

contract UpgradeDiamond is Script {
    address internal gardenAddress = 0xfeA3b7BcbB6123ffa55c9219e74374bE3c74369A;

    function run() external {
        IDiamondCut.FacetCut[] memory facetCuts;
        uint256 diamondVersion;
        uint256 registryVersion;
        bytes32 hashData;
        vm.startBroadcast();
        (facetCuts, diamondVersion, registryVersion, hashData) = UpgradeFacet(gardenAddress).upgradeDetails();
        UpgradeFacet(gardenAddress).upgrade(hashData);
        vm.stopBroadcast();
    }
}
