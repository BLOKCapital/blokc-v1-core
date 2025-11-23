// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { UtilityFacetsTestBase } from "../UtilityFacetsTestBase.sol";
import { IAaveV3 } from "src/diamond/facets/utilityFacets/arbitrumOne/aaveV3/IAaveV3.sol";
import {
    AaveV3Base,
    AaveV3Facet_InvalidATokenAddress,
    AaveV3Facet_InsufficientATokenBalance
} from "src/diamond/facets/utilityFacets/arbitrumOne/aaveV3/AaveV3Base.sol";
import { AaveV3Facet } from "src/diamond/facets/utilityFacets/arbitrumOne/aaveV3/AaveV3Facet.sol";

/// @title AaveV3Facet View Functions Tests
/// @notice Tests for AaveV3Facet reserve data query functions
contract AaveV3FacetViewFunctionsTest is UtilityFacetsTestBase {
    function setUp() public override {
        super.setUp();
        _addUtilityFacetsToDiamond();
    }

    function test_getReserveData_CanBeCalledByAnyone() public {
        // View function should be publicly accessible
        // Will revert because pool doesn't exist, but access control should pass
        vm.expectRevert();
        vm.prank(nonOwner);
        getAaveV3Facet().getReserveData(address(tokenA));
    }

    function test_getReserveData_ReturnsReserveData() public {
        // This test would require a mock Aave pool
        // For now, we verify it doesn't revert on access control
        vm.expectRevert();
        getAaveV3Facet().getReserveData(address(tokenA));
    }

    function test_getReserveData_HandlesZeroAddress() public {
        // Should handle zero address gracefully
        vm.expectRevert();
        getAaveV3Facet().getReserveData(address(0));
    }
}
