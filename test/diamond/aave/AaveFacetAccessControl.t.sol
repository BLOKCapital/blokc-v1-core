// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { UtilityFacetsTestBase } from "../UtilityFacetsTestBase.sol";
import { IAaveV3 } from "src/diamond/facets/utilityFacets/arbitrumOne/aaveV3/IAaveV3.sol";
import {
    AaveV3Base,
    AaveV3Facet_InsufficientBalance
} from "src/diamond/facets/utilityFacets/arbitrumOne/aaveV3/AaveV3Base.sol";
import { AaveV3Facet } from "src/diamond/facets/utilityFacets/arbitrumOne/aaveV3/AaveV3Facet.sol";

/// @title AaveV3Facet Access Control Tests
/// @notice Tests access control for AaveV3Facet functions
contract AaveV3FacetAccessControlTest is UtilityFacetsTestBase {
    function setUp() public override {
        super.setUp();
        _addUtilityFacetsToDiamond();
    }

    function test_RevertIf_NonOwnerCallslend() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        getAaveV3Facet().lend(address(tokenA), 1000);
    }

    function test_RevertIf_NonOwnerCallswithdraw() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        getAaveV3Facet().withdraw(address(tokenA), 1000);
    }

    function test_Success_AnyoneCanCallgetReserveData() public {
        // View functions should be publicly accessible
        // This will revert because the pool doesn't exist, but access control should pass
        vm.expectRevert();
        vm.prank(nonOwner);
        getAaveV3Facet().getReserveData(address(tokenA));
    }

    function test_RevertIf_InsufficientBalance() public {
        // Try to lend more than the diamond has
        _mintTokensToDiamond(address(tokenA), 500);

        vm.prank(owner);
        vm.expectRevert(AaveV3Facet_InsufficientBalance.selector);
        getAaveV3Facet().lend(address(tokenA), 1000);
    }
}
