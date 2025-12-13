// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { SBTMembershipFactory } from "src/MembershipPass/factory/SBTMembershipFactory.sol";
import { BaseScript } from "script/Base.s.sol";

import { console2 } from "forge-std/console2.sol";

contract DeployFactory is BaseScript {
    // CHANGE THIS BEFORE DEPLOYING — this address becomes DAO owner
    address constant DAO_OWNER = 0xe233e3F36674A744d62e52d032a2126EF6aDCbC5;

    function run() external broadcaster {
        setUp();
        // 1. Deploy factory with DAO owner
        SBTMembershipFactory factory = new SBTMembershipFactory(DAO_OWNER);
        console2.log("Factory deployed at:", address(factory));

        // (KSO REMOVED — no collection deployment here)
    }
}
