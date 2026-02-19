//SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";
import { UpgradeFacet } from "src/garden/facets/baseFacets/upgrade/UpgradeFacet.sol";

contract UpgradeGarden is BaseScript {
    function run() public broadcaster {
        setUp();
        address garden = 0xe4A134aAFac77585d0d2D5623a676a8EE2727A2e;
        (, bytes32 hashData) = UpgradeFacet(garden).upgradeDetails();
        console2.logBytes32(hashData);
        UpgradeFacet(garden).upgrade(hashData);
    }
}
