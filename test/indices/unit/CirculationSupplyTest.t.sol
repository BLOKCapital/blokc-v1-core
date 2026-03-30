// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Test } from "forge-std/Test.sol";

import { IndicesTestSetUp } from "test/indices/IndicesTestSetUp.sol";
import {
    CirculatingSupply,
    CirculatingSupply_SupplyNotAvailable,
    CirculatingSupply_StaleSupplyData,
    CirculatingSupply_InvalidUpdater,
    CirculatingSupply_LengthMismatch,
    CirculatingSupply_OnlyUpdater
} from "../../../src/indices/CirculatingSupply.sol";

contract CirculationSupplyTest is IndicesTestSetUp {
    string[] symbols;
    uint256[] supply;

    function setUp() public override {
        super.setUp();
        symbols = new string[](2);
        symbols[0] = "ETH";
        symbols[1] = "BTC";

        supply = new uint256[](2);
        supply[0] = 2e18;
        supply[1] = 5e18;
    }

    modifier updateBatch() {
        vm.startPrank(updater);
        cirSupply.updateBatch(symbols, supply);
        vm.stopPrank();
        _;
    }

    /**
     *     function updateBatch(string[] calldata symbols, uint256[] calldata supplies) external onlyUpdater {
     *     if (symbols.length != supplies.length) revert CirculatingSupply_LengthMismatch();
     *     uint256 time = block.timestamp;
     *     for (uint256 i = 0; i < symbols.length; i++) {
     *         uint256 oldSupply = supply[symbols[i]];
     *
     *         emit SupplyUpdated(symbols[i], supplies[i], time);
     *     }
     * }
     */
    // ═══════════════════════════════════════════════════════════════════════
    //                       updateBatch
    // ═══════════════════════════════════════════════════════════════════════

    function test_updateBatch() public {
        vm.startPrank(updater);
        vm.expectEmit(true, false, false, true);
        emit CirculatingSupply.SupplyUpdated(symbols[0], supply[0], block.timestamp);
        vm.expectEmit(true, false, false, true);
        emit CirculatingSupply.SupplyUpdated(symbols[1], supply[1], block.timestamp);
        cirSupply.updateBatch(symbols, supply);
        vm.stopPrank();

        // stroage variable check
        uint256 totalSupply = cirSupply.getTotalSupply();
        assertEq(totalSupply, supply[0] + supply[1]);

        assertEq(cirSupply.getLastUpdated(symbols[0]), block.timestamp);
        assertEq(cirSupply.getLastUpdated(symbols[1]), block.timestamp);

        assertEq(cirSupply.getSupply(symbols[0]), supply[0]);

        // re-writing the supplies
        supply[0] = 10e18;
        supply[1] = 15e18;
        vm.startPrank(updater);
        vm.expectEmit(true, false, false, true);
        emit CirculatingSupply.SupplyUpdated(symbols[0], supply[0], block.timestamp);
        vm.expectEmit(true, false, false, true);
        emit CirculatingSupply.SupplyUpdated(symbols[1], supply[1], block.timestamp);
        cirSupply.updateBatch(symbols, supply);
        vm.stopPrank();

        totalSupply = cirSupply.getTotalSupply();
        assertEq(totalSupply, supply[0] + supply[1]);

        assertEq(cirSupply.getLastUpdated(symbols[0]), block.timestamp);
        assertEq(cirSupply.getLastUpdated(symbols[1]), block.timestamp);

        assertEq(cirSupply.getSupply(symbols[0]), supply[0]);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                       updateBatch - Revert
    // ═══════════════════════════════════════════════════════════════════════

    function test_updateBatch_onlyUpdater() public {
        vm.startPrank(makeAddr("user"));
        vm.expectRevert(CirculatingSupply_OnlyUpdater.selector);
        cirSupply.updateBatch(symbols, supply);
        vm.stopPrank();
    }

    function test_updateBatch_lengthMismatch() public {
        string[] memory _symbols = new string[](3);
        _symbols[0] = "SOL";
        _symbols[1] = "BTC";
        _symbols[2] = "ETH";

        vm.startPrank(updater);
        vm.expectRevert(CirculatingSupply_LengthMismatch.selector);
        cirSupply.updateBatch(_symbols, supply);
        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                       updateUpdater
    // ═══════════════════════════════════════════════════════════════════════

    function test_updateUpdater() public {
        address newUpdater = makeAddr("newUpdater");

        vm.startPrank(owner);
        vm.expectEmit(true, true, false, false);
        emit CirculatingSupply.UpdaterChanged(updater, newUpdater);
        cirSupply.updateUpdater(newUpdater);
        vm.stopPrank();

        assertEq(cirSupply.updater(), newUpdater);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                       updateUpdater - Revert
    // ═══════════════════════════════════════════════════════════════════════

    function test_updateUpdater_onlyOwner() public {
        vm.startPrank(makeAddr("user"));
        vm.expectRevert();
        cirSupply.updateUpdater(makeAddr("newUpdater"));
        vm.stopPrank();
    }

    function test_updateUpdater_invalidUpdater() public {
        vm.startPrank(owner);
        vm.expectRevert(CirculatingSupply_InvalidUpdater.selector);
        cirSupply.updateUpdater(address(0));
        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                       getSupply
    // ═══════════════════════════════════════════════════════════════════════
    function test_getSupply() public updateBatch {
        uint256 ethSupply = cirSupply.getSupply((symbols[0]));
        assertEq(supply[0], ethSupply);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                       getSupply -- Revert
    // ═══════════════════════════════════════════════════════════════════════
    function test_getSupply_circulatingSupply_notAvailable() public updateBatch {
        string memory newSymbol = "BLOK";
        vm.expectRevert(abi.encodeWithSelector(CirculatingSupply_SupplyNotAvailable.selector, newSymbol));
        uint256 ethSupply = cirSupply.getSupply(newSymbol);
    }

    function test_getSupply_circulatingSupply_stale_data() public updateBatch {
        vm.warp(block.timestamp + 2 days);
        uint256 lastUpdatedAt = cirSupply.getLastUpdated((symbols[0]));
        vm.expectRevert(
            abi.encodeWithSelector(
                CirculatingSupply_StaleSupplyData.selector, symbols[0], lastUpdatedAt, block.timestamp
            )
        );
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                       getRawSupply
    // ═══════════════════════════════════════════════════════════════════════

    function test_getRawSupply() public updateBatch {
        assertEq(cirSupply.getRawSupply(symbols[0]), supply[0]);
        assertEq(cirSupply.getRawSupply(symbols[1]), supply[1]);
    }

    function test_getRawSupply_unknownSymbol() public {
        assertEq(cirSupply.getRawSupply("BLOK"), 0);
    }

    function test_getRawSupply_staleData() public updateBatch {
        vm.warp(block.timestamp + 2 days);
        assertEq(cirSupply.getRawSupply(symbols[0]), supply[0]);
    }
}

