// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import "forge-std/Test.sol";

import { IndexFacetTestBase } from "../unit/IndexFacetTest.t.sol";

import { IndexStorage } from "../../../src/garden/facets/indexFacets/IndexStorage.sol";

import { IIndex, SwapCall } from "../../../src/garden/facets/indexFacets/IIndex.sol";
import {
    IndexFacet_RebalanceIntervalNotPassed,
    IndexFacet_InsufficientSwapOutput
} from "../../../src/garden/facets/indexFacets/IndexBase.sol";

// =============================================================================
//  FUZZ — rebalance interval timing
// =============================================================================

contract RebalanceIntervalFuzzTest is IndexFacetTestBase {
    function setUp() public override {
        super.setUp();
        _connect();
    }

    /// @dev Any elapsed time below REBALANCE_INTERVAL must revert.
    function testFuzz_rebalanceInterval_alwaysRevertsBeforeCooldown(uint256 elapsed) public {
        elapsed = bound(elapsed, 0, IndexStorage.REBALANCE_INTERVAL - 1);

        // Set the rebalance timestamp to NOW and advance by less than the interval.
        h.forceSetLastRebalanceTimestamp(block.timestamp);
        vm.warp(block.timestamp + elapsed);

        // Balance portfolio so _verifyBalancesMatchTargets would pass if we got past the interval check
        h.setTokenBalance(address(weth), 2e18);
        h.setTokenBalance(address(wbtc), 6_666_666);
        h.setTokenBalance(address(usdc), 0);

        vm.expectRevert(IndexFacet_RebalanceIntervalNotPassed.selector);
        h.rebalance(new SwapCall[](0));
    }
}

// =============================================================================
//  FUZZ — swap minOutput
// =============================================================================

contract SwapOutputFuzzTest is IndexFacetTestBase {
    function setUp() public override {
        super.setUp();
        _connect();
        _warpPastInterval();
        // Balance portfolio for rebalance to reach swap execution
        h.setTokenBalance(address(weth), 2e18);
        h.setTokenBalance(address(wbtc), 6_666_666);
        h.setTokenBalance(address(usdc), 0);
    }

    /// @dev Any minOutput above zero must revert because the no-op mock produces 0.
    function testFuzz_minOutput_revertsForAnyPositiveMin(uint256 minOut) public {
        minOut = bound(minOut, 1, type(uint128).max);

        SwapCall[] memory calls = new SwapCall[](1);
        calls[0] = SwapCall({
            selector: swapTokensSel,
            data: abi.encode(address(wbtc), address(weth), uint256(0), uint256(0)),
            outputToken: address(weth),
            minOutput: minOut
        });
        vm.expectRevert(
            abi.encodeWithSelector(
                IndexFacet_InsufficientSwapOutput.selector, uint256(0), address(weth), uint256(0), minOut
            )
        );
        h.rebalance(calls);
    }
}
