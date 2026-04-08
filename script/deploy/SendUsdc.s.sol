//SPDX-License-Identifier: MIT License
pragma solidity ^0.8.31;

import { Script } from "forge-std/Script.sol";
import { BaseScript } from "script/Base.s.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SendUsdc is BaseScript {
    function run() public broadcaster {
        setUp();
        address recipient = 0xbf6c9469F9da6D9961BE061e20A6bDDf97C5E17F; // Replace with actual recipient address
        uint256 amount = 10 ** 5; // Amount of USDC to send (6 decimals)

        // USDC contract address on Arbitrum One
        address usdcAddress = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

        // Create an instance of the USDC token contract
        IERC20 usdc = IERC20(usdcAddress);

        // Send USDC to the recipient
        usdc.transfer(recipient, amount);
    }
}
