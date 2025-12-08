// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { UtilityFacetsTestBase } from "../UtilityFacetsTestBase.sol";
import { IWithdraw } from "src/diamond/facets/utilityFacets/arbitrumOne/withdraw/IWithdraw.sol";
import { WithdrawFacet } from "src/diamond/facets/utilityFacets/arbitrumOne/withdraw/WithdrawFacet.sol";
import {
    WithdrawBase,
    WithdrawFacet_WithdrawZeroAmount,
    WithdrawFacet_InsufficientUSDCBalance
} from "src/diamond/facets/utilityFacets/arbitrumOne/withdraw/WithdrawBase.sol";

/// @title WithdrawFacet Error Tests
/// @notice Tests error conditions for WithdrawFacet functions
contract WithdrawFacetErrorsTest is UtilityFacetsTestBase {
    function setUp() public override {
        super.setUp();
        _addUtilityFacetsToDiamond();
    }

    function test_RevertIf_WithdrawZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert(WithdrawFacet_WithdrawZeroAmount.selector);
        getWithdrawFacet().withdrawUSDC(0);
    }

    function test_RevertIf_InsufficientUSDCBalance() public {
        _mintTokensToDiamond(address(usdc), 500);

        vm.prank(owner);
        vm.expectRevert(WithdrawFacet_InsufficientUSDCBalance.selector);
        getWithdrawFacet().withdrawUSDC(1000);
    }
}
