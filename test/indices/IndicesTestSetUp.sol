// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { Test } from "forge-std/Test.sol";

import { MockOracle } from "../mock/MockPriceFeed.sol";
import { IndexComponentRegistry } from "../../src/indices/IndexComponentRegistry.sol";
import {IndexCalculationRegistry} from "../../src/indices/IndexCalculationRegistry.sol";
// ═══════════════════════════════════════════════════════════════════════
//                         SetUp
// ═══════════════════════════════════════════════════════════════════════

contract IndicesTestSetUp is Test {
    IndexComponentRegistry icr;
    IndexCalculationRegistry indexCalRegistry;

    MockOracle btcPriceFeed;
    MockOracle ethPriceFeed;

    uint256 btcPrice = 70_000e18;
    uint256 ethPrice = 3000e18;

    address owner = makeAddr("owner");
    address btcAddress = makeAddr("BTC");
    address ethAddress = makeAddr("ETH");

    IndexComponentRegistry.Component[] components;
    string[] symbol;

    function setUp() public {
        // deploy BTC price feed
        btcPriceFeed = new MockOracle("BTC", btcPrice);
        ethPriceFeed = new MockOracle("ETH", ethPrice);

        // store symbol in array
        symbol.push("BTC");
        symbol.push("ETH");

        // deploy componentRegistry
        icr = new IndexComponentRegistry(owner);
        indexCalRegistry = new IndexCalculationRegistry(owner);

        // component
        components.push(
            IndexComponentRegistry.Component({
                symbol: "BTC", tokenAddress: btcAddress, priceFeedAddress: address(btcPriceFeed), heartbeat: 3600
            })
        );

        components.push(
            IndexComponentRegistry.Component({
                symbol: "ETH", tokenAddress: ethAddress, priceFeedAddress: address(ethPriceFeed), heartbeat: 3600
            })
        );
    }
}
