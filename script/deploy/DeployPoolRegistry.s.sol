//SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Script } from "forge-std/Script.sol";
import { BaseScript } from "script/Base.s.sol";
import { PoolRegistry } from "src/liquidityPoolRegistry/PoolRegistry.sol";
import { console2 } from "forge-std/console2.sol";

contract DeployPoolRegistry is BaseScript {
    function run() public broadcaster {
        setUp();
        PoolRegistry poolRegistry = new PoolRegistry(deployer);
        console2.log("PoolRegistry deployed at:", address(poolRegistry));

        bytes32 protocolId = keccak256("UNISWAP_V3");
        address wethAddress = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

        //WETH/USDC - Uniswap V3
        address poolAddressWethUsdc = 0xC6962004f452bE9203591991D15f6b388e09E8D0;
        address usdcAddress = 0xC6962004f452bE9203591991D15f6b388e09E8D0;
        string memory pairName1 = "WETH/USDC";

        poolRegistry.addPool(poolAddressWethUsdc, usdcAddress, wethAddress, protocolId, pairName1);

        // WETH/WBTC - Uniswap V3
        address poolAddressWethWbtc = 0x905dfCD5649217c42684f23958568e533C711Aa3;
        address wbtcAddress = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
        string memory pairName2 = "WETH/WBTC";

        poolRegistry.addPool(poolAddressWethWbtc, wbtcAddress, wethAddress, protocolId, pairName2);

        // WETH/LINK - Uniswap V3
        address poolAddressWethLink = 0x468b88941e7Cc0B88c1869d68ab6b570bCEF62Ff;
        address linkAddress = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
        string memory pairName3 = "WETH/LINK";

        poolRegistry.addPool(poolAddressWethLink, linkAddress, wethAddress, protocolId, pairName3);

        //WETH/ARB - Uniswap V3
        address poolAddressWethArb = 0xC6F780497A95e246EB9449f5e4770916DCd6396A;
        address arbAddress = 0x912CE59144191C1204E64559FE8253a0e49E6548;
        string memory pairName4 = "WETH/ARB";

        poolRegistry.addPool(poolAddressWethArb, arbAddress, wethAddress, protocolId, pairName4);

        // WETH/UNI - Uniswap V3
        address poolAddressWethUni = 0xC24f7d8E51A64dc1238880BD00bb961D54cbeb29;
        address uniAddress = 0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0;
        string memory pairName5 = "WETH/UNI";

        poolRegistry.addPool(poolAddressWethUni, uniAddress, wethAddress, protocolId, pairName5);
    }
}
