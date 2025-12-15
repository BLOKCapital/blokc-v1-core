// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import { SBTMembershipFactory } from
    "src/MembershipPass/factory/SBTMembershipFactory.sol";

contract DeployFactory is Script {
    // DAO / protocol owner
    address constant DAO_OWNER =
        0xe233e3F36674A744d62e52d032a2126EF6aDCbC5;

    function run() external {
        vm.startBroadcast();

        // Deploy factory
        SBTMembershipFactory factory =
            new SBTMembershipFactory(DAO_OWNER);

        console2.log("SBTMembershipFactory deployed at:", address(factory));
        console2.log("Factory owner (DAO):", DAO_OWNER);

        vm.stopBroadcast();
    }
}
