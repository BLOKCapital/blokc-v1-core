// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { UtilityFacetsTestBase } from "../UtilityFacetsTestBase.sol";
import { IWithdraw } from "src/diamond/facets/utilityFacets/arbitrumOne/withdraw/IWithdraw.sol";
import { WithdrawFacet } from "src/diamond/facets/utilityFacets/arbitrumOne/withdraw/WithdrawFacet.sol";
import {
    WithdrawBase,
    WithdrawFacet_WithdrawZeroAmount
} from "src/diamond/facets/utilityFacets/arbitrumOne/withdraw/WithdrawBase.sol";

/// @title WithdrawFacet Access Control Tests
/// @notice Tests access control for WithdrawFacet functions
contract WithdrawFacetAccessControlTest is UtilityFacetsTestBase {
    function setUp() public override {
        super.setUp();
        _addUtilityFacetsToDiamond();
    }

    function test_RevertIf_NonOwnerCallsWithdrawUSDC() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        getWithdrawFacet().withdrawUSDC(1000);
    }

    function test_RevertIf_WithdrawZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert(WithdrawFacet_WithdrawZeroAmount.selector);
        getWithdrawFacet().withdrawUSDC(0);
    }

    function test_RevertIf_InsufficientUSDCBalance() public {
        _mintTokensToDiamond(address(usdc), 500);

        vm.prank(owner);
        vm.expectRevert();
        getWithdrawFacet().withdrawUSDC(1000);
    }
}
