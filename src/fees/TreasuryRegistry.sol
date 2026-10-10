// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▛▀▜▌▐▛▚▖     ▐▌   ▐▌ ▐▌▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ITreasuryRegistry, TreasuryInfo } from "../interfaces/ITreasuryRegistry.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when the zero address is passed as a Treasury (the spec requires fee
///         settlement to revert rather than send fees to address(0))
/// @param treasuryAddress The invalid address
error TreasuryRegistry_InvalidTreasuryAddress(address treasuryAddress);

/// @notice Thrown when renounceOwnership is called (disabled to prevent permanent lockout)
error TreasuryRegistry_CannotRenounceOwnership();

/**
 * @title TreasuryRegistry
 * @notice DAO-voted single USDC receiver for protocol fees and the DAO share of performance
 *         fees. The registry never stores address(0) — if it was never set, gardens must revert
 *         fee settlement rather than send fees to the zero address. The Treasury address is read
 *         LIVE at fee settlement so a compromised Treasury can be rotated by a single vote.
 */
contract TreasuryRegistry is ITreasuryRegistry, Ownable {
    TreasuryInfo private _info;

    event TreasuryAddressUpdated(
        address indexed oldTreasury, address indexed newTreasury, uint256 updatedAtBlock, bytes32 proposalRef
    );

    /// @notice Constructs the TreasuryRegistry (Treasury starts unset)
    /// @param initialOwner Address of the contract owner
    constructor(address initialOwner) Ownable(initialOwner) { }

    /// @notice Sets (or rotates) the Treasury address
    /// @param newTreasuryAddress The single USDC receiver for protocol/DAO-share fees
    /// @param proposalRef Owner-supplied audit reference (e.g. the DAO proposal hash)
    function setTreasuryAddress(address newTreasuryAddress, bytes32 proposalRef) external onlyOwner {
        if (newTreasuryAddress == address(0)) revert TreasuryRegistry_InvalidTreasuryAddress(newTreasuryAddress);
        address old = _info.treasuryAddress;
        _info = TreasuryInfo({
            treasuryAddress: newTreasuryAddress,
            updatedAtBlock: block.number,
            updatedAtTimestamp: block.timestamp,
            updatedBy: msg.sender,
            proposalRef: proposalRef
        });
        emit TreasuryAddressUpdated(old, newTreasuryAddress, block.number, proposalRef);
    }

    /// @notice Returns the current Treasury address (address(0) only if never set)
    function getTreasuryAddress() external view returns (address) {
        return _info.treasuryAddress;
    }

    /// @notice Returns the full Treasury record including audit fields
    function getTreasuryInfo() external view returns (TreasuryInfo memory) {
        return _info;
    }

    /// @notice Renounce ownership is disabled to prevent permanent lockout
    /// @inheritdoc Ownable
    function renounceOwnership() public pure override {
        revert TreasuryRegistry_CannotRenounceOwnership();
    }
}
