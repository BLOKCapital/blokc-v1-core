// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ProtocolStatusTestBase } from "./ProtocolStatusTestBase.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";

/// @title ProtocolStatusViewFunctionsTest
/// @notice Tests for ProtocolStatus view functions
contract ProtocolStatusViewFunctionsTest is ProtocolStatusTestBase {
    
    function test_GetProtocolStatus_ReturnsInitialState() public view {
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }
    
    function test_GetProtocolStatus_ReturnsActiveState() public {
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.ACTIVE));
    }
    
    function test_GetProtocolStatus_ReturnsInactiveState() public {
        // Initially inactive
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
        
        // Activate then deactivate
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        vm.prank(owner);
        protocolStatus.deactivateProtocol();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }
    
    function test_GetProtocolStatus_ReturnsUpgradesDisabledState() public {
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        vm.prank(owner);
        protocolStatus.disableUpgrades();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.UPGRADES_DISABLED));
    }
    
    function test_GetSecurityCouncilMembers_ReturnsInitialMembers() public view {
        IProtocolStatus.SecurityCouncilMember[] memory members = protocolStatus.getSecurityCouncilMembers();
        
        assertEq(members.length, 2);
        assertEq(members[0].memberAddress, securityCouncil1);
        assertEq(members[0].name, "Security Council Member 1");
        assertEq(members[1].memberAddress, securityCouncil2);
        assertEq(members[1].name, "Security Council Member 2");
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
        assertEq(members[2].memberAddress, securityCouncil3);
        assertEq(members[2].name, "Security Council Member 3");
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
    
    function test_GetSecurityCouncilMembers_AfterMultipleOperations() public {
        // Add member
        IProtocolStatus.SecurityCouncilMember memory newMember = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil3,
            name: "Security Council Member 3"
        });
        
        vm.prank(owner);
        protocolStatus.addSecurityCouncilMember(newMember);
        
        // Remove member
        IProtocolStatus.SecurityCouncilMember memory memberToRemove = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil1,
            name: "Security Council Member 1"
        });
        
        vm.prank(owner);
        protocolStatus.removeSecurityCouncilMember(memberToRemove);
        
        IProtocolStatus.SecurityCouncilMember[] memory members = protocolStatus.getSecurityCouncilMembers();
        assertEq(members.length, 2);
        
        // Verify both remaining members are present (order may vary)
        bool found2 = false;
        bool found3 = false;
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].memberAddress == securityCouncil2) {
                found2 = true;
            }
            if (members[i].memberAddress == securityCouncil3) {
                found3 = true;
            }
        }
        assertTrue(found2);
        assertTrue(found3);
    }
    
    function test_IsSecurityCouncilMember_ReturnsTrueForMember() public view {
        assertTrue(protocolStatus.isSecurityCouncilMember(securityCouncil1));
        assertTrue(protocolStatus.isSecurityCouncilMember(securityCouncil2));
    }
    
    function test_IsSecurityCouncilMember_ReturnsFalseForNonMember() public view {
        assertFalse(protocolStatus.isSecurityCouncilMember(securityCouncil3));
        assertFalse(protocolStatus.isSecurityCouncilMember(user1));
        assertFalse(protocolStatus.isSecurityCouncilMember(owner));
        assertFalse(protocolStatus.isSecurityCouncilMember(address(0)));
    }
    
    function test_IsSecurityCouncilMember_AfterAdd() public {
        IProtocolStatus.SecurityCouncilMember memory newMember = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil3,
            name: "Security Council Member 3"
        });
        
        assertFalse(protocolStatus.isSecurityCouncilMember(securityCouncil3));
        
        vm.prank(owner);
        protocolStatus.addSecurityCouncilMember(newMember);
        
        assertTrue(protocolStatus.isSecurityCouncilMember(securityCouncil3));
    }
    
    function test_IsSecurityCouncilMember_AfterRemove() public {
        assertTrue(protocolStatus.isSecurityCouncilMember(securityCouncil1));
        
        IProtocolStatus.SecurityCouncilMember memory memberToRemove = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil1,
            name: "Security Council Member 1"
        });
        
        vm.prank(owner);
        protocolStatus.removeSecurityCouncilMember(memberToRemove);
        
        assertFalse(protocolStatus.isSecurityCouncilMember(securityCouncil1));
    }
    
    function test_GetMemberName_ReturnsCorrectName() public view {
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
    
    function test_GetMemberName_ForNonMember() public view {
        // For non-members, returns empty string (default value for string in mapping)
        assertEq(protocolStatus.getMemberName(securityCouncil3), "");
        assertEq(protocolStatus.getMemberName(user1), "");
    }
    
    function test_GetMemberName_AfterRemove() public {
        assertEq(protocolStatus.getMemberName(securityCouncil1), "Security Council Member 1");
        
        IProtocolStatus.SecurityCouncilMember memory memberToRemove = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil1,
            name: "Security Council Member 1"
        });
        
        vm.prank(owner);
        protocolStatus.removeSecurityCouncilMember(memberToRemove);
        
        // After removal, name is still in the mapping (mapping is not cleared)
        // But the member is no longer in the set, so they're not a member
        assertEq(protocolStatus.getMemberName(securityCouncil1), "Security Council Member 1");
        assertFalse(protocolStatus.isSecurityCouncilMember(securityCouncil1));
    }
    
    function test_ViewFunctions_CanBeCalledByAnyone() public view {
        // View functions should be callable by anyone
        protocolStatus.getProtocolStatus();
        protocolStatus.getSecurityCouncilMembers();
        protocolStatus.isSecurityCouncilMember(securityCouncil1);
        protocolStatus.getMemberName(securityCouncil1);
    }
    
    function test_ViewFunctions_StateDoesNotChange() public {
        IProtocolStatus.State initialState = protocolStatus.getProtocolStatus();
        
        // Call view functions multiple times
        protocolStatus.getProtocolStatus();
        protocolStatus.getSecurityCouncilMembers();
        protocolStatus.isSecurityCouncilMember(securityCouncil1);
        
        // State should remain unchanged
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(initialState));
    }
    
    function test_GetSecurityCouncilMembers_OrderIsMaintained() public {
        IProtocolStatus.SecurityCouncilMember[] memory members1 = protocolStatus.getSecurityCouncilMembers();
        
        // Add and remove a member
        IProtocolStatus.SecurityCouncilMember memory newMember = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil3,
            name: "Security Council Member 3"
        });
        
        vm.prank(owner);
        protocolStatus.addSecurityCouncilMember(newMember);
        
        IProtocolStatus.SecurityCouncilMember memory memberToRemove = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil3,
            name: "Security Council Member 3"
        });
        
        vm.prank(owner);
        protocolStatus.removeSecurityCouncilMember(memberToRemove);
        
        IProtocolStatus.SecurityCouncilMember[] memory members2 = protocolStatus.getSecurityCouncilMembers();
        
        // Original members should still be in the same order
        assertEq(members1.length, members2.length);
        assertEq(members1[0].memberAddress, members2[0].memberAddress);
        assertEq(members1[1].memberAddress, members2[1].memberAddress);
    }
}

