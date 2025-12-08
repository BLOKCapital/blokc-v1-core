// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { UtilityFacetsTestBase } from "../UtilityFacetsTestBase.sol";
import { IAaveV3 } from "src/diamond/facets/utilityFacets/arbitrumOne/aaveV3/IAaveV3.sol";
import {
    AaveV3Base,
    AaveV3Facet_InvalidATokenAddress,
    AaveV3Facet_InsufficientATokenBalance,
    AaveV3Facet_InsufficientBalance
} from "src/diamond/facets/utilityFacets/arbitrumOne/aaveV3/AaveV3Base.sol";
import { AaveV3Facet } from "src/diamond/facets/utilityFacets/arbitrumOne/aaveV3/AaveV3Facet.sol";

/// @title AaveV3Facet Error Tests
/// @notice Tests error conditions for AaveV3Facet functions
contract AaveV3FacetErrorsTest is UtilityFacetsTestBase {
    function setUp() public override {
        super.setUp();
        _addUtilityFacetsToDiamond();
    }

    function test_RevertIf_InsufficientBalance() public {
        _mintTokensToDiamond(address(tokenA), 500);

        vm.prank(owner);
        vm.expectRevert(AaveV3Facet_InsufficientBalance.selector);
        getAaveV3Facet().lend(address(tokenA), 1000);
    }
}
