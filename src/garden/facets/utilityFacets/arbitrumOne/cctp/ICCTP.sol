// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

/// @title ICCTP
/// @author BLOK Capital DAO
/// @notice Interface for Circle Cross-Chain Transfer Protocol (CCTP) integration
interface ICCTP {
    /// @notice Initiates a burn of USDC tokens and produces a message for the destination chain
    /// @param amount The amount of USDC to send (usually 6 decimals)
    /// @param destinationDomain The Circle domain ID of the destination chain
    /// @param mintRecipient The recipient address on the destination chain (encoded as bytes32)
    function cctpSendUsdc(uint256 amount, uint32 destinationDomain, bytes32 mintRecipient) external;

    /// @notice Redeems (mints) USDC from another chain using Circle attestation
    /// @param message Raw message bytes from Circle attestation flow
    /// @param attestation Attestation bytes from Circle network
    function cctpRedeemUsdc(bytes calldata message, bytes calldata attestation) external;
}

/// @title ITokenMessengerV2
/// @author BLOK Capital DAO
/// @notice Interface for Circle's TokenMessengerV2 contract used to initiate cross-chain transfers
interface ITokenMessengerV2 {
    /// @notice Burns tokens and produces a message for the destination chain
    /// @param amount The amount of tokens to burn
    /// @param destinationDomain The Circle domain ID of the destination chain
    /// @param mintRecipient The recipient address on the destination chain (bytes32 encoded)
    /// @param burnToken The token address to burn
    /// @param destinationCaller Optional address that can call the destination
    /// @param maxFee Maximum fee to pay (0 = use default)
    /// @param minFinalityThreshold Minimum finality threshold (0 = use default)
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold
    )
        external;
}

/// @title IMessageTransmitterV2
/// @author BLOK Capital DAO
/// @notice Interface for Circle's MessageTransmitterV2 contract used to redeem cross-chain messages
interface IMessageTransmitterV2 {
    /// @notice Receives a message and attestation, verifies authenticity, and routes to TokenMinter
    /// @param message Raw message bytes from Circle attestation flow
    /// @param attestation Attestation bytes from Circle network
    function receiveMessage(bytes calldata message, bytes calldata attestation) external;
}
