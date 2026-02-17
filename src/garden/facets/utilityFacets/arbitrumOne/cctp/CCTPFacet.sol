// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { CCTPBase } from "src/garden/facets/utilityFacets/arbitrumOne/cctp/CCTPBase.sol";
import { Facet } from "src/garden/facets/Facet.sol";

import { ICCTP } from "src/garden/facets/utilityFacets/arbitrumOne/cctp/ICCTP.sol";

/**
 * @title CCTPFacet
 * @author BLOK Capital DAO
 * @notice Facet that implements the ICCTP interface to allow sending and redeeming USDC through the Circle Cross-Chain
 * Transfer Protocol (CCTP) on Arbitrum One. This facet provides external functions for garden owners to send USDC to
 * other chains and redeem USDC received from other chains, with appropriate access control and user-facing error
 * messages. It inherits from CCTPBase which contains the internal logic for interacting with CCTP, while CCTPFacet
 * itself provides the external interface for these operations.
 */
contract CCTPFacet is ICCTP, CCTPBase, Facet {
    /// @inheritdoc ICCTP
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

    /// @inheritdoc ICCTP
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
