// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/*###############################################################################

    @title KillSwitch
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

    // ========== ERRORS ==========
    error ProtocolStatus_ProtocolIsAlreadyActive();
    error ProtocolStatus_ProtocolIsAlreadyInactive();
    error ProtocolStatus_ZeroAddress();
    error ProtocolStatus_EmptyArray();
    error ProtocolStatus_MemberAlreadyExists(address member, string name);
    error ProtocolStatus_MemberDoesNotExist(address member, string name);
    error ProtocolStatus_Unauthorized();
    error ProtocolStatus_MustBeActiveToDisableUpgrades();
    error ProtocolStatus_OwnerCannotBeMember(address member, address owner);

    // ========== EVENTS ==========
    event ProtocolStatusChanged(
        State indexed oldStatus, State indexed newStatus, address indexed changedBy, string name
    );
    event SecurityCouncilMemberAdded(address indexed member, string name);
    event SecurityCouncilMemberRemoved(address indexed member, string name);

    // ========== MODIFIERS ==========
    /**
     * @dev Modifier to restrict access to only the DAO (owner) or Security Council members
     */
    modifier onlyAuthorized() {
        if (msg.sender != owner() && !_securityCouncilMemberAddresses.contains(msg.sender)) {
            revert ProtocolStatus_Unauthorized();
        }
        _;
    }

    // ========== CONSTRUCTOR ==========
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

    // ========== SECURITY COUNCIL MANAGEMENT ==========

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

    // ========== PROTOCOL STATUS MANAGEMENT ==========

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

    // ========== VIEW FUNCTIONS ==========

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
