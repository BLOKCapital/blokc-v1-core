//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";

contract CheckCurrentAccount is Script {
    function run() external view {
        console.log("=== CHECKING CURRENT ACCOUNT ===");
        
        // Check if PRIVATE_KEY is set
        try vm.envString("PRIVATE_KEY") returns (string memory privateKeyStr) {
            console.log("PRIVATE_KEY environment variable is set");
            console.log("Length:", bytes(privateKeyStr).length);
            
            // Try to convert to uint256
            try vm.envUint("PRIVATE_KEY") returns (uint256 privateKey) {
                address currentAccount = vm.addr(privateKey);
                console.log("Your current account:", currentAccount);
                console.log("Required owner account:", 0x3716aC26d58c3E75BAd3C90A21F93B4c31cC518F);
                console.log("Match:", currentAccount == 0x3716aC26d58c3E75BAd3C90A21F93B4c31cC518F);
                
                if (currentAccount != 0x3716aC26d58c3E75BAd3C90A21F93B4c31cC518F) {
                    console.log("");
                    console.log("ISSUE: Your private key is for a different account!");
                    console.log("You need the private key for:", 0x3716aC26d58c3E75BAd3C90A21F93B4c31cC518F);
                }
            } catch {
                console.log("ERROR: PRIVATE_KEY format is invalid");
                console.log("It should be a hex number like: 0x1234... or just the hex without 0x");
            }
            
        } catch {
            console.log("ERROR: PRIVATE_KEY environment variable is not set");
            console.log("Run: export PRIVATE_KEY=your_private_key_here");
        }
    }
}