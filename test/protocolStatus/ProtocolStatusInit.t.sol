// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ProtocolStatusTestBase } from "./ProtocolStatusTestBase.sol";
import { ProtocolStatus } from "src/protocolStatus/ProtocolStatus.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";

/// @title ProtocolStatusInitTest
/// @notice Tests for ProtocolStatus initialization
contract ProtocolStatusInitTest is ProtocolStatusTestBase {
    
    function test_Initialize_WithValidMembers() public {
        IProtocolStatus.SecurityCouncilMember[] memory members = new IProtocolStatus.SecurityCouncilMember[](1);
        members[0] = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil1,
            name: "Member 1"
        });
        
        ProtocolStatus newStatus = new ProtocolStatus(members, owner);
        
        // Verify initial state is INACTIVE
        assertEq(uint256(newStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
        
        // Verify members were added
        IProtocolStatus.SecurityCouncilMember[] memory retrievedMembers = newStatus.getSecurityCouncilMembers();
        assertEq(retrievedMembers.length, 1);
        assertEq(retrievedMembers[0].memberAddress, securityCouncil1);
        assertEq(retrievedMembers[0].name, "Member 1");
    }
    
    function test_Initialize_WithMultipleMembers() public {
        IProtocolStatus.SecurityCouncilMember[] memory members = new IProtocolStatus.SecurityCouncilMember[](3);
        members[0] = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil1,
            name: "Member 1"
        });
        members[1] = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil2,
            name: "Member 2"
        });
        members[2] = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil3,
            name: "Member 3"
        });
        
        ProtocolStatus newStatus = new ProtocolStatus(members, owner);
        
        // Verify members were added
        IProtocolStatus.SecurityCouncilMember[] memory retrievedMembers = newStatus.getSecurityCouncilMembers();
        assertEq(retrievedMembers.length, 3);
    }
    
    function test_Initialize_SetsInitialStatusToInactive() public {
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }
    
    function test_Initialize_InitialMembersAreRegistered() public {
        IProtocolStatus.SecurityCouncilMember[] memory members = protocolStatus.getSecurityCouncilMembers();
        assertEq(members.length, 2);
        assertTrue(protocolStatus.isSecurityCouncilMember(securityCouncil1));
        assertTrue(protocolStatus.isSecurityCouncilMember(securityCouncil2));
    }
    
    function test_Initialize_EmitsMemberAddedEvents() public {
        IProtocolStatus.SecurityCouncilMember[] memory members = new IProtocolStatus.SecurityCouncilMember[](1);
        members[0] = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil1,
            name: "Member 1"
        });
        
        vm.expectEmit(true, false, false, true);
        emit SecurityCouncilMemberAdded(securityCouncil1, "Member 1");
        
        new ProtocolStatus(members, owner);
    }
    
    function test_Initialize_EmitsStatusChangedEvent() public {
        IProtocolStatus.SecurityCouncilMember[] memory members = new IProtocolStatus.SecurityCouncilMember[](1);
        members[0] = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil1,
            name: "Member 1"
        });
        
        // The constructor emits ProtocolStatusChanged event with state transition from ACTIVE to INACTIVE
        // Note: The name field depends on whether msg.sender is in the members mapping
        // Since msg.sender in constructor is not a member, the name will be empty
        vm.expectEmit(true, true, false, true); // Check only indexed fields (oldStatus, newStatus, changedBy), ignore name
        emit ProtocolStatusChanged(
            IProtocolStatus.State.ACTIVE,
            IProtocolStatus.State.INACTIVE,
            address(0), // msg.sender in constructor
            "" // Name field (empty for non-member)
        );
        
        new ProtocolStatus(members, owner);
    }
    
    function test_RevertIf_InitializeWithEmptyArray() public {
        IProtocolStatus.SecurityCouncilMember[] memory emptyMembers = new IProtocolStatus.SecurityCouncilMember[](0);
        
        vm.expectRevert(ProtocolStatus.ProtocolStatus_EmptyArray.selector);
        new ProtocolStatus(emptyMembers, owner);
    }
    
    function test_RevertIf_InitializeWithZeroAddressMember() public {
        IProtocolStatus.SecurityCouncilMember[] memory members = new IProtocolStatus.SecurityCouncilMember[](1);
        members[0] = IProtocolStatus.SecurityCouncilMember({
            memberAddress: address(0),
            name: "Zero Address Member"
        });
        
        vm.expectRevert(ProtocolStatus.ProtocolStatus_ZeroAddress.selector);
        new ProtocolStatus(members, owner);
    }
    
    function test_RevertIf_InitializeWithOwnerAsMember() public {
        IProtocolStatus.SecurityCouncilMember[] memory members = new IProtocolStatus.SecurityCouncilMember[](1);
        members[0] = IProtocolStatus.SecurityCouncilMember({
            memberAddress: owner,
            name: "Owner Member"
        });
        
        vm.expectRevert(
            abi.encodeWithSelector(
                ProtocolStatus.ProtocolStatus_OwnerCannotBeMember.selector,
                owner,
                owner
            )
        );
        new ProtocolStatus(members, owner);
    }
    
    function test_RevertIf_InitializeWithDuplicateMembers() public {
        IProtocolStatus.SecurityCouncilMember[] memory members = new IProtocolStatus.SecurityCouncilMember[](2);
        members[0] = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil1,
            name: "Member 1"
        });
        members[1] = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil1, // Duplicate
            name: "Member 1 Duplicate"
        });
        
        vm.expectRevert(
            abi.encodeWithSelector(
                ProtocolStatus.ProtocolStatus_MemberAlreadyExists.selector,
                securityCouncil1,
                "Member 1 Duplicate"
            )
        );
        new ProtocolStatus(members, owner);
    }
    
    function test_Initialize_OwnerIsSetCorrectly() public {
        assertEq(protocolStatus.owner(), owner);
    }
    
    function test_Initialize_NonOwnerCannotBeOwner() public {
        assertTrue(protocolStatus.owner() != user1);
    }
}

