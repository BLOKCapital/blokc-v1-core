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

contract IndexTimestampActor is IndexFacetTestBase {
    bool public intentCreated;
    bool public rebalanceExecuted;

    constructor() {
        super.setUp();
        _connect();
    }

    function createIntent() external {
        if (
            block.timestamp >= IndexStorage.layout().lastIntentTimestamp + IndexStorage.INTENT_INTERVAL
                && block.timestamp >= IndexStorage.layout().lastRebalanceTimestamp + IndexStorage.REBALANCE_INTERVAL
        ) {
            try h.rebalanceIntent() {
                intentCreated = true;
            } catch { }
        }
    }

    function executeRebalance() external {
        if (!h.hasPendingIntent()) return;
        if (block.timestamp > IndexStorage.layout().lastIntentTimestamp + IndexStorage.INTENT_EXPIRY) return;
        if (block.timestamp < IndexStorage.layout().lastRebalanceTimestamp + IndexStorage.REBALANCE_INTERVAL) return;
        try h.rebalance(new SwapStep[](0)) {
            rebalanceExecuted = true;
        } catch { }
    }

    function advanceTime(uint256 seconds_) external {
        vm.warp(block.timestamp + bound(seconds_, 1, 2 hours));
    }

    function getLastRebalance() external view returns (uint256) {
        return h.getLastRebalanceTimestamp();
    }

    function getLastIntent() external view returns (uint256) {
        return h.getLastIntentTimestamp();
    }

    // Expose harness rebalancing flag directly — h is internal so callers
    // outside this contract cannot access it via actor.h()
    function isHarnessRebalancing() external view returns (bool) {
        return h.isRebalancing();
    }
}

contract IndexTimestampInvariantTest is Test {
    IndexTimestampActor actor;

    uint256 prevRebalance;
    uint256 prevIntent;

    function setUp() public {
        actor = new IndexTimestampActor();
        targetContract(address(actor));
        prevRebalance = actor.getLastRebalance();
        prevIntent = actor.getLastIntent();
    }

    function invariant_rebalanceTimestampNeverDecreases() public view {
        assertGe(actor.getLastRebalance(), prevRebalance, "lastRebalanceTimestamp decreased");
    }

    function invariant_intentTimestampNeverDecreases() public view {
        assertGe(actor.getLastIntent(), prevIntent, "lastIntentTimestamp decreased");
    }

    function invariant_rebalancingFlagAlwaysFalseAtRest() public view {
        assertFalse(actor.isHarnessRebalancing(), "rebalancing flag stuck true");
    }
}
