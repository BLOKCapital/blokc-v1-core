// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/// @title ICCTPTokenMessenger
/// @notice Minimal subset of the Circle CCTP TokenMessenger interface used by the CctpFacet.
interface ICCTP {
    /// @notice Emitted when a transfer is initiated to another chain
    event DepositForBurn(address indexed from, address indexed to, uint64 indexed destinationDomain, uint256 amount);

    /// @notice Initiates a burn of tokens and produces a message that can be redeemed on the destination chain
    /// @param amount The amount of tokens to burn
    /// @param destinationDomain The Circle domain id of the destination chain
    /// @param mintRecipient The recipient address on the destination chain (encoded as bytes32)
    function sendUSDC(uint256 amount, uint32 destinationDomain, bytes32 mintRecipient) external;

    /// @notice Redeems a message on this chain produced by a burn on the source chain
    /// @param message The message bytes produced by the source chain's TokenMessenger
    /// @param attestation The attestation bytes produced by the Circle network
    function redeemUSDC(bytes calldata message, bytes calldata attestation) external;
}

interface ITokenMessengerV2 {
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

interface IMessageTransmitterV2 {
    function receiveMessage(bytes calldata message, bytes calldata attestation) external;
}
