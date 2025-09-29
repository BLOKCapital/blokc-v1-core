// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.20;

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
        bytes32 privateKey = vm.envBytes32("PRIVATE_KEY_ANVIL");
        deployer = vm.rememberKey(uint256(privateKey));
        salt = vm.envBytes32("SALT");
    }
}
