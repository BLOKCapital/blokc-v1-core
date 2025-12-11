//SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";
import { UpgradeFacet } from "src/diamond/facets/baseFacets/upgrade/UpgradeFacet.sol";

contract UpgradeGarden is BaseScript {
    function run() public broadcaster {
        setUp();
        address garden = 0x230d1b539FA02E7686B4F9F455De1eC644D45d7e;
        (,,, bytes32 hashData) = UpgradeFacet(garden).upgradeDetails();
        console2.logBytes32(hashData);
        UpgradeFacet(garden).upgrade(hashData);
    }
}
