// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

/**
 * @title IProtocolStatus
 * @notice Interface for managing protocol-level state and Security Council Members (SCMs) via ENS.
 * @dev Handles membership, ENS resolution tracking, upgrade locks, and protocol activation state.
 */
interface IProtocolStatus {
    // =============================================================
    //                           ENUMS
    // =============================================================

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

    /**
     * @notice Represents the current status of a Security Council Member.
     * @dev
     * ACTIVE — Current ENS-resolved address is valid
     * EXPIRED — Membership expired based on timestamp
     * ADDRESS_CHANGED — ENS resolved address changed since last update
     */
    enum SCMStatus {
        ACTIVE,
        EXPIRED,
        ADDRESS_CHANGED
    }

    // =============================================================
    //                           STRUCTS
    // =============================================================

    /**
     * @notice Stores data for Security Council Members tracked via ENS.
     * @param namehash ENS namehash of the SCM domain.
     * @param ensName Human-readable ENS name (e.g., "alice.eth").
     * @param resolvedAddress The latest ENS-resolved address for the SCM.
     * @param previousAddress The previously resolved address (before change).
     * @param expiryTimestamp Timestamp after which membership is considered expired.
     * @param status Current SCM status (active, expired, address changed).
     */
    struct ENSMember {
        bytes32 namehash;
        string ensName;
        address resolvedAddress;
        address previousAddress;
        uint256 expiryTimestamp;
        SCMStatus status;
    }

    // =============================================================
    //                            EVENTS
    // =============================================================

    /**
     * @notice Emitted when an SCM's ENS-resolved address changes.
     * @param namehash ENS namehash of the SCM.
     * @param ensName Human-readable ENS name.
     * @param oldAddress Previously resolved address.
     * @param newAddress Newly resolved address.
     * @param timestamp Block timestamp of the update.
     */
    event SCMAddressChanged(
        bytes32 indexed namehash, string ensName, address oldAddress, address newAddress, uint256 timestamp
    );

    /**
     * @notice Logs any action performed by or related to a Security Council Member.
     * @param scm The SCM address involved.
     * @param action Description of the action (ex: "Added", "Removed", "ExtendedExpiry").
     */
    event SCMAction(address indexed scm, string action);

    /**
     * @notice Emitted when an unauthorized caller attempts a restricted action.
     * @param caller Address that attempted the action.
     * @param attemptedAction Description of the attempted operation.
     */
    event SCMUnauthorizedAttempt(address indexed caller, string attemptedAction);

    // =============================================================
    //                         MEMBERSHIP MGMT
    // =============================================================

    /**
     * @notice Adds a new Security Council Member using ENS data.
     * @param namehash ENS namehash of the SCM (e.g., namehash of "alice.eth").
     * @param ensName Human-readable ENS name.
     * @param expiryTimestamp Timestamp after which SCM is considered expired.
     */
    function addSecurityCouncilMemberByENS(
        bytes32 namehash,
        string calldata ensName,
        uint256 expiryTimestamp
    )
        external;

    /**
     * @notice Removes a Security Council Member by ENS namehash.
     * @param namehash ENS namehash of the SCM.
     */
    function removeSecurityCouncilMemberByENS(bytes32 namehash) external;

    /**
     * @notice Extends the expiry time of an existing SCM.
     * @param namehash ENS namehash of the SCM.
     * @param newExpiry New expiry timestamp.
     */
    function extendSCMExpiry(bytes32 namehash, uint256 newExpiry) external;

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
     * @notice Returns all registered SCMs.
     */
    function getSecurityCouncilMembers() external view returns (ENSMember[] memory);

    /**
     * @notice Returns the current protocol state.
     */
    function getProtocolStatus() external view returns (State);

    /**
     * @notice Checks if an address is a Security Council Member.
     * @param member Address to check.
     * @return True if the address is currently an active SCM.
     */
    function isSecurityCouncilMember(address member) external view returns (bool);

    /**
     * @notice Returns the ENS name associated with an SCM address.
     * @param member SCM resolved address.
     */
    function getMemberName(address member) external view returns (string memory);

    /**
     * @notice Returns the current ENS-resolved address for a namehash.
     * @param namehash ENS namehash.
     */
    function getResolvedAddress(bytes32 namehash) external view returns (address);

    /**
     * @notice Returns the previous ENS-resolved address for a namehash.
     * @param namehash ENS namehash.
     */
    function getPreviousResolvedAddress(bytes32 namehash) external view returns (address);

    /**
     * @notice Returns the current SCM status (active / expired / changed).
     * @param namehash ENS namehash.
     */
    function getSCMStatus(bytes32 namehash) external view returns (SCMStatus);

    /**
     * @notice Returns the expiry timestamp for an SCM.
     * @param namehash ENS namehash.
     */
    function getExpiryTimestamp(bytes32 namehash) external view returns (uint256);

    /**
     * @notice Returns the ENS name for an SCM.
     * @param namehash ENS namehash.
     */
    function getENSName(bytes32 namehash) external view returns (string memory);
}
