// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import "forge-std/Test.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Rebalancer, Rebalancer_RebalanceIntervalNotPassed } from "src/rebalancer/Rebalancer.sol";
import { MockERC20, MockIndex, MockComponentRegistry } from "../unit/RebalancerTest.t.sol";

/// @title RebalancerHandler
/// @notice Fuzzer handler for the Rebalancer cumulative-rebalance invariant suite.
///
///         The handler drives the full rebalance lifecycle — random deposits, new
///         gardens, batched (cursor-driven) rebalances, and the 24h cooldown — while
///         maintaining exact ghost state:
///           - per-token balance sums across all gardens + the rebalancer,
///           - system USD value (funding mints + swap amounts from events),
///           - the expected garden cursor after every action,
///           - per-garden contributions, both from the contract's own events and
///             from an independent mirror of the contract's valuation math.
///
///         The mock router used by the harness executes value-neutral swaps (it
///         burns the input and mints the output at fixed, price-consistent rates),
///         so any deviation between ghost accounting and on-chain state is a real
///         conservation violation, not a swap-slippage artifact.
contract RebalancerHandler is Test {
    // ========================================================================
    // Protocol refs (mirror of RebalancerTestBase mocks)
    // ========================================================================

    Rebalancer public immutable rebalancer;
    MockIndex public immutable index;
    MockComponentRegistry public immutable compRegistry;
    MockERC20 public immutable weth;
    MockERC20 public immutable wbtc;
    MockERC20 public immutable usdc;

    bytes32 public constant INDEX_TYPE = keccak256("BLOKC2");
    bytes32 public constant SYM_USDC = bytes32("USDC");
    uint256 public constant REBALANCE_INTERVAL = 24 hours;
    uint256 public constant MAX_GARDENS = 12;

    // ========================================================================
    // Ghost state
    // ========================================================================

    /// @notice Per-token sum of balances across all gardens + the rebalancer (exact).
    ///         Updated by funding mints and by CumulativeSwapExecuted event amounts.
    mapping(address => uint256) public ghost_tokenSum;

    /// @notice System USD value (8-dec) per ghost accounting (funding + swaps).
    uint256 public ghost_value;

    /// @notice System USD value at the start of the most recent rebalance call.
    ///         Compared against the live value by the value-loss guard invariant.
    uint256 public ghost_valueBeforeRebalance;

    /// @notice Expected gardenCursor after the last successful action.
    uint256 public ghost_expectedCursor;

    /// @notice Per-garden contribution captured from GardenRedistributed events.
    mapping(address => uint256) public ghost_gardenContribution;

    /// @notice Per-garden contribution mirrored independently (identical floor math)
    ///         from balances read before the rebalance call.
    mapping(address => uint256) public ghost_expectedContribution;

    /// @notice Whether a garden has been processed by at least one batch.
    mapping(address => bool) public ghost_gardenProcessed;

    /// @notice totalValueUsd captured from CumulativeRebalanceStarted (round start only).
    uint256 public ghost_eventRoundStartTotal;

    /// @notice Mirrored batch value for the round-start call (paired with the event).
    uint256 public ghost_expectedRoundStartValue;

    /// @notice Timestamp of the last completed round (cursor returned to 0).
    uint256 public ghost_lastRoundCompletedAt;

    /// @notice Count of rebalance calls that reverted (defensive; should stay 0).
    uint256 public ghost_revertedRebalances;

    /// @notice True when no funding has occurred since the last completed round —
    ///         the only state in which per-garden allocations are guaranteed to be
    ///         proportional to contributions. Set true only when a round completes
    ///         with no funding since that round started (funding that lands
    ///         mid-round breaks proportionality for gardens processed before it,
    ///         even after the round completes).
    bool public ghost_proportionalValid;

    /// @notice Whether any funding/addGarden happened since the current round
    ///         started. A round completing with this set cannot leave every
    ///         garden proportional to its contribution.
    bool public ghost_fundingSinceRoundStart;

    /// @notice All gardens currently registered in the MockIndex, in order.
    address[] public ghost_allGardens;

    uint256 public ghost_gardenCount;
    uint256 public gardenCounter;

    // ========================================================================
    // Constructor — baseline funding + one completed round
    // ========================================================================

    constructor(
        Rebalancer rebalancer_,
        MockIndex index_,
        MockComponentRegistry compRegistry_,
        MockERC20 weth_,
        MockERC20 wbtc_,
        MockERC20 usdc_,
        address[] memory initialGardens
    ) {
        rebalancer = rebalancer_;
        index = index_;
        compRegistry = compRegistry_;
        weth = weth_;
        wbtc = wbtc_;
        usdc = usdc_;

        // Baseline funding + approvals for every initial garden.
        for (uint256 i = 0; i < initialGardens.length; i++) {
            _addFundedGarden(initialGardens[i], 5e18, 5e7, 2e8);
        }

        // Complete one full round so the suite starts freshly rebalanced.
        vm.warp(25 hours);
        _completeRound();
        ghost_proportionalValid = true;
        ghost_fundingSinceRoundStart = false;
    }

    // ========================================================================
    // Handler actions
    // ========================================================================

    /// @notice Mint random token amounts to every garden. Arbitrary deposits
    ///         legitimately break allocation-proportionality until the next
    ///         completed round (ghost_proportionalValid = false).
    function fundGardens(uint256 seed) external {
        for (uint256 i = 0; i < ghost_allGardens.length; i++) {
            address g = ghost_allGardens[i];
            uint256 wethAmt = bound(uint256(keccak256(abi.encode(seed, i, 0))), 1e17, 2e19);
            uint256 wbtcAmt = bound(uint256(keccak256(abi.encode(seed, i, 1))), 1e6, 1e11);
            uint256 usdcAmt = bound(uint256(keccak256(abi.encode(seed, i, 2))), 1e6, 1e11);
            _mintToGarden(g, wethAmt, wbtcAmt, usdcAmt);
        }
        ghost_proportionalValid = false;
        ghost_fundingSinceRoundStart = true;
    }

    /// @notice Add a brand-new funded + approved garden to the index.
    ///         Capped at MAX_GARDENS to keep rounds and gas bounded.
    function addGarden(uint256 seed) external {
        if (ghost_gardenCount >= MAX_GARDENS) return;
        address g = vm.addr(1000 + gardenCounter++);
        uint256 wethAmt = bound(uint256(keccak256(abi.encode(seed, 0xaaaa))), 1e17, 2e19);
        uint256 wbtcAmt = bound(uint256(keccak256(abi.encode(seed, 0xbbbb))), 1e6, 1e11);
        uint256 usdcAmt = bound(uint256(keccak256(abi.encode(seed, 0xcccc))), 1e6, 1e11);
        _addFundedGarden(g, wethAmt, wbtcAmt, usdcAmt);
        ghost_proportionalValid = false;
        ghost_fundingSinceRoundStart = true;
    }

    /// @notice Process one batch of the current round. When a new round would need
    ///         to start (cursor == 0) inside the 24h cooldown, first verifies the
    ///         contract blocks the call with Rebalancer_RebalanceIntervalNotPassed,
    ///         then warps past the cooldown and proceeds.
    function rebalance(uint256) external {
        if (rebalancer.gardenCursor(INDEX_TYPE) == 0) {
            uint256 last = rebalancer.lastRebalanceTimestamp(INDEX_TYPE);
            uint256 nextAllowed = last + REBALANCE_INTERVAL;
            if (block.timestamp < nextAllowed) {
                // A new round must be blocked until the cooldown has elapsed.
                vm.expectRevert(
                    abi.encodeWithSelector(
                        Rebalancer_RebalanceIntervalNotPassed.selector, INDEX_TYPE, last, nextAllowed
                    )
                );
                rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 60);
                vm.warp(nextAllowed + 1);
            }
        }
        _rebalanceOnce();
    }

    // ========================================================================
    // Internal — single rebalance call with mirror + event accounting
    // ========================================================================

    function _completeRound() internal {
        uint256 guard;
        while (rebalancer.gardenCursor(INDEX_TYPE) != 0 && guard < 32) {
            _rebalanceOnce();
            guard++;
        }
    }

    function _rebalanceOnce() internal {
        uint256 cursor = rebalancer.gardenCursor(INDEX_TYPE);
        if (cursor == 0) {
            // A new round starts: no funding may have happened since its start
            // for the completed round to leave every garden proportional.
            ghost_fundingSinceRoundStart = false;
        }
        uint256 batch = rebalancer.maxGardensPerBatch(INDEX_TYPE);
        uint256 total = ghost_gardenCount;

        // Mirror the exact batch the contract will process (single index → contiguous slice).
        address[] memory batchGardens = new address[](0);
        if (total > 0 && cursor < total) {
            uint256 end = cursor + batch < total ? cursor + batch : total;
            batchGardens = new address[](end - cursor);
            for (uint256 i = cursor; i < end; i++) {
                batchGardens[i - cursor] = ghost_allGardens[i];
            }
        }

        // Mirror the contract's per-garden contribution valuation (identical floor math).
        uint256[] memory expectedContribs = new uint256[](batchGardens.length);
        uint256 expectedBatchValue;
        for (uint256 i = 0; i < batchGardens.length; i++) {
            expectedContribs[i] = _mirrorContribution(batchGardens[i]);
            expectedBatchValue += expectedContribs[i];
        }

        ghost_valueBeforeRebalance = _totalPortfolioValue();

        vm.recordLogs();
        try rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300) {
            _commitBatch(batchGardens, expectedContribs, expectedBatchValue, cursor, batch, total);
        } catch {
            ghost_revertedRebalances++;
        }
    }

    function _commitBatch(
        address[] memory batchGardens,
        uint256[] memory expectedContribs,
        uint256 expectedBatchValue,
        uint256 cursorBefore,
        uint256 batch,
        uint256 total
    )
        internal
    {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; i++) {
            Vm.Log memory log = logs[i];
            if (log.topics[0] == Rebalancer.GardenRedistributed.selector) {
                address garden = address(uint160(uint256(log.topics[1])));
                ghost_gardenContribution[garden] = abi.decode(log.data, (uint256));
                ghost_gardenProcessed[garden] = true;
            } else if (log.topics[0] == Rebalancer.CumulativeSwapExecuted.selector) {
                address tokenIn = address(uint160(uint256(log.topics[2])));
                address tokenOut = address(uint160(uint256(log.topics[3])));
                (uint256 amountIn, uint256 amountOut,) = abi.decode(log.data, (uint256, uint256, address));
                ghost_tokenSum[tokenIn] -= amountIn;
                ghost_tokenSum[tokenOut] += amountOut;
                ghost_value -= _tokenValue(tokenIn, amountIn);
                ghost_value += _tokenValue(tokenOut, amountOut);
            } else if (log.topics[0] == Rebalancer.CumulativeRebalanceStarted.selector) {
                (, uint256 totalValueUsd) = abi.decode(log.data, (uint256, uint256));
                ghost_eventRoundStartTotal = totalValueUsd;
            }
        }

        // Pair the mirrored contributions with the event contributions from the same call.
        for (uint256 i = 0; i < batchGardens.length; i++) {
            ghost_expectedContribution[batchGardens[i]] = expectedContribs[i];
        }
        if (cursorBefore == 0) ghost_expectedRoundStartValue = expectedBatchValue;

        // Cursor must advance by exactly batchSize, or reset to 0 at round end.
        uint256 cursorAfter = rebalancer.gardenCursor(INDEX_TYPE);
        if (cursorBefore + batch >= total) {
            assertEq(cursorAfter, 0, "cursor must reset at round end");
            assertEq(
                rebalancer.lastRebalanceTimestamp(INDEX_TYPE),
                block.timestamp,
                "round completion must stamp lastRebalanceTimestamp"
            );
            ghost_expectedCursor = 0;
            ghost_lastRoundCompletedAt = block.timestamp;
            // A completed round only guarantees proportionality when no funding
            // landed after the round started (gardens processed before the
            // funding hold pre-funding allocations that no longer match).
            ghost_proportionalValid = !ghost_fundingSinceRoundStart;
        } else {
            assertEq(cursorAfter, cursorBefore + batch, "cursor must advance by batchSize");
            ghost_expectedCursor = cursorBefore + batch;
        }
    }

    // ========================================================================
    // Internal — ghost helpers
    // ========================================================================

    function _mintToGarden(address g, uint256 wethAmt, uint256 wbtcAmt, uint256 usdcAmt) internal {
        weth.mint(g, wethAmt);
        wbtc.mint(g, wbtcAmt);
        usdc.mint(g, usdcAmt);
        ghost_tokenSum[address(weth)] += wethAmt;
        ghost_tokenSum[address(wbtc)] += wbtcAmt;
        ghost_tokenSum[address(usdc)] += usdcAmt;
        ghost_value += _tokenValue(address(weth), wethAmt);
        ghost_value += _tokenValue(address(wbtc), wbtcAmt);
        ghost_value += _tokenValue(address(usdc), usdcAmt);
    }

    function _addFundedGarden(address g, uint256 wethAmt, uint256 wbtcAmt, uint256 usdcAmt) internal {
        _mintToGarden(g, wethAmt, wbtcAmt, usdcAmt);
        vm.prank(g);
        weth.approve(address(rebalancer), type(uint256).max);
        vm.prank(g);
        wbtc.approve(address(rebalancer), type(uint256).max);
        vm.prank(g);
        usdc.approve(address(rebalancer), type(uint256).max);
        ghost_allGardens.push(g);
        ghost_gardenCount++;
        index.setGardens(ghost_allGardens);
    }

    /// @dev Independent mirror of _snapshotAndPullTokens' per-garden valuation:
    ///      same iteration order, same floor math, same USDC handling.
    function _mirrorContribution(address garden) internal view returns (uint256 v) {
        (bytes32[] memory symbols,) = index.getWeights();
        bool usdcIsComponent = _symbolInSet(symbols, SYM_USDC);
        for (uint256 j = 0; j < symbols.length; j++) {
            address token = compRegistry.getComponentAddress(symbols[j]);
            uint256 balance = IERC20(token).balanceOf(garden);
            if (balance > 0) {
                v += Math.mulDiv(
                    balance, compRegistry.prices(token), 10 ** IERC20Metadata(token).decimals(), Math.Rounding.Floor
                );
            }
        }
        if (!usdcIsComponent && compRegistry.isComponentRegistered(SYM_USDC)) {
            uint256 usdcBalance = usdc.balanceOf(garden);
            if (usdcBalance > 0) {
                v += Math.mulDiv(
                    usdcBalance, compRegistry.prices(address(usdc)), 10 ** usdc.decimals(), Math.Rounding.Floor
                );
            }
        }
    }

    function _tokenValue(address token, uint256 amount) internal view returns (uint256) {
        return
            Math.mulDiv(amount, compRegistry.prices(token), 10 ** IERC20Metadata(token).decimals(), Math.Rounding.Floor);
    }

    function _systemBalance(address token) internal view returns (uint256 sum) {
        sum = IERC20(token).balanceOf(address(rebalancer));
        for (uint256 i = 0; i < ghost_allGardens.length; i++) {
            sum += IERC20(token).balanceOf(ghost_allGardens[i]);
        }
    }

    /// @dev Mirrors _computeTotalValue's valuation universe (components + USDC when
    ///      it is not a component but has a registered feed).
    function _totalPortfolioValue() internal view returns (uint256 total) {
        (bytes32[] memory symbols,) = index.getWeights();
        bool usdcIsComponent = _symbolInSet(symbols, SYM_USDC);
        for (uint256 j = 0; j < symbols.length; j++) {
            address token = compRegistry.getComponentAddress(symbols[j]);
            total += _tokenValue(token, _systemBalance(token));
        }
        if (!usdcIsComponent && compRegistry.isComponentRegistered(SYM_USDC)) {
            total += _tokenValue(address(usdc), _systemBalance(address(usdc)));
        }
    }

    function _symbolInSet(bytes32[] memory symbols, bytes32 target) internal pure returns (bool) {
        for (uint256 i = 0; i < symbols.length; i++) {
            if (symbols[i] == target) return true;
        }
        return false;
    }

    // ========================================================================
    // Ghost accessors
    // ========================================================================

    function ghostAllGardens() external view returns (address[] memory) {
        return ghost_allGardens;
    }
}
