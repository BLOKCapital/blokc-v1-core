// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import "forge-std/Test.sol";

import { IndexFacetTestBase } from "../unit/IndexFacetTest.t.sol";

import { IndexStorage } from "../../../src/garden/facets/indexFacets/IndexStorage.sol";

import { IIndex, SwapCall } from "../../../src/garden/facets/indexFacets/IIndex.sol";

contract IndexTimestampActor is IndexFacetTestBase {
    bool public rebalanceExecuted;

    constructor() {
        super.setUp();
        _connect();
        // Balance portfolio so rebalances can succeed
        h.setTokenBalance(address(weth), 2e18);
        h.setTokenBalance(address(wbtc), 6_666_666);
        h.setTokenBalance(address(usdc), 0);
    }

    function executeRebalance() external {
        if (block.timestamp < IndexStorage.layout().lastRebalanceTimestamp + IndexStorage.REBALANCE_INTERVAL) return;
        try h.rebalance(new SwapCall[](0)) {
            rebalanceExecuted = true;
        } catch { }
    }

    function advanceTime(uint256 seconds_) external {
        vm.warp(block.timestamp + bound(seconds_, 1, 2 hours));
    }

    function getLastRebalance() external view returns (uint256) {
        return h.getLastRebalanceTimestamp();
    }

    function isHarnessRebalancing() external view returns (bool) {
        return h.isRebalancing();
    }
}

contract IndexTimestampInvariantTest is Test {
    IndexTimestampActor actor;

    uint256 prevRebalance;

    function setUp() public {
        actor = new IndexTimestampActor();
        targetContract(address(actor));
        prevRebalance = actor.getLastRebalance();
    }

    function invariant_rebalanceTimestampNeverDecreases() public view {
        assertGe(actor.getLastRebalance(), prevRebalance, "lastRebalanceTimestamp decreased");
    }

    function invariant_rebalancingFlagAlwaysFalseAtRest() public view {
        assertFalse(actor.isHarnessRebalancing(), "rebalancing flag stuck true");
    }
}
