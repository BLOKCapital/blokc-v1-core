// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ProtocolStatusTestBase } from "./ProtocolStatusTestBase.sol";
import { ProtocolStatus } from "src/protocolStatus/ProtocolStatus.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";

/// @title ProtocolStatusSecurityCouncilTest
/// @notice Tests for Security Council member management
contract ProtocolStatusSecurityCouncilTest is ProtocolStatusTestBase {
    
    function test_AddSecurityCouncilMember_ByOwner() public {
        IProtocolStatus.SecurityCouncilMember memory newMember = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil3,
            name: "Security Council Member 3"
        });
        
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit SecurityCouncilMemberAdded(securityCouncil3, "Security Council Member 3");
        protocolStatus.addSecurityCouncilMember(newMember);
        
        assertTrue(protocolStatus.isSecurityCouncilMember(securityCouncil3));
        assertEq(protocolStatus.getMemberName(securityCouncil3), "Security Council Member 3");
    }
    
    function test_AddSecurityCouncilMember_UpdatesMembersList() public {
        IProtocolStatus.SecurityCouncilMember memory newMember = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil3,
            name: "Security Council Member 3"
        });
        
        uint256 memberCountBefore = protocolStatus.getSecurityCouncilMembers().length;
        
        vm.prank(owner);
        protocolStatus.addSecurityCouncilMember(newMember);
        
        uint256 memberCountAfter = protocolStatus.getSecurityCouncilMembers().length;
        assertEq(memberCountAfter, memberCountBefore + 1);
    }
    
    function test_AddSecurityCouncilMember_MultipleMembers() public {
        IProtocolStatus.SecurityCouncilMember memory member1 = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil3,
            name: "Member 3"
        });
        
        address member4 = makeAddr("member4");
        IProtocolStatus.SecurityCouncilMember memory member2 = IProtocolStatus.SecurityCouncilMember({
            memberAddress: member4,
            name: "Member 4"
        });
        
        vm.prank(owner);
        protocolStatus.addSecurityCouncilMember(member1);
        
        vm.prank(owner);
        protocolStatus.addSecurityCouncilMember(member2);
        
        assertTrue(protocolStatus.isSecurityCouncilMember(securityCouncil3));
        assertTrue(protocolStatus.isSecurityCouncilMember(member4));
    }
    
    function test_RemoveSecurityCouncilMember_ByOwner() public {
        IProtocolStatus.SecurityCouncilMember memory memberToRemove = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil1,
            name: "Security Council Member 1"
        });
        
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit SecurityCouncilMemberRemoved(securityCouncil1, "Security Council Member 1");
        protocolStatus.removeSecurityCouncilMember(memberToRemove);
        
        assertFalse(protocolStatus.isSecurityCouncilMember(securityCouncil1));
    }
    
    function test_RemoveSecurityCouncilMember_UpdatesMembersList() public {
        IProtocolStatus.SecurityCouncilMember memory memberToRemove = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil1,
            name: "Security Council Member 1"
        });
        
        uint256 memberCountBefore = protocolStatus.getSecurityCouncilMembers().length;
        
        vm.prank(owner);
        protocolStatus.removeSecurityCouncilMember(memberToRemove);
        
        uint256 memberCountAfter = protocolStatus.getSecurityCouncilMembers().length;
        assertEq(memberCountAfter, memberCountBefore - 1);
    }
    
    function test_RemoveSecurityCouncilMember_RemovesCorrectMember() public {
        // Remove first member
        IProtocolStatus.SecurityCouncilMember memory memberToRemove1 = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil1,
            name: "Security Council Member 1"
        });
        
        vm.prank(owner);
        protocolStatus.removeSecurityCouncilMember(memberToRemove1);
        
        // Second member should still exist
        assertFalse(protocolStatus.isSecurityCouncilMember(securityCouncil1));
        assertTrue(protocolStatus.isSecurityCouncilMember(securityCouncil2));
    }
    
    function test_RemoveSecurityCouncilMember_MultipleRemovals() public {
        IProtocolStatus.SecurityCouncilMember memory member1 = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil1,
            name: "Security Council Member 1"
        });
        
        IProtocolStatus.SecurityCouncilMember memory member2 = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil2,
            name: "Security Council Member 2"
        });
        
        vm.prank(owner);
        protocolStatus.removeSecurityCouncilMember(member1);
        
        vm.prank(owner);
        protocolStatus.removeSecurityCouncilMember(member2);
        
        assertFalse(protocolStatus.isSecurityCouncilMember(securityCouncil1));
        assertFalse(protocolStatus.isSecurityCouncilMember(securityCouncil2));
    }
    
    function test_AddAndRemoveSecurityCouncilMember() public {
        // Add member
        IProtocolStatus.SecurityCouncilMember memory newMember = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil3,
            name: "Security Council Member 3"
        });
        
        vm.prank(owner);
        protocolStatus.addSecurityCouncilMember(newMember);
        assertTrue(protocolStatus.isSecurityCouncilMember(securityCouncil3));
        
        // Remove member
        vm.prank(owner);
        protocolStatus.removeSecurityCouncilMember(newMember);
        assertFalse(protocolStatus.isSecurityCouncilMember(securityCouncil3));
    }
    
    function test_RevertIf_AddSecurityCouncilMember_ByNonOwner() public {
        IProtocolStatus.SecurityCouncilMember memory newMember = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil3,
            name: "Security Council Member 3"
        });
        
        vm.prank(nonOwner);
        vm.expectRevert();
        protocolStatus.addSecurityCouncilMember(newMember);
    }
    
    function test_RevertIf_AddSecurityCouncilMember_ZeroAddress() public {
        IProtocolStatus.SecurityCouncilMember memory newMember = IProtocolStatus.SecurityCouncilMember({
            memberAddress: address(0),
            name: "Zero Address Member"
        });
        
        vm.prank(owner);
        vm.expectRevert(ProtocolStatus.ProtocolStatus_ZeroAddress.selector);
        protocolStatus.addSecurityCouncilMember(newMember);
    }
    
    function test_RevertIf_AddSecurityCouncilMember_OwnerAsMember() public {
        IProtocolStatus.SecurityCouncilMember memory newMember = IProtocolStatus.SecurityCouncilMember({
            memberAddress: owner,
            name: "Owner Member"
        });
        
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ProtocolStatus.ProtocolStatus_OwnerCannotBeMember.selector,
                owner,
                owner
            )
        );
        protocolStatus.addSecurityCouncilMember(newMember);
    }
    
    function test_RevertIf_AddSecurityCouncilMember_DuplicateMember() public {
        IProtocolStatus.SecurityCouncilMember memory newMember = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil1, // Already exists
            name: "Duplicate Member"
        });
        
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ProtocolStatus.ProtocolStatus_MemberAlreadyExists.selector,
                securityCouncil1,
                "Duplicate Member"
            )
        );
        protocolStatus.addSecurityCouncilMember(newMember);
    }
    
    function test_RevertIf_RemoveSecurityCouncilMember_ByNonOwner() public {
        IProtocolStatus.SecurityCouncilMember memory memberToRemove = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil1,
            name: "Security Council Member 1"
        });
        
        vm.prank(nonOwner);
        vm.expectRevert();
        protocolStatus.removeSecurityCouncilMember(memberToRemove);
    }
    
    function test_RevertIf_RemoveSecurityCouncilMember_NonExistentMember() public {
        IProtocolStatus.SecurityCouncilMember memory nonExistentMember = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil3, // Doesn't exist
            name: "Non Existent Member"
        });
        
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ProtocolStatus.ProtocolStatus_MemberDoesNotExist.selector,
                securityCouncil3,
                "Non Existent Member"
            )
        );
        protocolStatus.removeSecurityCouncilMember(nonExistentMember);
    }
    
    function test_GetSecurityCouncilMembers_ReturnsAllMembers() public {
        IProtocolStatus.SecurityCouncilMember[] memory members = protocolStatus.getSecurityCouncilMembers();
        
        assertEq(members.length, 2);
        assertEq(members[0].memberAddress, securityCouncil1);
        assertEq(members[1].memberAddress, securityCouncil2);
    }
    
    function test_GetSecurityCouncilMembers_AfterAdd() public {
        IProtocolStatus.SecurityCouncilMember memory newMember = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil3,
            name: "Security Council Member 3"
        });
        
        vm.prank(owner);
        protocolStatus.addSecurityCouncilMember(newMember);
        
        IProtocolStatus.SecurityCouncilMember[] memory members = protocolStatus.getSecurityCouncilMembers();
        assertEq(members.length, 3);
    }
    
    function test_GetSecurityCouncilMembers_AfterRemove() public {
        IProtocolStatus.SecurityCouncilMember memory memberToRemove = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil1,
            name: "Security Council Member 1"
        });
        
        vm.prank(owner);
        protocolStatus.removeSecurityCouncilMember(memberToRemove);
        
        IProtocolStatus.SecurityCouncilMember[] memory members = protocolStatus.getSecurityCouncilMembers();
        assertEq(members.length, 1);
        assertEq(members[0].memberAddress, securityCouncil2);
    }
    
    function test_IsSecurityCouncilMember_ReturnsTrueForMember() public {
        assertTrue(protocolStatus.isSecurityCouncilMember(securityCouncil1));
        assertTrue(protocolStatus.isSecurityCouncilMember(securityCouncil2));
    }
    
    function test_IsSecurityCouncilMember_ReturnsFalseForNonMember() public {
        assertFalse(protocolStatus.isSecurityCouncilMember(securityCouncil3));
        assertFalse(protocolStatus.isSecurityCouncilMember(user1));
        assertFalse(protocolStatus.isSecurityCouncilMember(owner));
    }
    
    function test_GetMemberName_ReturnsCorrectName() public {
        assertEq(protocolStatus.getMemberName(securityCouncil1), "Security Council Member 1");
        assertEq(protocolStatus.getMemberName(securityCouncil2), "Security Council Member 2");
    }
    
    function test_GetMemberName_AfterAdd() public {
        IProtocolStatus.SecurityCouncilMember memory newMember = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil3,
            name: "New Member Name"
        });
        
        vm.prank(owner);
        protocolStatus.addSecurityCouncilMember(newMember);
        
        assertEq(protocolStatus.getMemberName(securityCouncil3), "New Member Name");
    }
}

