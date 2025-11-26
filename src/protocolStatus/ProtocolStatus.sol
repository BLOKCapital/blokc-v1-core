// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/*###############################################################################

    @title ProtocolStatus
    @author BLOK Capital DAO
    @notice Exposes functionality to manage the protocol status.
    
    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract ProtocolStatus is IProtocolStatus, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev Current protocol status
    State private _protocolStatus;

    /// @dev Mapping of Security Council member addresses to their details
    mapping(address => SecurityCouncilMember) private _securityCouncilMembers;

    /// @dev Set of Security Council members
    EnumerableSet.AddressSet private _securityCouncilMemberAddresses;

    // ============================================================================
    // Errors
    // ============================================================================

    /// @notice Thrown when the protocol is already active
    error ProtocolStatus_ProtocolIsAlreadyActive();
    /// @notice Thrown when the protocol is already inactive
    error ProtocolStatus_ProtocolIsAlreadyInactive();
    /// @notice Thrown when the address is zero
    error ProtocolStatus_ZeroAddress();
    /// @notice Thrown when the array is empty
    error ProtocolStatus_EmptyArray();
    /// @notice Thrown when the member already exists
    error ProtocolStatus_MemberAlreadyExists(address member, string name);
    /// @notice Thrown when the member does not exist
    error ProtocolStatus_MemberDoesNotExist(address member, string name);
    /// @notice Thrown when the sender is not authorized
    error ProtocolStatus_Unauthorized();
    /// @notice Thrown when the protocol must be active to disable upgrades
    error ProtocolStatus_MustBeActiveToDisableUpgrades();
    /// @notice Thrown when the owner cannot be a member
    error ProtocolStatus_OwnerCannotBeMember(address member, address owner);

    // ============================================================================
    // Events
    // ============================================================================

    /// @notice Emitted when the protocol status changes
    event ProtocolStatusChanged(
        State indexed oldStatus, State indexed newStatus, address indexed changedBy, string name
    );
    /// @notice Emitted when a security council member is added
    event SecurityCouncilMemberAdded(address indexed member, string name);
    /// @notice Emitted when a security council member is removed
    event SecurityCouncilMemberRemoved(address indexed member, string name);

    // ============================================================================
    // Modifiers
    // ============================================================================

    /// @dev Modifier to restrict access to only the DAO (owner) or Security Council members
    modifier onlyAuthorized() {
        if (msg.sender != owner() && !_securityCouncilMemberAddresses.contains(msg.sender)) {
            revert ProtocolStatus_Unauthorized();
        }
        _;
    }

    // ============================================================================
    // Constructor
    // ============================================================================

    /// @notice Initializes the protocol status contract
    /// @param initialMembers The initial security council members
    /// @param initialOwner The initial owner
    constructor(SecurityCouncilMember[] memory initialMembers, address initialOwner) Ownable(initialOwner) {
        // Check for empty array
        if (initialMembers.length == 0) {
            revert ProtocolStatus_EmptyArray();
        }

        // Add initial Security Council members
        for (uint256 i = 0; i < initialMembers.length; i++) {
            address member = initialMembers[i].memberAddress;
            string memory name = initialMembers[i].name;
            // Validate if the member address is not zero address
            if (member == address(0)) {
                revert ProtocolStatus_ZeroAddress();
            }

            // Validate if the member is not the owner
            if (member == owner()) {
                revert ProtocolStatus_OwnerCannotBeMember(member, owner());
            }

            // Add member to the set if not already present
            if (!_securityCouncilMemberAddresses.add(member)) {
                revert ProtocolStatus_MemberAlreadyExists(member, name);
            }

            _securityCouncilMembers[member] = SecurityCouncilMember({ memberAddress: member, name: name });

            // Emit event for each added member
            emit SecurityCouncilMemberAdded(member, name);
        }

        // Initialize protocol status to INACTIVE
        _protocolStatus = State.INACTIVE;

        // Emit initial status event
        emit ProtocolStatusChanged(State.ACTIVE, State.INACTIVE, msg.sender, _securityCouncilMembers[msg.sender].name);
    }

    // ============================================================================
    // Security Council Management
    // ============================================================================

    /// @inheritdoc IProtocolStatus
    function addSecurityCouncilMember(SecurityCouncilMember memory member) external onlyOwner {
        address memberAddress = member.memberAddress;
        string memory name = member.name;

        // Validate if the member address is not zero address
        if (memberAddress == address(0)) {
            revert ProtocolStatus_ZeroAddress();
        }

        // Validate if the member is not the owner
        if (memberAddress == owner()) {
            revert ProtocolStatus_OwnerCannotBeMember(memberAddress, owner());
        }

        // Add member to the set if not already present
        if (!_securityCouncilMemberAddresses.add(memberAddress)) {
            revert ProtocolStatus_MemberAlreadyExists(memberAddress, name);
        }

        _securityCouncilMembers[memberAddress] = SecurityCouncilMember({ memberAddress: memberAddress, name: name });

        // Emit event for the added member
        emit SecurityCouncilMemberAdded(memberAddress, name);
    }

    /// @inheritdoc IProtocolStatus
    function removeSecurityCouncilMember(SecurityCouncilMember memory member) external onlyOwner {
        address memberAddress = member.memberAddress;
        string memory name = member.name;
        // Remove member from the set if present
        if (!_securityCouncilMemberAddresses.remove(memberAddress)) {
            revert ProtocolStatus_MemberDoesNotExist(memberAddress, name);
        }

        // Emit event for the removed member
        emit SecurityCouncilMemberRemoved(memberAddress, name);
    }

    // ============================================================================
    // Protocol Status Management
    // ============================================================================

    /// @inheritdoc IProtocolStatus
    function activateProtocol() external onlyOwner {
        State currentStatus = _protocolStatus;

        // Check if the protocol is already active
        if (currentStatus == State.ACTIVE) {
            revert ProtocolStatus_ProtocolIsAlreadyActive();
        }

        // Set protocol status to ACTIVE
        _protocolStatus = State.ACTIVE;

        // Emit status change event
        emit ProtocolStatusChanged(currentStatus, State.ACTIVE, msg.sender, _securityCouncilMembers[msg.sender].name);
    }

    /// @inheritdoc IProtocolStatus
    function deactivateProtocol() external onlyAuthorized {
        State currentStatus = _protocolStatus;

        // Check if the protocol is already inactive
        if (currentStatus == State.INACTIVE) {
            revert ProtocolStatus_ProtocolIsAlreadyInactive();
        }

        // Set protocol status to INACTIVE
        _protocolStatus = State.INACTIVE;

        // Emit status change event
        emit ProtocolStatusChanged(currentStatus, State.INACTIVE, msg.sender, _securityCouncilMembers[msg.sender].name);
    }

    /// @inheritdoc IProtocolStatus
    function disableUpgrades() external onlyAuthorized {
        State currentStatus = _protocolStatus;

        // Check if the protocol is ACTIVE, only then upgrades can be disabled
        // If it's already INACTIVE or UPGRADES_DISABLED, we shouldn't allow this action
        if (currentStatus != State.ACTIVE) {
            revert ProtocolStatus_MustBeActiveToDisableUpgrades();
        }

        // Set protocol status to UPGRADES_DISABLED
        _protocolStatus = State.UPGRADES_DISABLED;

        // Emit status change event
        emit ProtocolStatusChanged(
            currentStatus, State.UPGRADES_DISABLED, msg.sender, _securityCouncilMembers[msg.sender].name
        );
    }

    // ============================================================================
    // View Functions
    // ============================================================================

    /// @inheritdoc IProtocolStatus
    function getSecurityCouncilMembers() external view returns (SecurityCouncilMember[] memory) {
        uint256 memberCount = _securityCouncilMemberAddresses.length();
        SecurityCouncilMember[] memory members = new SecurityCouncilMember[](memberCount);
        for (uint256 i = 0; i < memberCount; i++) {
            address memberAddress = _securityCouncilMemberAddresses.at(i);
            members[i] = _securityCouncilMembers[memberAddress];
        }
        return members;
    }

    /// @inheritdoc IProtocolStatus
    function isSecurityCouncilMember(address member) external view returns (bool) {
        return _securityCouncilMemberAddresses.contains(member);
    }

    /// @inheritdoc IProtocolStatus
    function getProtocolStatus() external view returns (State) {
        return _protocolStatus;
    }

    /// @inheritdoc IProtocolStatus
    function getMemberName(address member) external view returns (string memory) {
        return _securityCouncilMembers[member].name;
    }
}
