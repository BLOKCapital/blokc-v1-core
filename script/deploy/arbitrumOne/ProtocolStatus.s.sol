//SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { Script } from "forge-std/Script.sol";
import { BaseScript } from "../../Base.s.sol";
import { console } from "forge-std/Console.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";

contract UpgradeDiamond is Script {
    address internal protocolStatusAddress = 0x55d302eB35BB3c1064e9a7dcD9a40C8577262cE8;

    function run() external {
        vm.startBroadcast();
        IProtocolStatus(protocolStatusAddress).activateProtocol();
        vm.stopBroadcast();
    }
}
