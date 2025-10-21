//SPDX-License-Identifier: MIT// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;pragma solidity ^0.8.20;



import { Script, console } from "forge-std/Script.sol";import { Script } from "forge-std/Script.sol";

import { BaseScript } from "script/Base.s.sol";

contract FundReceiver is Script {import { console } from "forge-std/console.sol";

    address constant RECEIVER_V3 = 0x282ce4546171A68655b385F8752F77bd8c8cAd1F;

    uint256 constant FUNDING_AMOUNT = 0.01 ether; // Small amount for gascontract FundReceiver is BaseScript {

        // Base chain deployed addresses

    function run() external {    address constant RECEIVER = 0xf9E84F4E6b578A400e2F45f88c364E376d27e879;

        console.log("=== FUNDING RECEIVER FOR GAS ===");

        console.log("Receiver V3:", RECEIVER_V3);    function run() public broadcaster {

        console.log("Funding Amount:", FUNDING_AMOUNT);        setUp();

        console.log("Network: Base Mainnet");        

        console.log("");        console.log("Funding FacetRegistryReceiver contract...");

                console.log("Receiver:", RECEIVER);

        uint256 privateKey = vm.envUint("PRIVATE_KEY");        

        address sender = vm.addr(privateKey);        // Send 0.01 ETH to the receiver for gas execution

        console.log("Sender:", sender);        uint256 fundAmount = 0.01 ether;

                console.log("Funding amount:", fundAmount);

        vm.startBroadcast(privateKey);        

                (bool success,) = payable(RECEIVER).call{value: fundAmount}("");

        // Send ETH to receiver for execution gas        require(success, "Failed to send ETH");

        payable(RECEIVER_V3).transfer(FUNDING_AMOUNT);        

                console.log("Receiver funded successfully!");

        vm.stopBroadcast();        console.log("New balance:", RECEIVER.balance);

            }

        console.log("");}
        console.log("SUCCESS: Receiver funded with", FUNDING_AMOUNT);
        console.log("This provides gas for CCIP execution on Base chain");
    }
}