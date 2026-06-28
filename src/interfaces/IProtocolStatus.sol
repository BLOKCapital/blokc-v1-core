// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

/**
 * @title IProtocolStatus
 * @notice Interface for managing protocol-level state.
 * @dev All state transitions are owner-only. ENS-based Security Council Member
 *      governance was removed — may be reintroduced with an L2-compatible mechanism.
 */
interface IProtocolStatus {
    /**
     * @notice Represents the overall protocol status.
     * @dev
     * ACTIVE — Protocol fully operational
     * UPGRADES_DISABLED — Protocol active but upgrades permanently disabled
     * INACTIVE — Protocol paused / shut down
     */
    enum State {
        ACTIVE,
        UPGRADES_DISABLED,
        INACTIVE
    }

    // =============================================================
    //                       PROTOCOL STATE MGMT
    // =============================================================

    /**
     * @notice Activates the protocol.
     */
    function activateProtocol() external;

    /**
     * @notice Deactivates the protocol (pauses operations).
     */
    function deactivateProtocol() external;

    /**
     * @notice Permanently disables upgrades.
     * @dev This action is typically irreversible.
     */
    function disableUpgrades() external;

    // =============================================================
    //                              VIEWS
    // =============================================================

    /**
     * @notice Returns the current protocol state.
     */
    function getProtocolStatus() external view returns (State);
}
