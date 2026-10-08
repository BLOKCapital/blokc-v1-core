// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Test, Vm } from "forge-std/Test.sol";

import { MockOracle } from "../../mock/MockPriceFeed.sol";
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
    IndexComponentRegistry__InvalidDeviationBps,
    IndexComponentRegistry__InvalidDeviationTimeout,
    IndexComponentRegistry__PriceDeviationTooHigh
} from "../../../src/indices/IndexComponentRegistry.sol";

/// @dev Mock feed that can be toggled to revert on every AggregatorV3 call (feed outage)
contract SwitchableOracle is AggregatorV3Interface {
    bool public reverting;
    uint80 public roundId = 12_345;
    int256 public answer;
    uint256 public updatedAt;
    string i_symbol;

    constructor(string memory _symbol, uint256 _answer) {
        answer = int256(_answer);
        updatedAt = block.timestamp;
        i_symbol = _symbol;
    }

    function setReverting(bool _reverting) external {
        reverting = _reverting;
    }

    function refresh(int256 _answer) external {
        answer = _answer;
        ++roundId;
        updatedAt = block.timestamp;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function description() external view returns (string memory) {
        return i_symbol;
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        if (reverting) revert("feed down");
        return (roundId, answer, updatedAt, updatedAt, roundId);
    }

    function getRoundData(uint80 _roundId) external view returns (uint80, int256, uint256, uint256, uint80) {
        if (reverting) revert("feed down");
        return (_roundId, answer, updatedAt, updatedAt, _roundId);
    }
}

contract IndexComponentRegistryTest is IndicesTestSetUp {
    function setUp() public override {
        super.setUp();
        // Reset icr to a clean state — super.setUp() pre-registers BTC/ETH for
        // MarketCapWeightedTest, but these tests manage registration themselves.
        icr = new IndexComponentRegistry(owner);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                       Register Component
    // ═══════════════════════════════════════════════════════════════════════

    function test_registerComponent() public {
        vm.startPrank(owner);
        icr.registerComponents(components);
        vm.stopPrank();

        // check whether the component is registered or not
        bool isBtcregistered = icr.isComponentRegistered(bytes32("BTC"));
        bool isEthPriceFeedRegistered = icr.isComponentRegistered(bytes32("ETH"));

        assertEq(isBtcregistered, true);
        assertEq(isEthPriceFeedRegistered, true);

        // check for change in oracle record
        IndexComponentRegistry.OracleRecord memory btcRecord = icr.getOracleRecord(bytes32("BTC"));
        IndexComponentRegistry.OracleRecord memory ethRecord = icr.getOracleRecord(bytes32("ETH"));

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
        address btc = icr.getComponentAddress(bytes32("BTC"));
        address eth = icr.getComponentAddress(bytes32("ETH"));
        assertEq(btc, btcAddress);
        assertEq(eth, ethAddress);

        // check the pricefeed address
        address btcOracleAddress = icr.getComponentSymbolToPriceFeedAddress(bytes32("BTC"));
        address ethOracleAddress = icr.getComponentSymbolToPriceFeedAddress(bytes32("ETH"));

        assertEq(address(btcPriceFeed), btcOracleAddress);
        assertEq(address(ethPriceFeed), ethOracleAddress);

        //fetch price

        uint256 storedPriceBtc = icr.fetchPrice(bytes32("BTC"));
        uint256 storedPriceEth = icr.fetchPrice(bytes32("ETH"));

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
                symbol: bytes32("LINK"),
                tokenAddress: address(0),
                priceFeedAddress: address(btcPriceFeed),
                heartbeat: 3600
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
                symbol: bytes32("LINK"),
                tokenAddress: makeAddr("newToken"),
                priceFeedAddress: address(0),
                heartbeat: 3600
            })
        );
        icr.registerComponents(components);
    }

    function test_registerComponent_revert_already_resgistered() public {
        vm.startPrank(owner);
        vm.expectRevert(IndexComponentRegistry_ComponentAlreadyRegistered.selector);
        components.push(
            IndexComponentRegistry.Component({
                symbol: bytes32("ETH"),
                tokenAddress: ethAddress,
                priceFeedAddress: address(ethPriceFeed),
                heartbeat: 3600
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
        uint256 storedPriceBtc = icr.fetchPrice(bytes32("BTC"));
        uint256 storedPriceEth = icr.fetchPrice(bytes32("ETH"));

        assertEq(storedPriceBtc, btcPrice);
        assertEq(storedPriceEth, ethPrice);
    }

    function test_fetchPrice_revert_component_not_registered() public {
        vm.expectRevert(IndexComponentRegistry_ComponentNotRegistered.selector);
        icr.fetchPrice(bytes32("BTC"));
    }

    function test_fetchPrice_notUpdated_returnsCachedPrice() public setComponentPriceFeed {
        vm.warp(block.timestamp + 1800); // 30 minutes < 1 hour heartbeat

        uint256 price = icr.fetchPrice(bytes32("BTC"));
        assertEq(price, btcPrice);
    }

    function test_fetchPrice_stale_noNewRound_servesCached() public setComponentPriceFeed {
        uint256 registeredAt = block.timestamp;
        vm.warp(registeredAt + 3601); // past the 1-hour heartbeat, no new round published

        vm.recordLogs();
        uint256 price = icr.fetchPrice(bytes32("BTC"));
        assertEq(price, btcPrice); // cached price served, no revert

        // FeedStale(token, lastPriceTimestamp, age, servedPrice) emitted with the cached price
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool found;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter == address(icr) && logs[i].topics[0] == IndexComponentRegistry.FeedStale.selector) {
                found = true;
                assertEq(logs[i].emitter, address(icr));
                break;
            }
        }
        assertTrue(found, "FeedStale event not emitted");
    }

    function test_fetchPrice_after_refreshing_with_newPrice() public setComponentPriceFeed {
        vm.warp(block.timestamp + 3601);

        // prices within 10% of EMA (EMA initialized to registration price: BTC=70_000, ETH=3000)
        int256 newPriceBtc = 77_000e18; // ~9% increase from EMA — within 10%
        int256 newPriceEth = 2900e18; // ~3.3% decrease from EMA — within 10%

        btcPriceFeed.refresh(newPriceBtc);
        ethPriceFeed.refresh(newPriceEth);

        uint256 storedPriceBtc = icr.fetchPrice(bytes32("BTC"));
        uint256 storedPriceEth = icr.fetchPrice(bytes32("ETH"));

        assertEq(storedPriceBtc, uint256(newPriceBtc));
        assertEq(storedPriceEth, uint256(newPriceEth));
    }

    function test_fetchPrice_deviation_pastTimeout_autoAccepted() public setComponentPriceFeed {
        uint256 registeredAt = block.timestamp;
        vm.warp(registeredAt + 36_001);

        // BTC: 70_000e18 -> 20_000e18 is a ~71% EMA-relative drop — far outside the 10% band,
        // but below the 2x broken-feed cap. The FIRST deviating read only records the deviation
        // (persistence clock starts); the cached price is served. After the 1h timeout has
        // elapsed since that first rejection, the next read auto-accepts the market price.
        int256 newPriceBtc = 20_000e18;
        btcPriceFeed.refresh(newPriceBtc);

        uint256 firstDeviationAt = block.timestamp;
        uint256 rejected = icr.fetchPrice(bytes32("BTC"));
        assertEq(rejected, btcPrice);
        assertEq(icr.getOracleRecord(bytes32("BTC")).firstDeviationAt, firstDeviationAt);

        vm.warp(firstDeviationAt + 3600);
        vm.expectEmit(true, false, false, true, address(icr));
        emit IndexComponentRegistry.DeviationTimeoutAccepted(btcAddress, 20_000e18, btcPrice);

        uint256 price = icr.fetchPrice(bytes32("BTC"));
        assertEq(price, uint256(newPriceBtc)); // market price accepted, not cached

        IndexComponentRegistry.OracleRecord memory record = icr.getOracleRecord(bytes32("BTC"));
        assertEq(record.price, uint256(newPriceBtc));
        assertEq(record.emaPrice, uint256(newPriceBtc)); // EMA re-seeded to market
        assertEq(record.firstDeviationAt, 0);
        assertEq(record.consecutiveRejections, 0);
        assertEq(record.isFeedWorking, true);
    }

    function test_fetchPrice_get_cached_price_change_above_maxDeviation() public setComponentPriceFeed {
        uint256 deviationAt = block.timestamp + 1800;
        vm.warp(deviationAt);

        // BTC: 70_000e18 -> 20_000e18 is ~71% drop, well above the 10% band
        int256 newPriceBtc = 20_000e18;
        btcPriceFeed.refresh(newPriceBtc);

        // deviation floor: (70_000 − 20_000) × 1e4 / 70_000, rounded down
        vm.expectEmit(true, false, false, true, address(icr));
        emit IndexComponentRegistry.PriceDeviationRejected(btcAddress, 20_000e18, btcPrice, 7142, 1000);

        // return with the previous price
        uint256 storedPrice = icr.fetchPrice(bytes32("BTC"));
        assertEq(storedPrice, btcPrice);

        IndexComponentRegistry.OracleRecord memory record = icr.getOracleRecord(bytes32("BTC"));
        assertEq(record.firstDeviationAt, deviationAt);
        assertEq(record.consecutiveRejections, 1);
        assertEq(record.isFeedWorking, false);
    }

    function test_fetchPrice_feedWorkingStatusToggle() public setComponentPriceFeed {
        IndexComponentRegistry.OracleRecord memory record = icr.getOracleRecord(bytes32("BTC"));
        assertEq(record.isFeedWorking, true);

        // Bad price: ~21% below EMA of 70_000 — clearly outside 10% threshold
        vm.warp(block.timestamp + 1800);
        int256 badPrice = 55_000e18;
        btcPriceFeed.refresh(badPrice);

        uint256 cachedPrice = icr.fetchPrice(bytes32("BTC"));
        assertEq(cachedPrice, btcPrice);

        record = icr.getOracleRecord(bytes32("BTC"));
        assertEq(record.isFeedWorking, false);

        // Recovered price: ~5.7% below EMA of 70_000 — within 10% threshold
        // Keep total warp under 3600 to avoid hitting the stale-price boundary
        vm.warp(block.timestamp + 1000);
        int256 recoveredPrice = 66_000e18;
        btcPriceFeed.refresh(recoveredPrice);

        uint256 newPrice = icr.fetchPrice(bytes32("BTC"));
        assertEq(newPrice, uint256(recoveredPrice));

        record = icr.getOracleRecord(bytes32("BTC"));
        assertEq(record.isFeedWorking, true);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                Time-Decay Guard (bands, timeout, resync)
    // ═══════════════════════════════════════════════════════════════════════

    function test_autoAccept_boundary_exactTimeout_accepts() public setComponentPriceFeed {
        vm.warp(block.timestamp + 3599);
        btcPriceFeed.refresh(20_000e18);

        // First deviating read: records the deviation, serves the cached price
        uint256 rejected = icr.fetchPrice(bytes32("BTC"));
        assertEq(rejected, btcPrice);
        uint256 firstDeviationAt = block.timestamp;

        // Exactly firstDeviationAt + DEFAULT_DEVIATION_TIMEOUT (>= comparison): accepted
        vm.warp(firstDeviationAt + 3600);
        uint256 accepted = icr.fetchPrice(bytes32("BTC"));
        assertEq(accepted, 20_000e18);
    }

    function test_autoAccept_cap_twoX_neverAutoAccepted() public setComponentPriceFeed {
        // A 2x move = exactly 10_000 bps EMA-relative — the broken-feed tier. It is rejected
        // forever (strict < cap) and only forceResync can adopt it.
        vm.warp(block.timestamp + 1800);
        btcPriceFeed.refresh(140_000e18);

        uint256 rejected = icr.fetchPrice(bytes32("BTC"));
        assertEq(rejected, btcPrice);

        vm.warp(block.timestamp + 2 days); // far past the deviation timeout
        rejected = icr.fetchPrice(bytes32("BTC"));
        assertEq(rejected, btcPrice); // still cached — never auto-accepted
        assertEq(icr.getOracleRecord(bytes32("BTC")).consecutiveRejections, 2);
    }

    function test_autoAccept_cap_justUnderTwoX_acceptedAfterPersistence() public setComponentPriceFeed {
        vm.warp(block.timestamp + 1800);
        btcPriceFeed.refresh(139_000e18); // 1.986x = 9_857 bps EMA-relative — under the cap

        uint256 firstDeviationAt = block.timestamp;
        assertEq(icr.fetchPrice(bytes32("BTC")), btcPrice); // rejected on first sight

        vm.warp(firstDeviationAt + 3600);
        assertEq(icr.fetchPrice(bytes32("BTC")), 139_000e18); // auto-accepted after persistence
    }

    function test_bandBoundary_exactBand_accepted() public setComponentPriceFeed {
        vm.warp(block.timestamp + 1800);

        // Drop of exactly 10%: deviation = 7_000 × 1e4 / 70_000 = 1000 bps == band (strict >)
        btcPriceFeed.refresh(63_000e18);
        assertEq(icr.fetchPrice(bytes32("BTC")), 63_000e18);
    }

    function test_bandBoundary_bandPlusOne_rejected() public setComponentPriceFeed {
        vm.warp(block.timestamp + 1800);

        // Drop of 10.01%: deviation = 7_007 × 1e4 / 70_000 = 1001 bps > band
        btcPriceFeed.refresh(62_993e18);
        assertEq(icr.fetchPrice(bytes32("BTC")), btcPrice);
    }

    function test_consecutiveRejections_accumulateAndReset() public setComponentPriceFeed {
        vm.warp(block.timestamp + 1800);
        btcPriceFeed.refresh(55_000e18); // −21.4%
        icr.fetchPrice(bytes32("BTC"));

        vm.warp(block.timestamp + 1000); // 2800 < heartbeat, still fresh-window rejections
        btcPriceFeed.refresh(50_000e18); // −28.6% vs original EMA
        icr.fetchPrice(bytes32("BTC"));

        IndexComponentRegistry.OracleRecord memory record = icr.getOracleRecord(bytes32("BTC"));
        assertEq(record.consecutiveRejections, 2);

        // An accepted round resets the streak
        vm.warp(block.timestamp + 100); // 2900 total, still inside the 3600 heartbeat
        btcPriceFeed.refresh(66_000e18); // −5.7% vs original EMA
        icr.fetchPrice(bytes32("BTC"));

        record = icr.getOracleRecord(bytes32("BTC"));
        assertEq(record.consecutiveRejections, 0);
        assertEq(record.firstDeviationAt, 0);
    }

    function test_setMaxDeviationBps() public setComponentPriceFeed {
        assertEq(icr.getMaxDeviationBps(bytes32("BTC")), 1000); // default

        vm.startPrank(owner);
        icr.setMaxDeviationBps(bytes32("BTC"), 2500);
        vm.stopPrank();
        assertEq(icr.getMaxDeviationBps(bytes32("BTC")), 2500);

        // A 16.7% move now passes the 25% band
        vm.warp(block.timestamp + 1800);
        btcPriceFeed.refresh(84_000e18);
        assertEq(icr.fetchPrice(bytes32("BTC")), 84_000e18);
    }

    function test_setMaxDeviationBps_revert_nonOwner() public setComponentPriceFeed {
        vm.expectRevert();
        icr.setMaxDeviationBps(bytes32("BTC"), 2500);
    }

    function test_setMaxDeviationBps_revert_outOfBounds() public setComponentPriceFeed {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IndexComponentRegistry__InvalidDeviationBps.selector, 99));
        icr.setMaxDeviationBps(bytes32("BTC"), 99);

        vm.expectRevert(abi.encodeWithSelector(IndexComponentRegistry__InvalidDeviationBps.selector, 50_001));
        icr.setMaxDeviationBps(bytes32("BTC"), 50_001);
        vm.stopPrank();
    }

    function test_setMaxDeviationBps_revert_unregistered() public {
        vm.startPrank(owner);
        vm.expectRevert(IndexComponentRegistry_ComponentNotRegistered.selector);
        icr.setMaxDeviationBps(bytes32("LINK"), 2500);
        vm.stopPrank();
    }

    function test_setDeviationTimeout() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IndexComponentRegistry__InvalidDeviationTimeout.selector, 1799));
        icr.setDeviationTimeout(1799);

        vm.expectRevert(abi.encodeWithSelector(IndexComponentRegistry__InvalidDeviationTimeout.selector, 86_401));
        icr.setDeviationTimeout(86_401);

        icr.setDeviationTimeout(2 hours);
        vm.stopPrank();
        assertEq(icr.getDeviationTimeout(), 2 hours);

        vm.expectRevert();
        icr.setDeviationTimeout(2 hours);
    }

    function test_forceResync() public setComponentPriceFeed {
        // Create an unresolved deviation rejection
        vm.warp(block.timestamp + 1800);
        btcPriceFeed.refresh(20_000e18);
        icr.fetchPrice(bytes32("BTC"));
        assertEq(icr.getOracleRecord(bytes32("BTC")).firstDeviationAt != 0, true);

        // Publish a new round, then resync to it without waiting for the timeout
        vm.warp(block.timestamp + 100);
        btcPriceFeed.refresh(66_000e18);

        vm.startPrank(owner);
        icr.forceResync(bytes32("BTC"));
        vm.stopPrank();

        IndexComponentRegistry.OracleRecord memory record = icr.getOracleRecord(bytes32("BTC"));
        assertEq(record.price, 66_000e18);
        assertEq(record.emaPrice, 66_000e18);
        assertEq(record.firstDeviationAt, 0);
        assertEq(record.consecutiveRejections, 0);
        assertEq(record.isFeedWorking, true);
        assertEq(icr.fetchPrice(bytes32("BTC")), 66_000e18);
    }

    function test_forceResync_revert_nonOwner() public setComponentPriceFeed {
        vm.expectRevert();
        icr.forceResync(bytes32("BTC"));
    }

    function test_forceResync_revert_noNewRound() public setComponentPriceFeed {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IndexComponentRegistry__InvalidFeedResponseError.selector, btcAddress));
        icr.forceResync(bytes32("BTC"));
        vm.stopPrank();
    }

    function test_fetchPriceStrict_reverts_whileDeviationUnresolved() public setComponentPriceFeed {
        vm.warp(block.timestamp + 1800);
        btcPriceFeed.refresh(20_000e18);
        icr.fetchPrice(bytes32("BTC"));

        vm.expectRevert(
            abi.encodeWithSelector(
                IndexComponentRegistry__PriceDeviationTooHigh.selector, btcAddress, btcPrice, btcPrice
            )
        );
        icr.fetchPriceStrict(bytes32("BTC"));
    }

    function test_feedFailureCounter_deletedUnderFeedKeyOnUnregister() public {
        SwitchableOracle linkFeed = new SwitchableOracle("LINK", 10_000e18);
        IndexComponentRegistry.Component[] memory comps = new IndexComponentRegistry.Component[](1);
        comps[0] = IndexComponentRegistry.Component({
            symbol: bytes32("LINK"),
            tokenAddress: makeAddr("LINK"),
            priceFeedAddress: address(linkFeed),
            heartbeat: 3600
        });

        vm.startPrank(owner);
        icr.registerComponents(comps);
        vm.stopPrank();

        // Feed goes down: failure counter increments under the FEED address
        linkFeed.setReverting(true);
        vm.warp(block.timestamp + 1); // leave the same-block short-circuit so the feed is consulted
        icr.fetchPrice(bytes32("LINK"));
        assertEq(icr.getFeedFailures(address(linkFeed)), 1);

        // Unregister must now clear the counter (it used to delete under the token key)
        bytes32[] memory syms = new bytes32[](1);
        syms[0] = bytes32("LINK");
        vm.startPrank(owner);
        icr.unregisterComponents(syms);
        vm.stopPrank();

        assertEq(icr.getFeedFailures(address(linkFeed)), 0);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                       Unregister Component
    // ═══════════════════════════════════════════════════════════════════════

    function test_unregisterComponent() public setComponentPriceFeed {
        vm.startPrank(owner);
        icr.unregisterComponents(symbol);
        vm.stopPrank();

        assertEq(icr.isComponentRegistered(bytes32("BTC")), false);
        assertEq(icr.isComponentRegistered(bytes32("ETH")), false);

        vm.expectRevert(IndexComponentRegistry_ComponentNotRegistered.selector);
        icr.getComponentAddress(bytes32("BTC"));

        vm.expectRevert(IndexComponentRegistry_ComponentNotRegistered.selector);
        icr.getComponentAddress(bytes32("ETH"));

        vm.expectRevert(IndexComponentRegistry_ComponentNotRegistered.selector);
        icr.getComponentSymbolToPriceFeedAddress(bytes32("BTC"));

        vm.expectRevert(IndexComponentRegistry_ComponentNotRegistered.selector);
        icr.getComponentSymbolToPriceFeedAddress(bytes32("ETH"));

        IndexComponentRegistry.OracleRecord memory btcRecord = icr.getOracleRecord(bytes32("BTC"));
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
        bytes32[] memory unknownSymbol = new bytes32[](1);
        unknownSymbol[0] = bytes32("LINK");

        vm.startPrank(owner);
        vm.expectRevert(IndexComponentRegistry_ComponentNotRegistered.selector);
        icr.unregisterComponents(unknownSymbol);
        vm.stopPrank();
    }
}
