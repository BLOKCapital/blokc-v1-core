// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { UtilityFacetsTestBase } from "../UtilityFacetsTestBase.sol";
import { ICCTP } from "src/diamond/facets/utilityFacets/arbitrumOne/cctp/ICCTP.sol";
import {
    CCTPBase,
    CCTPFacet_ZeroAmount,
    CCTPFacet_InvalidMessage,
    CCTPFacet_InvalidAttestation,
    CCTPFacet_NoUSDCMinted,
    CCTPFacet_InsufficientBalance,
    CCTPFacet_TransferFailed
} from "src/diamond/facets/utilityFacets/arbitrumOne/cctp/CCTPBase.sol";
import { CCTPFacet } from "src/diamond/facets/utilityFacets/arbitrumOne/cctp/CCTPFacet.sol";

/// @title CCTPFacet Access Control Tests
/// @notice Tests access control for CCTPFacet functions
contract CCTPFacetAccessControlTest is UtilityFacetsTestBase {
    function setUp() public override {
        super.setUp();
        _addUtilityFacetsToDiamond();
    }

    function test_RevertIf_NonOwnerCallsSendUSDC() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        getCCTPFacet().sendUSDC(1000, 1, bytes32(uint256(1)));
    }

    function test_RevertIf_NonOwnerCallsRedeemUSDC() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        getCCTPFacet().redeemUSDC("message", "attestation");
    }

    function test_RevertIf_ZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert(CCTPFacet_ZeroAmount.selector);
        getCCTPFacet().sendUSDC(0, 1, bytes32(uint256(1)));
    }

    function test_RevertIf_InvalidMessage() public {
        vm.prank(owner);
        vm.expectRevert(CCTPFacet_InvalidMessage.selector);
        getCCTPFacet().redeemUSDC("", "attestation");
    }

    function test_RevertIf_InvalidAttestation() public {
        vm.prank(owner);
        vm.expectRevert(CCTPFacet_InvalidAttestation.selector);
        getCCTPFacet().redeemUSDC("message", "");
    }
}
