// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title ICCTP
    @author BLOK Capital DAO
    @notice Interface for Circle Cross-Chain Transfer Protocol (CCTP) integration
    @dev This interface provides functions for sending and receiving USDC across
         chains using Circle's CCTP protocol.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

// ============================================================================
// ICCTP
// ============================================================================

/// @title ICCTP
/// @notice Interface for Circle Cross-Chain Transfer Protocol integration
/// @dev This interface provides functions for cross-chain USDC transfers using
///      Circle's CCTP. All operations are restricted to the diamond owner.
///      Note: Events are declared in the implementation contract, not in the interface,
///      following Solidity best practices.
interface ICCTP {
    // ========================================================================
    // Functions
    // ========================================================================

    /// @notice Initiates a burn of USDC tokens and produces a message for the destination chain
    /// @param amount The amount of USDC to send (usually 6 decimals)
    /// @param destinationDomain The Circle domain ID of the destination chain
    /// @param mintRecipient The recipient address on the destination chain (encoded as bytes32)
    function sendUSDC(uint256 amount, uint32 destinationDomain, bytes32 mintRecipient) external;

    /// @notice Redeems (mints) USDC from another chain using Circle attestation
    /// @param message Raw message bytes from Circle attestation flow
    /// @param attestation Attestation bytes from Circle network
    function redeemUSDC(bytes calldata message, bytes calldata attestation) external;
}

// ============================================================================
// Circle CCTP Interfaces
// ============================================================================

/// @title ITokenMessengerV2
/// @notice Interface for Circle's TokenMessengerV2 contract
/// @dev This interface exposes the depositForBurn function used to initiate
///      cross-chain transfers by burning tokens on the source chain.
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
/// @notice Interface for Circle's MessageTransmitterV2 contract
/// @dev This interface exposes the receiveMessage function used to redeem
///      messages from source chains and mint tokens on the destination chain.
interface IMessageTransmitterV2 {
    /// @notice Receives a message and attestation, verifies authenticity, and routes to TokenMinter
    /// @param message Raw message bytes from Circle attestation flow
    /// @param attestation Attestation bytes from Circle network
    function receiveMessage(bytes calldata message, bytes calldata attestation) external;
}
