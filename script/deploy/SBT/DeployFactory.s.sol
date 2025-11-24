// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import { SBTMembershipFactory } from "src/MembershipPass/factory/SBTMembershipFactory.sol";
import { IERC5484 } from "src/interfaces/IERC5484.sol";

contract DeployFactory is Script {
    // CHANGE THIS BEFORE DEPLOYING — this address becomes DAO owner
    address constant DAO_OWNER = 0x1234567890123456789012345678901234567890;

    function run() external {
        vm.startBroadcast();

        // 1. Deploy factory with DAO owner
        SBTMembershipFactory factory = new SBTMembershipFactory(DAO_OWNER);
        console2.log("Factory deployed at:", address(factory));

        // 2. Deploy a sample collection from the factory
        address kso = factory.deployCollection(
            "KSO",
            "KSO",
            "Key Stakeholder Pass",
            "bafy-kso-cid",
            0, // unlimited supply
            IERC5484.BurnAuth.Neither, // burn disabled
            SBTMembershipFactory.MintPolicy.DAO_ONLY
        );

        console2.log("KSO Collection deployed:", kso);

        vm.stopBroadcast();
    }
}
