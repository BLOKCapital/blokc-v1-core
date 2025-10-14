// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/// @title ICCTPTokenMessenger
/// @notice Minimal subset of the Circle CCTP TokenMessenger interface used by the CctpFacet.
interface ICCTPTokenMessenger {
    /// @notice Emitted when a transfer is initiated to another chain
    event DepositForBurn(address indexed from, address indexed to, uint64 indexed destinationDomain, uint256 amount);

    /// @notice Initiates a burn of tokens and produces a message that can be redeemed on the destination chain
    /// @param amount The amount of tokens to burn
    /// @param recipient The recipient address on the destination chain (encoded as bytes32)
    /// @param destinationDomain The Circle domain id of the destination chain
    /// @return messageFee The fee paid for the message (if applicable)
    function depositForBurn(
        uint256 amount,
        bytes32 recipient,
        uint32 destinationDomain
    )
        external
        returns (uint256 messageFee);

    /// @notice Redeems a message on this chain produced by a burn on the source chain
    /// @param message The message bytes produced by the source chain's TokenMessenger
    function receiveMessage(bytes calldata message) external;
}
