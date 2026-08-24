// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.31;

import { Script } from "forge-std/Script.sol";

contract BaseScript is Script {
    address internal deployer;
    bytes32 internal salt;

    modifier broadcaster() {
        vm.startBroadcast(deployer);
        _;
        vm.stopBroadcast();
    }

    function setUp() public virtual {
        bytes32 privateKey = vm.envBytes32("PRIVATE_KEY_ARB");
        deployer = vm.rememberKey(uint256(privateKey));
        salt = vm.envBytes32("SALT");

        // Optional chain guard: set EXPECTED_CHAIN_ID to hard-fail a script on the
        // wrong network (e.g. 42161 for Arbitrum One). Unset = no-op, so scripts
        // targeting other chains keep working.
        uint256 expectedChainId = vm.envOr("EXPECTED_CHAIN_ID", uint256(0));
        if (expectedChainId != 0) {
            require(block.chainid == expectedChainId, "BaseScript: wrong chain id");
        }
    }
}
