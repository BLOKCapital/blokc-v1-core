// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { Test } from "forge-std/Test.sol";

import { MockOracle } from "../mock/MockPriceFeed.sol";
import { IndexComponentRegistry } from "../../src/indices/IndexComponentRegistry.sol";
import { IndexCalculationRegistry } from "../../src/indices/IndexCalculationRegistry.sol";
import { CirculatingSupply } from "../../src/indices/CirculatingSupply.sol";
import { MarketCapWeighted } from "../../src/indices/indexCalculations/MarketCapWeighted.sol";
// ═══════════════════════════════════════════════════════════════════════
//                         SetUp
// ═══════════════════════════════════════════════════════════════════════

contract IndicesTestSetUp is Test {
    IndexComponentRegistry icr;
    IndexCalculationRegistry indexCalRegistry;
    CirculatingSupply cirSupply;
    MarketCapWeighted marketCapWeighted;

    MockOracle btcPriceFeed;
    MockOracle ethPriceFeed;

    uint256 btcPrice = 70_000e18;
    uint256 ethPrice = 3000e18;

    address owner = makeAddr("owner");
    address btcAddress = makeAddr("BTC");
    address ethAddress = makeAddr("ETH");
    address updater = makeAddr("Updater");

    IndexComponentRegistry.Component[] components;
    bytes32[] symbol;
    uint256[] supply;

    function setUp() public virtual {
        // deploy BTC price feed
        btcPriceFeed = new MockOracle("BTC", btcPrice);
        ethPriceFeed = new MockOracle("ETH", ethPrice);

        // store symbol in array
        symbol.push(bytes32("BTC"));
        supply.push(1);
        symbol.push(bytes32("ETH"));
        supply.push(2);

        // deploy componentRegistry
        icr = new IndexComponentRegistry(owner);

        // component
        components.push(
            IndexComponentRegistry.Component({
                symbol: bytes32("BTC"),
                tokenAddress: btcAddress,
                priceFeedAddress: address(btcPriceFeed),
                heartbeat: 3600
            })
        );

        components.push(
            IndexComponentRegistry.Component({
                symbol: bytes32("ETH"),
                tokenAddress: ethAddress,
                priceFeedAddress: address(ethPriceFeed),
                heartbeat: 3600
            })
        );
        // register component
        vm.startPrank(owner);
        icr.registerComponents(components);
        vm.stopPrank();

        // deploy Indec Calculation Registry
        indexCalRegistry = new IndexCalculationRegistry(owner);

        // deploy CirculatingSupply
        cirSupply = new CirculatingSupply(owner, updater, address(icr));
        assertEq(updater, cirSupply.updater());

        // add supply
        vm.startPrank(updater);
        cirSupply.updateBatch(symbol, supply);
        vm.stopPrank();

        // deploy MarketCapWeighted

        marketCapWeighted = new MarketCapWeighted(address(icr), address(cirSupply));
        assertEq(marketCapWeighted.getCirculatingSupply(), address(cirSupply));
        assertEq(marketCapWeighted.getIndexComponentRegistry(), address(icr));
    }
}
