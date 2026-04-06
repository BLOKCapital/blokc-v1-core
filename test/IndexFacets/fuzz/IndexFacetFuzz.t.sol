// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import "forge-std/Test.sol";

import { IndexFacetTestBase } from "../unit/IndexFacetTest.t.sol";

import { IndexFacet } from "../../../src/garden/facets/indexFacets/IndexFacet.sol";

import { IndexBase } from "../../../src/garden/facets/indexFacets/IndexBase.sol";

import { IndexStorage } from "../../../src/garden/facets/indexFacets/IndexStorage.sol";

import { IIndex, SwapStep, PendingIntent } from "../../../src/garden/facets/indexFacets/IIndex.sol";
import { SwapInstruction } from "src/interfaces/ISwapInstruction.sol";
import { IFacetRegistry } from "../../../src/interfaces/IFacetRegistry.sol";
import { LibDiamond } from "../../../src/garden/libraries/LibDiamond.sol";
import { LibStorageSlot } from "../../../src/garden/libraries/LibStorageSlot.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {
    IndexFacet_NotConnectedToIndex,
    IndexFacet_AlreadyConnectedToIndex,
    IndexFacet_IndexNotRegistered,
    IndexFacet_IntentIntervalNotPassed,
    IndexFacet_RebalanceIntervalNotPassed,
    IndexFacet_NoPendingIntent,
    IndexFacet_BalanceOutsideThreshold,
    IndexFacet_SwapCallFailed,
    IndexFacet_SelectorNotWhitelisted,
    IndexFacet_SelectorNotFound,
    IndexFacet_InsufficientSwapOutput,
    IndexFacet_IntentExpired,
    IndexFacet_ExcessiveValueLoss,
    IndexFacet_RebalanceReentrancy,
    IndexFacet_ZeroTotalValue
} from "../../../src/garden/facets/indexFacets/IndexBase.sol";
// =============================================================================
//  FUZZ — rebalanceIntent timing
// =============================================================================

contract RebalanceIntentFuzzTest is IndexFacetTestBase {
    function setUp() public override {
        super.setUp();
        _connect();
    }

    /// @dev Any timestamp within the intent interval must revert.
    function testFuzz_intentInterval_alwaysRevertsBeforeExpiry(uint256 elapsed) public {
        elapsed = bound(elapsed, 0, IndexStorage.INTENT_EXPIRY - 1);

        // First intent to set lastIntentTimestamp
        vm.warp(block.timestamp + IndexStorage.REBALANCE_INTERVAL + IndexStorage.INTENT_EXPIRY + 1);
        h.rebalanceIntent();

        // Advance by less than INTENT_EXPIRY
        vm.warp(block.timestamp + elapsed);
        vm.expectRevert(IndexFacet_IntentIntervalNotPassed.selector);
        h.rebalanceIntent();
    }

    /// @dev Any elapsed time below REBALANCE_INTERVAL must hit the rebalance interval guard.
    ///      We must also force lastIntentTimestamp far enough back that the intent
    ///      interval check (checked first in the code) does NOT fire instead.
    function testFuzz_rebalanceInterval_alwaysRevertsBeforeCooldown(uint256 elapsed) public {
        elapsed = bound(elapsed, 0, IndexStorage.REBALANCE_INTERVAL - 1);

        // Push lastIntentTimestamp far into the past so the intent interval check passes.
        // INTENT_EXPIRY = 10 min. Setting to 0 means timestamp must be > 600 to pass.
        // After setUp the default Forge timestamp is 1, so warp enough to clear it.
        vm.warp(block.timestamp + IndexStorage.INTENT_EXPIRY + 1);
        h.forceSetLastIntentTimestamp(0); // treated as "very long ago" → passes intent check

        // Now set the rebalance timestamp to NOW and advance by less than the interval.
        h.forceSetLastRebalanceTimestamp(block.timestamp);
        vm.warp(block.timestamp + elapsed);
        vm.expectRevert(IndexFacet_RebalanceIntervalNotPassed.selector);
        h.rebalanceIntent();
    }
}

// =============================================================================
//  FUZZ — swap minOutput
// =============================================================================

contract SwapOutputFuzzTest is IndexFacetTestBase {
    function setUp() public override {
        super.setUp();
        _connect();
        _createIntent();
    }

    /// @dev Any amountOut above zero must revert because the no-op mock produces 0.
    function testFuzz_minOutput_revertsForAnyPositiveMin(uint256 minOut) public {
        minOut = bound(minOut, 1, type(uint128).max);

        SwapStep[] memory steps = new SwapStep[](1);
        address[] memory tokens = new address[](2);
        tokens[0] = address(wbtc);
        tokens[1] = address(weth);
        address[] memory pools = new address[](1);
        pools[0] = address(0);
        steps[0] = SwapStep({
            dexId: keccak256("TEST_DEX"),
            instruction: SwapInstruction({
                amountIn: 0,
                amountOut: minOut,
                tokens: tokens,
                pools: pools,
                exactOutput: false
            })
        });
        vm.expectRevert();
        h.rebalance(steps);
    }
}

