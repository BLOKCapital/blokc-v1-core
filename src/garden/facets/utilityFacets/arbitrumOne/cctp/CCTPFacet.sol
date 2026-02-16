// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    @title CCTPFacet
    @author BLOK Capital DAO
    @notice Facet exposing Circle Cross-Chain Transfer Protocol (CCTP) functions
    @dev This facet provides integration with Circle's CCTP for cross-chain USDC
         transfers. All operations are protected by owner-only access control.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import { CCTPBase } from "src/garden/facets/utilityFacets/arbitrumOne/cctp/CCTPBase.sol";
import { Facet } from "src/garden/facets/Facet.sol";

contract CCTPFacet is CCTPBase, Facet {
    // ========================================================================
    // External Functions
    // ========================================================================

    /// @notice Sends (burns) native USDC and instructs Circle to mint on destination chain
    /// @param amount USDC amount to send (usually 6 decimals)
    /// @param destinationDomain Circle domain ID of the destination chain
    /// @param mintRecipient Bytes32-encoded recipient address on destination chain
    function sendUsdc(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient
    )
        external
        onlyGardenOwner
        nonReentrant
        ifIndexNotConnected
    {
        _sendUsdc(amount, destinationDomain, mintRecipient);
    }

    /// @notice Redeems (mints) USDC from another chain using Circle attestation
    /// @param message Raw message bytes from Circle attestation flow
    /// @param attestation Attestation bytes from Circle network
    function redeemUsdc(
        bytes calldata message,
        bytes calldata attestation
    )
        external
        onlyGardenOwner
        nonReentrant
        ifIndexNotConnected
    {
        _redeemUsdc(message, attestation);
    }
}
