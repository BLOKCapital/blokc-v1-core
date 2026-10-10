// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/// @notice Audit record for the current Treasury
/// @param treasuryAddress The single USDC receiver
/// @param updatedAtBlock Block number of the latest change
/// @param updatedAtTimestamp Timestamp of the latest change
/// @param updatedBy The owner key that executed the change
/// @param proposalRef Owner-supplied audit reference (e.g. DAO proposal hash)
struct TreasuryInfo {
    address treasuryAddress;
    uint256 updatedAtBlock;
    uint256 updatedAtTimestamp;
    address updatedBy;
    bytes32 proposalRef;
}

/// @notice The DAO-voted single USDC receiver for protocol and DAO-share performance fees.
interface ITreasuryRegistry {
    /// @notice Returns the current Treasury address (revert-free; may be address(0) only if
    ///         never set — gardens must treat that as "unsettleable" and revert settlement).
    function getTreasuryAddress() external view returns (address);

    /// @notice Returns the full Treasury record including audit fields.
    function getTreasuryInfo() external view returns (TreasuryInfo memory);
}
