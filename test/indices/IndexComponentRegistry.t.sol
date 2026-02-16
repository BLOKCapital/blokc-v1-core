// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Test } from "forge-std/Test.sol";

import { MockOracle } from "../mock/MockPriceFeed.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IndicesTestSetUp } from "test/indices/IndicesTestSetUp.sol";
import {
    IndexComponentRegistry,
    IndexComponentRegistry_InvalidComponentAddress,
    IndexComponentRegistry_InvalidPriceFeedAddress,
    IndexComponentRegistry_ComponentAlreadyRegistered,
    IndexComponentRegistry_ComponentNotRegistered,
    IndexComponentRegistry_TotalComponentsAndPriceFeedsMismatch,
    IndexComponentRegistry_TotalComponentsAndSymbolsMismatch,
    IndexComponentRegistry__FeedFrozenError,
    IndexComponentRegistry__InvalidFeedResponseError,
    IndexComponentRegistry__UnknownFeedError
} from "../../src/indices/IndexComponentRegistry.sol";

contract IndexComponentRegistryTest is IndicesTestSetUp {
    // ═══════════════════════════════════════════════════════════════════════
    //                       Register Component
    // ═══════════════════════════════════════════════════════════════════════

    function test_registerComponent() public {
        vm.startPrank(owner);
        icr.registerComponents(components);
        vm.stopPrank();

        // check whether the component is registered or not
        bool isBtcregistered = icr.isComponentRegistered("BTC");
        bool isEthPriceFeedRegistered = icr.isComponentRegistered("ETH");

        assertEq(isBtcregistered, true);
        assertEq(isEthPriceFeedRegistered, true);

        // check for change in oracle record
        IndexComponentRegistry.OracleRecord memory btcRecord = icr.getOracleRecord("BTC");
        IndexComponentRegistry.OracleRecord memory ethRecord = icr.getOracleRecord("ETH");

        assertEq(btcRecord.price, btcPrice);
        assertEq(btcRecord.timestamp, block.timestamp);
        assertEq(btcRecord.lastUpdated, block.timestamp);
        assertEq(btcRecord.roundId, 12_345);
        assertEq(btcRecord.decimals, 18);
        assertEq(btcRecord.isFeedWorking, true);

        assertEq(ethRecord.price, ethPrice);
        assertEq(ethRecord.timestamp, block.timestamp);
        assertEq(ethRecord.lastUpdated, block.timestamp);
        assertEq(ethRecord.roundId, 12_345);
        assertEq(ethRecord.decimals, 18);
        assertEq(ethRecord.isFeedWorking, true);

        // check for token address
        address btc = icr.getComponentAddress("BTC");
        address eth = icr.getComponentAddress("ETH");
        assertEq(btc, btcAddress);
        assertEq(eth, ethAddress);

        // check the pricefeed address
        address btcOracleAddress = icr.getComponentSymbolToPriceFeedAddress("BTC");
        address ethOracleAddress = icr.getComponentSymbolToPriceFeedAddress("ETH");

        assertEq(address(btcPriceFeed), btcOracleAddress);
        assertEq(address(ethPriceFeed), ethOracleAddress);

        //fetch price

        uint256 storedPriceBtc = icr.fetchPrice(btcAddress, "BTC");
        uint256 storedPriceEth = icr.fetchPrice(ethAddress, "ETH");

        assertEq(storedPriceBtc, btcPrice);
        assertEq(storedPriceEth, ethPrice);
    }

    function test_registerComponent_Revert_OnlyOwner() public {
        vm.expectRevert();
        icr.registerComponents(components);
    }

    function test_registerComponent_revert_invalidComponentAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(IndexComponentRegistry_InvalidComponentAddress.selector);
        components.push(
            IndexComponentRegistry.Component({
                symbol: "LINK", tokenAddress: address(0), priceFeedAddress: address(btcPriceFeed), heartbeat: 3600
            })
        );
        icr.registerComponents(components);
        vm.stopPrank();
    }

    function test_registerComponent_revert_invalide_price_feed() public {
        vm.startPrank(owner);
        vm.expectRevert(IndexComponentRegistry_InvalidPriceFeedAddress.selector);
        components.push(
            IndexComponentRegistry.Component({
                symbol: "LINK", tokenAddress: makeAddr("newToken"), priceFeedAddress: address(0), heartbeat: 3600
            })
        );
        icr.registerComponents(components);
    }

    function test_registerComponent_revert_already_resgistered() public {
        vm.startPrank(owner);
        vm.expectRevert(IndexComponentRegistry_ComponentAlreadyRegistered.selector);
        components.push(
            IndexComponentRegistry.Component({
                symbol: "ETH", tokenAddress: ethAddress, priceFeedAddress: address(ethPriceFeed), heartbeat: 3600
            })
        );
        icr.registerComponents(components);
    }

    function test_registerComponent_revert_stale_price() public {
        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IndexComponentRegistry__FeedFrozenError.selector, btcAddress));
        icr.registerComponents(components);
        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                  Invalid Feed Response (_isFeedWorking)
    // ═══════════════════════════════════════════════════════════════════════

    function test_registerComponent_revert_invalidFeed_zeroAnswer() public {
        btcPriceFeed.setResponse(12_345, 0, block.timestamp, block.timestamp, 12_345);

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IndexComponentRegistry__InvalidFeedResponseError.selector, btcAddress));
        icr.registerComponents(components);
        vm.stopPrank();
    }

    function test_registerComponent_revert_invalidFeed_zeroRoundId() public {
        btcPriceFeed.setResponse(0, int256(btcPrice), block.timestamp, block.timestamp, 0);

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IndexComponentRegistry__InvalidFeedResponseError.selector, btcAddress));
        icr.registerComponents(components);
        vm.stopPrank();
    }

    function test_registerComponent_revert_invalidFeed_zeroTimestamp() public {
        btcPriceFeed.setResponse(12_345, int256(btcPrice), 0, 0, 12_345);

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IndexComponentRegistry__InvalidFeedResponseError.selector, btcAddress));
        icr.registerComponents(components);
        vm.stopPrank();
    }

    function test_registerComponent_revert_invalidFeed_futureTimestamp() public {
        btcPriceFeed.setResponse(12_345, int256(btcPrice), block.timestamp + 1 hours, block.timestamp + 1 hours, 12_345);

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IndexComponentRegistry__InvalidFeedResponseError.selector, btcAddress));
        icr.registerComponents(components);
        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                       Fetch Price
    // ═══════════════════════════════════════════════════════════════════════

    modifier setComponentPriceFeed() {
        vm.startPrank(owner);
        icr.registerComponents(components);
        vm.stopPrank();
        _;
    }

    function test_fetchPrice() public setComponentPriceFeed {
        uint256 storedPriceBtc = icr.fetchPrice(btcAddress, "BTC");
        uint256 storedPriceEth = icr.fetchPrice(ethAddress, "ETH");

        assertEq(storedPriceBtc, btcPrice);
        assertEq(storedPriceEth, ethPrice);
    }

    function test_fetchPrice_revert_unknown_feed_error() public {
        vm.expectRevert(abi.encodeWithSelector(IndexComponentRegistry__UnknownFeedError.selector, btcAddress));
        icr.fetchPrice(btcAddress, "BTC");
    }

    function test_fetchPrice_notUpdated_returnsCachedPrice() public setComponentPriceFeed {
        vm.warp(block.timestamp + 1800); // 30 minutes < 1 hour heartbeat

        uint256 price = icr.fetchPrice(btcAddress, "BTC");
        assertEq(price, btcPrice);
    }

    function test_fetchPrice_notUpdated_revert_stalePrice() public setComponentPriceFeed {
        vm.warp(block.timestamp + 3601);

        vm.expectRevert(abi.encodeWithSelector(IndexComponentRegistry__FeedFrozenError.selector, btcAddress));
        icr.fetchPrice(btcAddress, "BTC");
    }

    function test_fetchPrice_after_refreshing_with_newPrice() public setComponentPriceFeed {
        vm.warp(block.timestamp + 3601);

        // prices within 50% max deviation threshold
        int256 newPriceBtc = 80_000e18;
        int256 newPriceEth = 2900e18;

        btcPriceFeed.refresh(newPriceBtc);
        ethPriceFeed.refresh(newPriceEth);

        uint256 storedPriceBtc = icr.fetchPrice(btcAddress, "BTC");
        uint256 storedPriceEth = icr.fetchPrice(ethAddress, "ETH");

        assertEq(storedPriceBtc, uint256(newPriceBtc));
        assertEq(storedPriceEth, uint256(newPriceEth));
    }

    function test_fetchPrice_revert_price_cange_above_maxDeviation_stale() public setComponentPriceFeed {
        vm.warp(block.timestamp + 36_001);

        // BTC: 70_000e18 -> 20_000e18 is ~71% drop, wel abve 50% max deviation
        int256 newPriceBtc = 20_000e18;

        btcPriceFeed.refresh(newPriceBtc);

        vm.expectRevert(abi.encodeWithSelector(IndexComponentRegistry__FeedFrozenError.selector, btcAddress));
        icr.fetchPrice(btcAddress, "BTC");
    }

    function test_fetchPrice_get_cached_price_change_above_maxDeviation() public setComponentPriceFeed {
        vm.warp(block.timestamp + 1800);

        // BTC: 70_000e18 -> 20_000e18 is ~71% drop, wel abve 50% max deviation
        int256 newPriceBtc = 20_000e18;

        btcPriceFeed.refresh(newPriceBtc);

        // return with the previous price
        uint256 storedPrice = icr.fetchPrice(btcAddress, "BTC");
        assertEq(storedPrice, btcPrice);
    }

    function test_fetchPrice_feedWorkingStatusToggle() public setComponentPriceFeed {
        IndexComponentRegistry.OracleRecord memory record = icr.getOracleRecord("BTC");
        assertEq(record.isFeedWorking, true);

        vm.warp(block.timestamp + 1800);
        int256 badPrice = 20_000e18;
        btcPriceFeed.refresh(badPrice);

        uint256 cachedPrice = icr.fetchPrice(btcAddress, "BTC");
        assertEq(cachedPrice, btcPrice);

        record = icr.getOracleRecord("BTC");
        assertEq(record.isFeedWorking, false);

        vm.warp(block.timestamp + 1800);
        int256 recoveredPrice = 22_000e18;
        btcPriceFeed.refresh(recoveredPrice);

        uint256 newPrice = icr.fetchPrice(btcAddress, "BTC");
        assertEq(newPrice, uint256(recoveredPrice));

        record = icr.getOracleRecord("BTC");
        assertEq(record.isFeedWorking, true);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                       Unregister Component
    // ═══════════════════════════════════════════════════════════════════════

    function test_unregisterComponent() public setComponentPriceFeed {
        vm.startPrank(owner);
        icr.unregisterComponents(symbol);
        vm.stopPrank();

        assertEq(icr.isComponentRegistered("BTC"), false);
        assertEq(icr.isComponentRegistered("ETH"), false);

        vm.expectRevert(IndexComponentRegistry_ComponentNotRegistered.selector);
        icr.getComponentAddress("BTC");

        vm.expectRevert(IndexComponentRegistry_ComponentNotRegistered.selector);
        icr.getComponentAddress("ETH");

        vm.expectRevert(IndexComponentRegistry_ComponentNotRegistered.selector);
        icr.getComponentSymbolToPriceFeedAddress("BTC");

        vm.expectRevert(IndexComponentRegistry_ComponentNotRegistered.selector);
        icr.getComponentSymbolToPriceFeedAddress("ETH");

        IndexComponentRegistry.OracleRecord memory btcRecord = icr.getOracleRecord("BTC");
        assertEq(btcRecord.price, 0);
        assertEq(btcRecord.timestamp, 0);
        assertEq(btcRecord.lastUpdated, 0);
        assertEq(btcRecord.roundId, 0);
        assertEq(btcRecord.decimals, 0);
        assertEq(btcRecord.isFeedWorking, false);
    }

    function test_unregisterComponent_revert_onlyOwner() public setComponentPriceFeed {
        vm.expectRevert();
        icr.unregisterComponents(symbol);
    }

    function test_unregisterComponent_revert_component_not_registered() public {
        string[] memory unknownSymbol = new string[](1);
        unknownSymbol[0] = "LINK";

        vm.startPrank(owner);
        vm.expectRevert(IndexComponentRegistry_ComponentNotRegistered.selector);
        icr.unregisterComponents(unknownSymbol);
        vm.stopPrank();
    }
}
