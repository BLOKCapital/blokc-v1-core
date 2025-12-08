// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { UtilityFacetsTestBase } from "../UtilityFacetsTestBase.sol";
import { IAaveV3 } from "src/diamond/facets/utilityFacets/arbitrumOne/aaveV3/IAaveV3.sol";
import {
    AaveV3Base,
    AaveV3Facet_InsufficientBalance
} from "src/diamond/facets/utilityFacets/arbitrumOne/aaveV3/AaveV3Base.sol";
import { AaveV3Facet } from "src/diamond/facets/utilityFacets/arbitrumOne/aaveV3/AaveV3Facet.sol";

/// @title AaveV3Facet Edge Cases Tests
/// @notice Tests edge cases and boundary conditions
contract AaveV3FacetEdgeCasesTest is UtilityFacetsTestBase {
    function setUp() public override {
        super.setUp();
        _addUtilityFacetsToDiamond();
    }

    function test_EdgeCase_MinimumLendAmount() public {
        _mintTokensToDiamond(address(tokenA), 1);

        vm.prank(owner);
        vm.expectRevert();
        getAaveV3Facet().lend(address(tokenA), 1); // Minimum amount
    }

    function test_EdgeCase_MaximumLendAmount() public {
        uint256 maxAmount = type(uint256).max;
        _mintTokensToDiamond(address(tokenA), maxAmount);

        vm.prank(owner);
        vm.expectRevert();
        getAaveV3Facet().lend(address(tokenA), maxAmount);
    }

    function test_EdgeCase_ExactBalanceLend() public {
        uint256 balance = 1000;
        _mintTokensToDiamond(address(tokenA), balance);

        vm.prank(owner);
        vm.expectRevert();
        getAaveV3Facet().lend(address(tokenA), balance); // Exact balance
    }

    function test_EdgeCase_MinimumWithdrawAmount() public {
        vm.prank(owner);
        vm.expectRevert();
        getAaveV3Facet().withdraw(address(tokenA), 1); // Minimum amount
    }

    function test_EdgeCase_WithdrawMoreThanBalance() public {
        // Try to withdraw more than available
        vm.prank(owner);
        vm.expectRevert();
        getAaveV3Facet().withdraw(address(tokenA), type(uint256).max);
    }
}
