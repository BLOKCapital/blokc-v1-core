//SPDX-Lincense-Identifier: MIT
pragma solidity >=0.8.20;

import { BaseScript } from "../../Base.s.sol";
import { console2 } from "forge-std/console2.sol";
import { ProtocolStatus } from "src/protocolStatus/ProtocolStatus.sol";

import { UpgradeFacet } from "src/diamond/facets/baseFacets/upgrade/UpgradeFacet.sol";

contract UpgradeGarden is BaseScript {
    function run() public broadcaster {
        setUp();
        // ProtocolStatus(0x2E199Fe85936739129711a06b670cA0c421c05E9).activateProtocol();
        address garden = 0x2516F64574d8A67DA334af46a38F08DF2a427Be6;
        (,,, bytes32 hashData) = UpgradeFacet(garden).upgradeDetails();
        console2.logBytes32(hashData);
        UpgradeFacet(garden).upgrade(hashData);
    }
}
