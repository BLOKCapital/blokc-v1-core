// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Test } from "forge-std/Test.sol";

import { IndicesTestSetUp } from "test/indices/IndicesTestSetUp.sol";
import { MockOracle } from "test/mock/MockPriceFeed.sol";
import { IndexComponentRegistry } from "src/indices/IndexComponentRegistry.sol";
import { MarketCapWeighted } from "../../../src/indices/indexCalculations/MarketCapWeighted.sol";
import {
    MarketCapWeighted,
    MarketCapWeighted_ZeroAddress,
    MarketCapWeighted_InvalidTotalMarketCap,
    MarketCapWeighted_MarketCapOverflow,
    MarketCapWeighted_MarketCapExceedsSanityBound,
    MarketCapWeighted_ComponentWeightBelowMinimum
} from "../../../src/indices/indexCalculations/MarketCapWeighted.sol";
import { IndexMath } from "src/indices/libraries/IndexMath.sol";

contract MarketCapWeightedTest is IndicesTestSetUp {
    // ═══════════════════════════════════════════════════════════════════════
    //                     Constructor -- Revert
    // ═══════════════════════════════════════════════════════════════════════

    function test_constructor_zeroAddress_indexComponentRegistry() public {
        vm.expectRevert(MarketCapWeighted_ZeroAddress.selector);
        marketCapWeighted = new MarketCapWeighted(address(0), address(cirSupply));
    }

    function test_constructor_zeroAddress_circulatingSupply() public {
        vm.expectRevert(MarketCapWeighted_ZeroAddress.selector);
        marketCapWeighted = new MarketCapWeighted(address(icr), address(0));
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                     getWeights
    // ═══════════════════════════════════════════════════════════════════════

    function test_getWeights() public {
        uint256[] memory weights = marketCapWeighted.getWeights(symbol);

        assertEq(symbol.length, weights.length);

        /**
         * Calculation
         * BTC
         * Supply - 1
         * Price - 70_000e18 -- While calculation Decimal is removed
         * Total Market Cap of BTC - 70000
         * Total Market Cap = 70_000
         *
         * ETH
         * Supply - 2
         * Price - 3000e18
         * Toatl MArket Cap of ETH - 6_000
         * Total Market cap = 76_000
         *
         * Now each component calculation part - Its calculated in 1e18 precision
         * For further calcualtion will be using Library Math
         */

        uint256 btcWeight = IndexMath.calculateWeight(70_000, 76_000);
        uint256 ethWeight = IndexMath.calculateWeight(6000, 76_000);
        assertEq(weights[0], btcWeight);
        assertEq(weights[1], ethWeight);
    }

    function test_getWeights_singleComponent() public {
        /**
         * Single component - weight must be exactly 1e18 (100%)
         */
        bytes32[] memory singleSymbol = new bytes32[](1);
        singleSymbol[0] = bytes32("BTC");

        uint256[] memory weights = marketCapWeighted.getWeights(singleSymbol);

        assertEq(weights.length, 1);
        assertEq(weights[0], 1e18);
    }

    function test_getWeights_equalMarketCaps() public {
        /**
         * 3 tokens, each with supply=1 and price=1_000e18 (18 decimals)
         * marketCap per token = 1 * 1_000e18 / 1e18 = 1_000
         * total = 3_000
         * expected weight each = 1_000/3_000 * 1e18
         */

        MockOracle oracle1 = new MockOracle("TOKEN1", 1000e18);
        MockOracle oracle2 = new MockOracle("TOKEN2", 1000e18);
        MockOracle oracle3 = new MockOracle("TOKEN3", 1000e18);

        IndexComponentRegistry.Component[] memory comps = new IndexComponentRegistry.Component[](3);
        comps[0] = IndexComponentRegistry.Component({
            symbol: bytes32("TOKEN1"), tokenAddress: makeAddr("T1"), priceFeedAddress: address(oracle1), heartbeat: 3600
        });
        comps[1] = IndexComponentRegistry.Component({
            symbol: bytes32("TOKEN2"), tokenAddress: makeAddr("T2"), priceFeedAddress: address(oracle2), heartbeat: 3600
        });
        comps[2] = IndexComponentRegistry.Component({
            symbol: bytes32("TOKEN3"), tokenAddress: makeAddr("T3"), priceFeedAddress: address(oracle3), heartbeat: 3600
        });

        vm.startPrank(owner);
        icr.registerComponents(comps);
        vm.stopPrank();

        bytes32[] memory syms = new bytes32[](3);
        syms[0] = bytes32("TOKEN1");
        syms[1] = bytes32("TOKEN2");
        syms[2] = bytes32("TOKEN3");

        uint256[] memory supplies = new uint256[](3);
        supplies[0] = 1;
        supplies[1] = 1;
        supplies[2] = 1;

        vm.startPrank(updater);
        cirSupply.updateBatch(syms, supplies);
        vm.stopPrank();

        uint256[] memory weights = marketCapWeighted.getWeights(syms);

        uint256 expectedWeight = IndexMath.calculateWeight(1000, 3000);
        assertEq(weights[0], expectedWeight);
        assertEq(weights[1], expectedWeight);
        assertEq(weights[2], expectedWeight);
    }

    function test_getWeights_sum_approx_1e18() public {
        uint256[] memory weights = marketCapWeighted.getWeights(symbol);

        uint256 sum = 0;
        for (uint256 i = 0; i < weights.length; i++) {
            sum += weights[i];
        }

        assertLe(sum, 1e18);
    }

    function test_getWeights_largeComponent() public {
        uint256 count = 10;

        bytes32[10] memory tokenNames = [bytes32("TKN1"), bytes32("TKN2"), bytes32("TKN3"), bytes32("TKN4"), bytes32("TKN5"), bytes32("TKN6"), bytes32("TKN7"), bytes32("TKN8"), bytes32("TKN9"), bytes32("TKN10")];

        bytes32[] memory syms = new bytes32[](count);
        IndexComponentRegistry.Component[] memory comps = new IndexComponentRegistry.Component[](count);
        uint256[] memory supplies = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            bytes32 sym = tokenNames[i];
            uint256 price = (i + 1) * 1000e18;
            MockOracle oracle = new MockOracle(string(abi.encodePacked(sym)), price);

            syms[i] = sym;
            comps[i] = IndexComponentRegistry.Component({
                symbol: sym, tokenAddress: makeAddr(string(abi.encodePacked(sym))), priceFeedAddress: address(oracle), heartbeat: 3600
            });
            supplies[i] = i + 1;
        }

        vm.prank(owner);
        icr.registerComponents(comps);

        vm.prank(updater);
        cirSupply.updateBatch(syms, supplies);

        uint256[] memory weights = marketCapWeighted.getWeights(syms);

        assertEq(weights.length, count);

        // weight sum invariant: floor rounding loses at most 1 unit per component
        uint256 sum = 0;
        for (uint256 i = 0; i < count; i++) {
            sum += weights[i];
        }
        assertLe(sum, 1e18);
        assertGe(sum, 1e18 - (count - 1));
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                     getWeights - Reverts
    // ═══════════════════════════════════════════════════════════════════════

    function test_getWeights_marketCapExceedsSanityBound() public {
        MockOracle oracle1 = new MockOracle("TOKEN1", 1e18);
        IndexComponentRegistry.Component[] memory comps = new IndexComponentRegistry.Component[](1);
        comps[0] = IndexComponentRegistry.Component({
            symbol: bytes32("TOKEN1"), tokenAddress: makeAddr("T1"), priceFeedAddress: address(oracle1), heartbeat: 3600
        });
        bytes32[] memory syms = new bytes32[](1);
        syms[0] = bytes32("TOKEN1");

        uint256[] memory supplies = new uint256[](1);
        supplies[0] = 1e31;

        vm.startPrank(owner);
        icr.registerComponents(comps);
        vm.stopPrank();

        vm.startPrank(updater);
        cirSupply.updateBatch(syms, supplies);
        vm.stopPrank();

        vm.expectRevert(MarketCapWeighted_MarketCapExceedsSanityBound.selector);
        marketCapWeighted.getWeights(syms);
    }

    function test_getWeights_componentWeightBelowMinimum() public {
        MockOracle oracleTiny = new MockOracle("TOKEN1", 1e18);
        MockOracle oracleBig = new MockOracle("TOKEN2", 1e18);

        IndexComponentRegistry.Component[] memory comps = new IndexComponentRegistry.Component[](2);
        comps[0] = IndexComponentRegistry.Component({
            symbol: bytes32("TOKEN1"), tokenAddress: makeAddr("T1"), priceFeedAddress: address(oracleTiny), heartbeat: 3600
        });
        comps[1] = IndexComponentRegistry.Component({
            symbol: bytes32("TOKEN2"), tokenAddress: makeAddr("T2"), priceFeedAddress: address(oracleBig), heartbeat: 3600
        });

        vm.startPrank(owner);
        icr.registerComponents(comps);
        vm.stopPrank();

        bytes32[] memory syms = new bytes32[](2);
        syms[0] = bytes32("TOKEN1");
        syms[1] = bytes32("TOKEN2");

        uint256[] memory supplies = new uint256[](2);
        supplies[0] = 1; //  tiny market cap
        supplies[1] = 1e18; //  dominates total

        vm.startPrank(updater);
        cirSupply.updateBatch(syms, supplies);
        vm.stopPrank();

        vm.expectRevert(MarketCapWeighted_ComponentWeightBelowMinimum.selector);
        marketCapWeighted.getWeights(syms);
    }

    function test_getWeights_emptyArray() public {
        bytes32[] memory emptySymbols = new bytes32[](0);

        vm.expectRevert(MarketCapWeighted_InvalidTotalMarketCap.selector);
        marketCapWeighted.getWeights(emptySymbols);
    }

    function test_getWeights_marketCapOverflow() public {
        // This test is skipped because MarketCapWeighted_MarketCapOverflow is unreachable in practice.
        //
        // Here is why:
        //   - getWeights() adds up each component's market cap one by one.
        //   - If the running total ever overflows uint256, it reverts with MarketCapOverflow.
        //   - BUT before any market cap value is returned, _getComponentMarketCap() checks:
        //       if (componentMarketCap > MAX_COMPONENT_MARKET_CAP) revert MarketCapExceedsSanityBound
        //   - MAX_COMPONENT_MARKET_CAP is 1e30.
        //   - uint256 max is roughly 1.15e77.
        //   - To overflow the sum, you would need (1.15e77 / 1e30) = ~10^47 components.
        //   - That is physically impossible to register or iterate over.
        //
        // So the sanity bound check always fires before the overflow check ever can.
        // MarketCapOverflow is dead code under the current design.
        // To make it reachable, MAX_COMPONENT_MARKET_CAP would need to be made overridable
        // (e.g. via a virtual internal getter) so a test harness can disable it.
        vm.skip(true);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                     View Functions
    // ═══════════════════════════════════════════════════════════════════════

    function test_getIndexComponentRegistry() public view {
        assertEq(marketCapWeighted.getIndexComponentRegistry(), address(icr));
    }

    function test_getCirculatingSupply() public view {
        assertEq(marketCapWeighted.getCirculatingSupply(), address(cirSupply));
    }
}

