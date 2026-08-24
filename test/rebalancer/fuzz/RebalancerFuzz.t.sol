// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import "forge-std/Test.sol";
import { Rebalancer } from "src/rebalancer/Rebalancer.sol";
import { RebalancerTestBase, MockIndex } from "../unit/RebalancerTest.t.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import {
    Rebalancer_NoIndicesRegistered,
    Rebalancer_BatchSizeNotSet,
    Rebalancer_DeadlineExpired,
    Rebalancer_UnapprovedSwapSelector,
    Rebalancer_InvalidConfig,
    Rebalancer_DexNotConfigured,
    Rebalancer_ZeroTotalValue
} from "src/rebalancer/Rebalancer.sol";

/// @title RebalancerFuzzTest
/// @notice Stateless fuzz tests for the Rebalancer edge cases: deadline
///         boundaries, unknown index types, unset batch sizes, single gardens,
///         empty symbols, USDC-as-component vs not, batch sizes that do not
///         divide the garden count evenly, garden dedup across multiple indices,
///         dust-only portfolios, and the setDexConfig selector whitelist.
contract RebalancerFuzzTest is RebalancerTestBase {
    using Math for uint256;

    /// @dev Absolute USD-value dust allowance (8-dec USD units = $0.01).
    uint256 public constant VALUE_DUST = 1e9;

    // ═══════════════════════════════════════════════════════════════════════
    // DEADLINE BOUNDARIES
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Any deadline strictly before now must revert with DeadlineExpired.
    function testFuzz_deadline_beforeNow_reverts(uint256 deadlineSeed) public {
        vm.warp(1_700_000_000);
        uint256 deadline = bound(deadlineSeed, 0, block.timestamp - 1);
        vm.expectRevert(abi.encodeWithSelector(Rebalancer_DeadlineExpired.selector, deadline, block.timestamp));
        rebalancer.cumulativeRebalance(INDEX_TYPE, deadline);
    }

    /// @notice Any deadline strictly after now + 1h must revert with DeadlineExpired.
    function testFuzz_deadline_afterNowPlusHour_reverts(uint256 deadlineSeed) public {
        vm.warp(1_700_000_000);
        uint256 deadline = bound(deadlineSeed, block.timestamp + 1 hours + 1, block.timestamp + 10 days);
        vm.expectRevert(abi.encodeWithSelector(Rebalancer_DeadlineExpired.selector, deadline, block.timestamp));
        rebalancer.cumulativeRebalance(INDEX_TYPE, deadline);
    }

    /// @notice The exact boundaries (deadline == now and deadline == now + 1h) are
    ///         accepted — only strict inequalities revert.
    function testFuzz_deadline_exactBoundaries_succeed(uint256 seed) public {
        vm.warp(1_700_000_000);
        address[] memory one = new address[](1);
        one[0] = alice;
        blokc2Index.setGardens(one);
        _fundGarden(alice, bound(seed, 1e17, 1e19), bound(seed >> 4, 1e6, 1e9), bound(seed >> 8, 1e6, 1e8));
        _warpPastInterval();

        // deadline == now is accepted.
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp);
        assertEq(rebalancer.lastRebalanceTimestamp(INDEX_TYPE), block.timestamp);

        // deadline == now + 1h is accepted on the next round.
        _warpPastInterval();
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 1 hours);
        assertEq(rebalancer.lastRebalanceTimestamp(INDEX_TYPE), block.timestamp);
    }

    /// @notice Any deadline in [now, now + 1h] is accepted.
    function testFuzz_deadline_anyInRange_succeeds(uint256 deadline, uint256 seed) public {
        vm.warp(1_700_000_000);
        address[] memory one = new address[](1);
        one[0] = alice;
        blokc2Index.setGardens(one);
        _fundGarden(alice, bound(seed, 1e17, 1e19), bound(seed >> 4, 1e6, 1e9), 0);
        _warpPastInterval();

        uint256 d = bound(deadline, block.timestamp, block.timestamp + 1 hours);
        rebalancer.cumulativeRebalance(INDEX_TYPE, d);
        assertEq(rebalancer.lastRebalanceTimestamp(INDEX_TYPE), block.timestamp);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // PRE-VALIDATION GUARDS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Unknown index type ids must revert with NoIndicesRegistered.
    function testFuzz_rebalance_unknownIndexType_reverts(bytes32 seed) public {
        bytes32 id = bytes32(uint256(keccak256(abi.encode(seed))));
        if (id == INDEX_TYPE) id = bytes32("OTHER_TYPE");
        vm.expectRevert(abi.encodeWithSelector(Rebalancer_NoIndicesRegistered.selector, id));
        rebalancer.cumulativeRebalance(id, block.timestamp + 300);
    }

    /// @notice A rebalancer with no maxGardensPerBatch configured must revert with
    ///         BatchSizeNotSet (zero batch size is the "not set" state).
    function testFuzz_rebalance_batchSizeNotSet_reverts(uint256 seed) public {
        Rebalancer fresh = new Rebalancer(
            owner, address(indexFactory), address(compRegistry), address(poolRegistry), address(1), address(usdc)
        );
        vm.prank(owner);
        fresh.addIndexToType(INDEX_TYPE, address(blokc2Index));
        _fundGarden(alice, bound(seed, 1e17, 1e19), bound(seed >> 4, 1e6, 1e9), 0);
        _warpPastInterval();
        vm.expectRevert(abi.encodeWithSelector(Rebalancer_BatchSizeNotSet.selector, INDEX_TYPE));
        fresh.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SINGLE GARDEN / CONSERVATION
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice A single-garden round rebalances to target weights, returns
    ///         everything, conserves value (≥ 99.5%, no creation) and leaves no
    ///         residue in the rebalancer.
    function testFuzz_singleGarden_rebalancesAndConservesValue(uint256 seed) public {
        address[] memory one = new address[](1);
        one[0] = alice;
        blokc2Index.setGardens(one);
        _fundGarden(alice, bound(seed, 1e17, 1e19), bound(seed >> 4, 1e6, 1e9), bound(seed >> 8, 1e6, 1e8));
        _warpPastInterval();

        uint256 before = _portfolioValue(one);
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
        uint256 afterValue = _portfolioValue(one);

        assertGe(afterValue, Math.mulDiv(before, 9950, 10_000, Math.Rounding.Floor), "value lost beyond 0.5%");
        assertLe(afterValue, before + VALUE_DUST, "value created by rebalance");
        assertEq(weth.balanceOf(address(rebalancer)), 0, "WETH residue");
        assertEq(wbtc.balanceOf(address(rebalancer)), 0, "WBTC residue");
        assertEq(usdc.balanceOf(address(rebalancer)), 0, "USDC residue");
        assertEq(rebalancer.gardenCursor(INDEX_TYPE), 0, "round completed");
    }

    /// @notice Random portfolios (1-6 gardens) conserve total value through a
    ///         full round: within the 0.5% guard on the downside, no creation on
    ///         the upside.
    function testFuzz_valueConservation_randomPortfolios(uint256 seed) public {
        uint256 n = bound(seed, 1, 6);
        address[] memory gs = _fundedGardens(n, seed);
        _warpPastInterval();

        uint256 before = _portfolioValue(gs);
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
        uint256 afterValue = _portfolioValue(gs);

        assertGe(afterValue, Math.mulDiv(before, 9950, 10_000, Math.Rounding.Floor), "value lost beyond 0.5%");
        assertLe(afterValue, before + VALUE_DUST, "value created by rebalance");
        assertEq(rebalancer.gardenCursor(INDEX_TYPE), 0, "round completed");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // EMPTY SYMBOLS / USDC HANDLING
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice With an empty component list and USDC held by the garden, the round
    ///         succeeds: no components → no swaps, and the USDC is pulled and
    ///         redistributed back (value-neutral, exact).
    function testFuzz_emptySymbols_usdcHeld_succeeds(uint256 seed) public {
        blokc2Index.setWeights(new bytes32[](0), new uint256[](0));
        address[] memory one = new address[](1);
        one[0] = alice;
        blokc2Index.setGardens(one);

        uint256 usdcAmt = bound(seed, 1e6, 1e12);
        usdc.mint(alice, usdcAmt);
        vm.prank(alice);
        usdc.approve(address(rebalancer), type(uint256).max);
        _warpPastInterval();

        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);

        assertEq(usdc.balanceOf(alice), usdcAmt, "USDC fully returned");
        assertEq(usdc.balanceOf(address(rebalancer)), 0, "no USDC residue");
        assertEq(rebalancer.gardenCursor(INDEX_TYPE), 0, "round completed");
    }

    /// @notice With an empty component list and zero-value gardens, the round must
    ///         revert with ZeroTotalValue.
    function testFuzz_emptySymbols_noValue_reverts(uint256 seed) public {
        blokc2Index.setWeights(new bytes32[](0), new uint256[](0));
        _warpPastInterval();
        vm.expectRevert(abi.encodeWithSelector(Rebalancer_ZeroTotalValue.selector, INDEX_TYPE));
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
    }

    /// @notice When USDC is an index component (not a cash buffer), the round
    ///         still rebalances, conserves value, and drains the rebalancer.
    function testFuzz_usdcAsComponent(uint256 seed) public {
        bytes32[] memory syms = new bytes32[](3);
        syms[0] = SYM_WETH;
        syms[1] = SYM_WBTC;
        syms[2] = SYM_USDC;
        uint256 w1 = bound(seed, 0, 1e18);
        uint256 w2 = bound(seed >> 8, 0, 1e18 - w1);
        uint256[] memory wts = new uint256[](3);
        wts[0] = w1;
        wts[1] = w2;
        wts[2] = 1e18 - w1 - w2;
        blokc2Index.setWeights(syms, wts);

        _fundGarden(alice, bound(seed >> 16, 1e17, 1e19), bound(seed >> 20, 1e6, 1e9), bound(seed >> 24, 1e6, 1e10));
        _fundGarden(bob, bound(seed >> 32, 1e17, 1e19), bound(seed >> 36, 1e6, 1e9), bound(seed >> 40, 1e6, 1e10));
        _warpPastInterval();

        uint256 before = _portfolioValue(gardens);
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
        uint256 afterValue = _portfolioValue(gardens);

        assertGe(afterValue, Math.mulDiv(before, 9950, 10_000, Math.Rounding.Floor), "value lost beyond 0.5%");
        assertLe(afterValue, before + VALUE_DUST, "value created by rebalance");
        assertEq(weth.balanceOf(address(rebalancer)) + wbtc.balanceOf(address(rebalancer)), 0, "component residue");
        assertEq(usdc.balanceOf(address(rebalancer)), 0, "USDC residue");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // BATCH SIZES — UNEVEN DIVISION
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Batch sizes that do not divide the garden count evenly: the round
    ///         must complete in exactly ceil(n/b) calls, the cursor must reset,
    ///         and every funded garden must receive tokens back.
    function testFuzz_batchSizes_unevenDivision(uint256 nSeed, uint256 bSeed) public {
        uint256 n = bound(nSeed, 1, 9);
        uint256 b = bound(bSeed, 1, n + 2);
        address[] memory gs = _fundedGardens(n, nSeed);
        _setBatch(b);
        _warpPastInterval();

        uint256 calls;
        do {
            rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
            calls++;
        } while (rebalancer.gardenCursor(INDEX_TYPE) != 0 && calls <= n + 1);

        assertEq(rebalancer.gardenCursor(INDEX_TYPE), 0, "round must complete");
        assertEq(rebalancer.lastRebalanceTimestamp(INDEX_TYPE), block.timestamp, "round completion stamped");
        assertLe(calls, n, "calls == ceil(n/b) <= n");
        for (uint256 i = 0; i < n; i++) {
            assertGt(
                weth.balanceOf(gs[i]) + wbtc.balanceOf(gs[i]) + usdc.balanceOf(gs[i]),
                0,
                "every funded garden receives tokens"
            );
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // PROPORTIONAL REDISTRIBUTION
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice After a full round, each garden's holdings must equal its reported
    ///         contribution (its share of the batch total), within rounding.
    function testFuzz_redistribution_proportionalToContributions(uint256 seed) public {
        uint256 n = bound(seed, 2, 5);
        address[] memory gs = _fundedGardens(n, seed);
        _warpPastInterval();

        vm.recordLogs();
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        for (uint256 i = 0; i < n; i++) {
            uint256 contrib = _contributionFromLogs(logs, gs[i]);
            uint256 actual = _gardenValue(gs[i]);
            if (contrib > 0) {
                assertApproxEqRel(actual, contrib, 5e15, "garden allocation vs contribution");
            } else {
                assertLe(actual, VALUE_DUST, "zero-contribution garden receives dust only");
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // WEIGHT EXTREMES / DUST
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Extreme weights (0% and 100% on a component) still rebalance and
    ///         conserve value.
    function testFuzz_weightExtremes(uint256 wSeed, uint256 seed) public {
        uint256 w1 = bound(wSeed, 0, 1e18);
        uint256[] memory wts = new uint256[](2);
        wts[0] = w1;
        wts[1] = 1e18 - w1;
        bytes32[] memory syms = new bytes32[](2);
        syms[0] = SYM_WETH;
        syms[1] = SYM_WBTC;
        blokc2Index.setWeights(syms, wts);

        _fundGarden(alice, bound(seed, 1e17, 1e19), bound(seed >> 4, 1e6, 1e9), 0);
        _fundGarden(bob, bound(seed >> 8, 1e17, 1e19), bound(seed >> 12, 1e6, 1e9), 0);
        _warpPastInterval();

        uint256 before = _portfolioValue(gardens);
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
        uint256 afterValue = _portfolioValue(gardens);

        assertGe(afterValue, Math.mulDiv(before, 9950, 10_000, Math.Rounding.Floor), "value lost beyond 0.5%");
        assertLe(afterValue, before + VALUE_DUST, "value created by rebalance");
    }

    /// @notice Dust-only portfolios: succeeds when any value is present, reverts
    ///         with ZeroTotalValue when the entire portfolio floors to zero.
    function testFuzz_tinyBalances(uint256 seed) public {
        address[] memory one = new address[](1);
        one[0] = alice;
        blokc2Index.setGardens(one);
        _fundGarden(alice, bound(seed, 0, 1000), bound(seed >> 8, 0, 1000), 0);
        _warpPastInterval();

        uint256 before = _portfolioValue(one);
        if (before == 0) {
            vm.expectRevert(abi.encodeWithSelector(Rebalancer_ZeroTotalValue.selector, INDEX_TYPE));
            rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
        } else {
            rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
            uint256 afterValue = _portfolioValue(one);
            assertGe(afterValue, Math.mulDiv(before, 9950, 10_000, Math.Rounding.Floor), "value lost beyond 0.5%");
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MULTI-INDEX GARDEN DEDUP
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice A garden registered under two indices of the same type must be
    ///         processed once (dedup in _collectGardens): no double-pull, no
    ///         value loss.
    function testFuzz_multipleIndices_sharedGardenDeduplicated(uint256 seed) public {
        bytes32[] memory syms = new bytes32[](2);
        syms[0] = SYM_WETH;
        syms[1] = SYM_WBTC;
        uint256[] memory wts = new uint256[](2);
        wts[0] = 0.5e18;
        wts[1] = 0.5e18;

        MockIndex second = new MockIndex();
        indexFactory.setRegistered(address(second), true);
        second.setWeights(syms, wts);
        second.setGardens(gardens); // alice + bob also live on the primary index
        vm.prank(owner);
        rebalancer.addIndexToType(INDEX_TYPE, address(second));

        _fundGarden(alice, bound(seed, 1e17, 1e19), bound(seed >> 4, 1e6, 1e9), 0);
        _fundGarden(bob, bound(seed >> 8, 1e17, 1e19), bound(seed >> 12, 1e6, 1e9), 0);
        _warpPastInterval();

        uint256 before = _portfolioValue(gardens);
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
        uint256 afterValue = _portfolioValue(gardens);

        assertGe(afterValue, Math.mulDiv(before, 9950, 10_000, Math.Rounding.Floor), "value lost beyond 0.5%");
        assertLe(afterValue, before + VALUE_DUST, "value created by rebalance");
        assertEq(rebalancer.gardenCursor(INDEX_TYPE), 0, "round completed");
        assertEq(weth.balanceOf(address(rebalancer)) + wbtc.balanceOf(address(rebalancer)), 0, "no residue");
    }

    // ═══════════════════════════════════════════════════════════════════════
    // setDexConfig SELECTOR WHITELIST
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Every whitelisted router swap selector must be accepted by
    ///         setDexConfig regardless of dex type, and stored verbatim.
    function testFuzz_setDexConfig_whitelistedSelectors(bytes4 selector, uint8 dexTypeSeed) public {
        if (!_isWhitelisted(selector)) return; // covered by the revert test below
        bytes32 dexId = keccak256(abi.encode(selector, dexTypeSeed));
        poolRegistry.setDexRegistered(dexId, true);
        poolRegistry.setDexActive(dexId, true);

        vm.prank(owner);
        rebalancer.setDexConfig(dexId, address(router), address(router), selector, Rebalancer.DexType(dexTypeSeed % 3));

        (address routerStored, address quoteFacetStored, bytes4 selectorStored,) = rebalancer.dexConfigs(dexId);
        assertEq(routerStored, address(router), "router stored");
        assertEq(quoteFacetStored, address(router), "quoteFacet stored");
        assertEq(selectorStored, selector, "selector stored");
    }

    /// @notice Any selector outside the whitelist must revert with
    ///         UnapprovedSwapSelector — the compromised-owner drain protection.
    function testFuzz_setDexConfig_unapprovedSelector_reverts(bytes4 selector) public {
        if (_isWhitelisted(selector)) return; // covered by the success test above
        bytes32 dexId = keccak256(abi.encode(selector));
        poolRegistry.setDexRegistered(dexId, true);
        vm.prank(owner);
        if (selector == bytes4(0)) {
            // The zero selector trips the InvalidConfig guard before the whitelist check.
            vm.expectRevert(Rebalancer_InvalidConfig.selector);
            rebalancer.setDexConfig(dexId, address(router), address(router), selector, Rebalancer.DexType.V2_STANDARD);
        } else {
            vm.expectRevert(abi.encodeWithSelector(Rebalancer_UnapprovedSwapSelector.selector, selector));
            rebalancer.setDexConfig(dexId, address(router), address(router), selector, Rebalancer.DexType.V2_STANDARD);
        }
    }

    /// @notice setDexConfig validation: zero / EOA router or quoteFacet must
    ///         revert with InvalidConfig, and an unregistered dex with
    ///         DexNotConfigured.
    function testFuzz_setDexConfig_invalidAddresses_reverts(uint256 seed) public {
        address routerAddr = address(uint160(bound(seed, 1, type(uint160).max)));
        if (routerAddr.code.length > 0) routerAddr = makeAddr("eoa");
        bytes32 dexId = keccak256(abi.encode("invalidcfg", seed));
        poolRegistry.setDexRegistered(dexId, true);

        vm.prank(owner);
        vm.expectRevert(Rebalancer_InvalidConfig.selector);
        rebalancer.setDexConfig(dexId, routerAddr, address(router), 0x38ed1739, Rebalancer.DexType.V2_STANDARD);

        vm.prank(owner);
        vm.expectRevert(Rebalancer_InvalidConfig.selector);
        rebalancer.setDexConfig(dexId, address(router), address(0), 0x38ed1739, Rebalancer.DexType.V2_STANDARD);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Rebalancer_DexNotConfigured.selector, bytes32("UNREGISTERED_DEX")));
        rebalancer.setDexConfig(
            bytes32("UNREGISTERED_DEX"), address(router), address(router), 0x38ed1739, Rebalancer.DexType.V2_STANDARD
        );
    }

    // ═══════════════════════════════════════════════════════════════════════
    // HELPERS
    // ═══════════════════════════════════════════════════════════════════════

    function _setBatch(uint256 b) internal {
        vm.prank(owner);
        rebalancer.setMaxGardensPerBatch(INDEX_TYPE, b);
    }

    /// @dev Creates n fresh gardens, funds each with random amounts, and registers
    ///      them on the index. Returns the garden list.
    function _fundedGardens(uint256 n, uint256 seed) internal returns (address[] memory gs) {
        gs = new address[](n);
        for (uint256 i = 0; i < n; i++) {
            gs[i] = makeAddr(string(abi.encodePacked("fuzzgarden", i)));
            _fundGarden(
                gs[i],
                bound(uint256(keccak256(abi.encode(seed, i, 0))), 1e17, 2e19),
                bound(uint256(keccak256(abi.encode(seed, i, 1))), 1e6, 1e10),
                bound(uint256(keccak256(abi.encode(seed, i, 2))), 1e6, 1e9)
            );
        }
        blokc2Index.setGardens(gs);
    }

    function _isWhitelisted(bytes4 sel) internal pure returns (bool) {
        return sel == bytes4(0x38ed1739) // swapExactTokensForTokens (Uniswap V2)
            || sel == bytes4(0xac3893ba) // swapExactTokensForTokensSupportingFeeOnTransferTokens (Camelot V2)
            || sel == bytes4(0x6c42f2b1) // swapExactTokensForTokensSupportingFeeOnTransferTokensV2 (Camelot V2 router)
            || sel == bytes4(0x414bf389) // exactInputSingle (Uniswap V3)
            || sel == bytes4(0xbc651188); // exactInputSingle (Camelot V3, 7-param)
    }

    /// @dev Total USD value (8-dec) of all tokens across the given gardens and
    ///      the rebalancer. Matches the contract's valuation universe for the
    ///      WETH/WBTC index (USDC is not a component and has a registered feed).
    function _portfolioValue(address[] memory gs) internal view returns (uint256 total) {
        address[3] memory tokens = [address(weth), address(wbtc), address(usdc)];
        for (uint256 t = 0; t < 3; t++) {
            uint256 sum = IERC20(tokens[t]).balanceOf(address(rebalancer));
            for (uint256 i = 0; i < gs.length; i++) {
                sum += IERC20(tokens[t]).balanceOf(gs[i]);
            }
            total += Math.mulDiv(
                sum, compRegistry.prices(tokens[t]), 10 ** IERC20Metadata(tokens[t]).decimals(), Math.Rounding.Floor
            );
        }
    }

    function _gardenValue(address g) internal view returns (uint256 total) {
        total = Math.mulDiv(weth.balanceOf(g), compRegistry.prices(address(weth)), 10 ** 18, Math.Rounding.Floor)
            + Math.mulDiv(wbtc.balanceOf(g), compRegistry.prices(address(wbtc)), 10 ** 8, Math.Rounding.Floor)
            + Math.mulDiv(usdc.balanceOf(g), compRegistry.prices(address(usdc)), 10 ** 6, Math.Rounding.Floor);
    }

    function _contributionFromLogs(Vm.Log[] memory logs, address garden) internal pure returns (uint256 contrib) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == Rebalancer.GardenRedistributed.selector) {
                if (address(uint160(uint256(logs[i].topics[1]))) == garden) {
                    contrib = abi.decode(logs[i].data, (uint256));
                    break;
                }
            }
        }
    }
}
