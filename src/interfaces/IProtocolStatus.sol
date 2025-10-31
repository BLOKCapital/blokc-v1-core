// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/*###############################################################################

    @title IProtocolStatus
    @author BLOK Capital DAO
    @notice Interface for the Protocol Status
    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

interface IProtocolStatus {
    /**
     * @notice Enum representing the protocol states
     * @dev ACTIVE: Protocol is fully operational
     * @dev UPGRADES_DISABLED: Protocol is operational but upgrades are disabled
     * @dev INACTIVE: Protocol is shut down
     */
    enum State {
        ACTIVE,
        UPGRADES_DISABLED,
        INACTIVE
    }

    /**
     * @notice Struct representing a Security Council member
     * @param memberAddress The address of the Security Council member
     * @param name The name of the Security Council member
     */
    struct SecurityCouncilMember {
        address memberAddress;
        string name;
    }

    /**
     * @notice Adds a new member to the Security Council
     * @param  member The Security Council member to add
     * @dev Can only be called by the DAO
     */
    function addSecurityCouncilMember(SecurityCouncilMember memory member) external;

    /**
     * @notice Removes a member from the Security Council
     * @param member The address of the Security Council member to remove
     * @dev Can only be called by the DAO
     */
    function removeSecurityCouncilMember(SecurityCouncilMember memory member) external;

    /**
     * @notice Activates the protocol
     * @dev Sets the protocol status to ACTIVE
     * @dev Can only be called by the DAO
     */
    function activateProtocol() external;

    /**
     * @notice Deactivates the protocol
     * @dev Sets the protocol status to INACTIVE
     * @dev Can only be called by the DAO or Security Council
     */
    function deactivateProtocol() external;

    /**
     * @notice Disables protocol upgrades
     * @dev Sets the protocol status to UPGRADES_DISABLED
     * @dev Can only be called by the DAO or Security Council when the protocol is ACTIVE
     */
    function disableUpgrades() external;

    /**
     * @notice Returns the list of Security Council members
     */
    function getSecurityCouncilMembers() external view returns (SecurityCouncilMember[] memory);

    /**
     * @notice Returns the current protocol status
     * @return The current protocol status as a State enum value
     */
    function getProtocolStatus() external view returns (State);

    /**
     * @notice Checks if an address is a Security Council member
     * @param member The address to check
     */
    function isSecurityCouncilMember(address member) external view returns (bool);

    /**
     * @notice Returns the name of a security council member
     * @param member The address of the member
     * @return The name of the member
     */
    function getMemberName(address member) external view returns (string memory);
}
