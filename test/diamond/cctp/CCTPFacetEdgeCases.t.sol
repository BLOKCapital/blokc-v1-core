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

/// @title CCTPFacet Edge Cases Tests
/// @notice Tests edge cases and boundary conditions
contract CCTPFacetEdgeCasesTest is UtilityFacetsTestBase {
    function setUp() public override {
        super.setUp();
        _addUtilityFacetsToDiamond();
    }

    function test_EdgeCase_MinimumSendAmount() public {
        _mintTokensToUser(address(usdc), owner, 1);

        vm.prank(owner);
        vm.expectRevert(CCTPFacet_ZeroAmount.selector);
        getCCTPFacet().sendUSDC(0, 1, bytes32(uint256(1)));
    }

    function test_EdgeCase_MaximumSendAmount() public {
        uint256 maxAmount = type(uint256).max;
        _mintTokensToUser(address(usdc), owner, maxAmount);

        vm.prank(owner);
        vm.expectRevert();
        getCCTPFacet().sendUSDC(maxAmount, 1, bytes32(uint256(1)));
    }

    function test_EdgeCase_ZeroDestinationDomain() public {
        _mintTokensToUser(address(usdc), owner, 1000);

        vm.prank(owner);
        vm.expectRevert();
        getCCTPFacet().sendUSDC(1000, 0, bytes32(uint256(1)));
    }

    function test_EdgeCase_MaxDestinationDomain() public {
        _mintTokensToUser(address(usdc), owner, 1000);

        vm.prank(owner);
        vm.expectRevert();
        getCCTPFacet().sendUSDC(1000, type(uint32).max, bytes32(uint256(1)));
    }

    function test_EdgeCase_ZeroMintRecipient() public {
        _mintTokensToUser(address(usdc), owner, 1000);

        vm.prank(owner);
        vm.expectRevert();
        getCCTPFacet().sendUSDC(1000, 1, bytes32(0));
    }

    function test_EdgeCase_MaxMintRecipient() public {
        _mintTokensToUser(address(usdc), owner, 1000);

        vm.prank(owner);
        vm.expectRevert();
        getCCTPFacet().sendUSDC(1000, 1, bytes32(type(uint256).max));
    }

    function test_EdgeCase_EmptyMessage() public {
        vm.prank(owner);
        vm.expectRevert(CCTPFacet_InvalidMessage.selector);
        getCCTPFacet().redeemUSDC("", "attestation");
    }

    function test_EdgeCase_EmptyAttestation() public {
        vm.prank(owner);
        vm.expectRevert(CCTPFacet_InvalidAttestation.selector);
        getCCTPFacet().redeemUSDC("message", "");
    }

    function test_EdgeCase_VeryLongMessage() public {
        bytes memory longMessage = new bytes(10_000);
        bytes memory attestation = "attestation";

        vm.prank(owner);
        vm.expectRevert();
        getCCTPFacet().redeemUSDC(longMessage, attestation);
    }

    function test_EdgeCase_VeryLongAttestation() public {
        bytes memory message = "message";
        bytes memory longAttestation = new bytes(10_000);

        vm.prank(owner);
        vm.expectRevert();
        getCCTPFacet().redeemUSDC(message, longAttestation);
    }
}
