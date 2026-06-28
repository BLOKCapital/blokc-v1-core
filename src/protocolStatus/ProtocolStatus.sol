// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    @title ProtocolStatus
    @author BLOK Capital DAO
    @notice Manages protocol-level state (active / upgrades-disabled / inactive).
            All state transitions are owner-only.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title ProtocolStatus
/// @author BLOK Capital DAO
/// @notice Manages protocol-level state (active / upgrades-disabled / inactive).
///         All state transitions are owner-only.
/// @dev Previously included ENS-based Security Council Member (SCM) governance,
///      which was removed because it only worked on Ethereum mainnet and the
///      protocol deploys to Arbitrum. The SCM system may be reintroduced with
///      an L2-compatible governance mechanism in the future.
contract ProtocolStatus is IProtocolStatus, Ownable {
    // ------------------------------------------------------------------------
    // STORAGE
    // ------------------------------------------------------------------------

    /// @dev Current protocol state (ACTIVE, UPGRADES_DISABLED, or INACTIVE).
    State private _protocolStatus;

    // ------------------------------------------------------------------------
    // ERRORS
    // ------------------------------------------------------------------------
    /// @notice Thrown when attempting to activate an already-active protocol.
    error ProtocolStatus_ProtocolIsAlreadyActive();

    /// @notice Thrown when attempting to deactivate an already-inactive protocol.
    error ProtocolStatus_ProtocolIsAlreadyInactive();

    /// @notice Thrown when a required address argument is the zero address.
    error ProtocolStatus_ZeroAddress();

    /// @notice Thrown when attempting to disable upgrades while the protocol is not active.
    error ProtocolStatus_MustBeActiveToDisableUpgrades();

    // ------------------------------------------------------------------------
    // EVENTS
    // ------------------------------------------------------------------------
    /// @notice Emitted when the protocol state transitions.
    /// @param oldStatus The previous protocol state.
    /// @param newStatus The new protocol state.
    /// @param changedBy The address that triggered the change.
    event ProtocolStatusChanged(State indexed oldStatus, State indexed newStatus, address indexed changedBy);

    // ------------------------------------------------------------------------
    // CONSTRUCTOR
    // ------------------------------------------------------------------------
    /// @notice Initializes the protocol in ACTIVE state.
    /// @param initialOwner The address that will own this contract.
    constructor(address initialOwner) Ownable(initialOwner) {
        if (initialOwner == address(0)) revert ProtocolStatus_ZeroAddress();
        _protocolStatus = State.ACTIVE;
        emit ProtocolStatusChanged(State.INACTIVE, State.ACTIVE, msg.sender);
    }

    // ------------------------------------------------------------------------
    // PROTOCOL MANAGEMENT (owner-only)
    // ------------------------------------------------------------------------
    /// @inheritdoc IProtocolStatus
    function activateProtocol() external override onlyOwner {
        State currentStatus = _protocolStatus;
        if (currentStatus == State.ACTIVE) revert ProtocolStatus_ProtocolIsAlreadyActive();
        _protocolStatus = State.ACTIVE;
        emit ProtocolStatusChanged(currentStatus, State.ACTIVE, msg.sender);
    }

    /// @inheritdoc IProtocolStatus
    function deactivateProtocol() external override onlyOwner {
        State currentStatus = _protocolStatus;
        if (currentStatus == State.INACTIVE) revert ProtocolStatus_ProtocolIsAlreadyInactive();
        _protocolStatus = State.INACTIVE;
        emit ProtocolStatusChanged(currentStatus, State.INACTIVE, msg.sender);
    }

    /// @inheritdoc IProtocolStatus
    function disableUpgrades() external override onlyOwner {
        State currentStatus = _protocolStatus;
        if (currentStatus != State.ACTIVE) revert ProtocolStatus_MustBeActiveToDisableUpgrades();
        _protocolStatus = State.UPGRADES_DISABLED;
        emit ProtocolStatusChanged(currentStatus, State.UPGRADES_DISABLED, msg.sender);
    }

    // ------------------------------------------------------------------------
    // VIEWS
    // ------------------------------------------------------------------------
    /// @inheritdoc IProtocolStatus
    function getProtocolStatus() external view override returns (State) {
        return _protocolStatus;
    }
}
