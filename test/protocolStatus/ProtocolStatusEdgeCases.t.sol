// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ProtocolStatusTestBase } from "./ProtocolStatusTestBase.sol";
import { ProtocolStatus } from "src/protocolStatus/ProtocolStatus.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";

/// @title ProtocolStatusEdgeCasesTest
/// @notice Tests for edge cases in ProtocolStatus
contract ProtocolStatusEdgeCasesTest is ProtocolStatusTestBase {
    
    function test_AddMember_ThenRemove_ThenAddAgain() public {
        IProtocolStatus.SecurityCouncilMember memory member = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil3,
            name: "Security Council Member 3"
        });
        
        // Add
        vm.prank(owner);
        protocolStatus.addSecurityCouncilMember(member);
        assertTrue(protocolStatus.isSecurityCouncilMember(securityCouncil3));
        
        // Remove
        vm.prank(owner);
        protocolStatus.removeSecurityCouncilMember(member);
        assertFalse(protocolStatus.isSecurityCouncilMember(securityCouncil3));
        
        // Add again
        vm.prank(owner);
        protocolStatus.addSecurityCouncilMember(member);
        assertTrue(protocolStatus.isSecurityCouncilMember(securityCouncil3));
    }
    
    function test_StateTransitions_MultipleRapidChanges() public {
        // Rapid state changes
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        vm.prank(owner);
        protocolStatus.deactivateProtocol();
        
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        vm.prank(owner);
        protocolStatus.disableUpgrades();
        
        vm.prank(owner);
        protocolStatus.deactivateProtocol();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }
    
    function test_RemoveAllSecurityCouncilMembers() public {
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
        
        IProtocolStatus.SecurityCouncilMember[] memory members = protocolStatus.getSecurityCouncilMembers();
        assertEq(members.length, 0);
    }
    
    function test_RemoveAllMembers_ThenOwnerCanStillDeactivate() public {
        // Remove all security council members
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
        
        // Owner should still be able to deactivate (owner is always authorized)
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        vm.prank(owner);
        protocolStatus.deactivateProtocol();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }
    
    function test_AddManyMembers() public {
        uint256 count = 10;
        
        for (uint256 i = 0; i < count; i++) {
            address memberAddr = makeAddr(string(abi.encodePacked("member", i)));
            IProtocolStatus.SecurityCouncilMember memory member = IProtocolStatus.SecurityCouncilMember({
                memberAddress: memberAddr,
                name: string(abi.encodePacked("Member ", i))
            });
            
            vm.prank(owner);
            protocolStatus.addSecurityCouncilMember(member);
        }
        
        IProtocolStatus.SecurityCouncilMember[] memory members = protocolStatus.getSecurityCouncilMembers();
        assertEq(members.length, 2 + count); // 2 initial + count new
    }
    
    function test_StateChange_ByDifferentSecurityCouncilMembers() public {
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        // First member deactivates
        vm.prank(securityCouncil1);
        protocolStatus.deactivateProtocol();
        
        // Owner reactivates
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        // Second member disables upgrades
        vm.prank(securityCouncil2);
        protocolStatus.disableUpgrades();
        
        // First member deactivates again
        vm.prank(securityCouncil1);
        protocolStatus.deactivateProtocol();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }
    
    function test_GetMemberName_ForRemovedMember() public {
        assertEq(protocolStatus.getMemberName(securityCouncil1), "Security Council Member 1");
        
        IProtocolStatus.SecurityCouncilMember memory memberToRemove = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil1,
            name: "Security Council Member 1"
        });
        
        vm.prank(owner);
        protocolStatus.removeSecurityCouncilMember(memberToRemove);
        
        // Name is still in the mapping after removal (mapping is not cleared)
        // But the member is no longer in the set
        assertEq(protocolStatus.getMemberName(securityCouncil1), "Security Council Member 1");
        assertFalse(protocolStatus.isSecurityCouncilMember(securityCouncil1));
    }
    
    function test_IsSecurityCouncilMember_ForZeroAddress() public view {
        assertFalse(protocolStatus.isSecurityCouncilMember(address(0)));
    }
    
    function test_GetMemberName_ForZeroAddress() public view {
        assertEq(protocolStatus.getMemberName(address(0)), "");
    }
    
    function test_AddMember_WithEmptyName() public {
        IProtocolStatus.SecurityCouncilMember memory member = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil3,
            name: "" // Empty name
        });
        
        vm.prank(owner);
        protocolStatus.addSecurityCouncilMember(member);
        
        assertTrue(protocolStatus.isSecurityCouncilMember(securityCouncil3));
        assertEq(protocolStatus.getMemberName(securityCouncil3), "");
    }
    
    function test_AddMember_WithLongName() public {
        string memory longName = "This is a very long name for a security council member that tests if the contract can handle long strings properly";
        
        IProtocolStatus.SecurityCouncilMember memory member = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil3,
            name: longName
        });
        
        vm.prank(owner);
        protocolStatus.addSecurityCouncilMember(member);
        
        assertEq(protocolStatus.getMemberName(securityCouncil3), longName);
    }
    
    function test_RevertIf_DisableUpgrades_FromInactiveThenActivate() public {
        // Try to disable upgrades from inactive state
        vm.prank(owner);
        vm.expectRevert(ProtocolStatus.ProtocolStatus_MustBeActiveToDisableUpgrades.selector);
        protocolStatus.disableUpgrades();
        
        // Activate
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        // Now disable upgrades should work
        vm.prank(owner);
        protocolStatus.disableUpgrades();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.UPGRADES_DISABLED));
    }
    
    function test_StateTransitions_AllPossiblePaths() public {
        // Path 1: INACTIVE -> ACTIVE -> INACTIVE
        vm.prank(owner);
        protocolStatus.activateProtocol();
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.ACTIVE));
        
        vm.prank(owner);
        protocolStatus.deactivateProtocol();
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
        
        // Path 2: INACTIVE -> ACTIVE -> UPGRADES_DISABLED -> INACTIVE
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        vm.prank(owner);
        protocolStatus.disableUpgrades();
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.UPGRADES_DISABLED));
        
        vm.prank(owner);
        protocolStatus.deactivateProtocol();
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }
    
    function test_SecurityCouncilMember_CanPerformMultipleOperations() public {
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        // Security council member can disable upgrades
        vm.prank(securityCouncil1);
        protocolStatus.disableUpgrades();
        
        // Then deactivate
        vm.prank(securityCouncil1);
        protocolStatus.deactivateProtocol();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }
    
    function testFuzz_AddRemoveMember(address memberAddr) public {
        vm.assume(memberAddr != address(0));
        vm.assume(memberAddr != owner);
        vm.assume(!protocolStatus.isSecurityCouncilMember(memberAddr));
        
        IProtocolStatus.SecurityCouncilMember memory member = IProtocolStatus.SecurityCouncilMember({
            memberAddress: memberAddr,
            name: "Fuzz Member"
        });
        
        vm.prank(owner);
        protocolStatus.addSecurityCouncilMember(member);
        assertTrue(protocolStatus.isSecurityCouncilMember(memberAddr));
        
        vm.prank(owner);
        protocolStatus.removeSecurityCouncilMember(member);
        assertFalse(protocolStatus.isSecurityCouncilMember(memberAddr));
    }
    
    function test_RemoveMember_ThenAddDifferentMemberAtSameAddress() public {
        // Remove securityCouncil1
        IProtocolStatus.SecurityCouncilMember memory memberToRemove = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil1,
            name: "Security Council Member 1"
        });
        
        vm.prank(owner);
        protocolStatus.removeSecurityCouncilMember(memberToRemove);
        
        // Add a different member with different name at same address
        IProtocolStatus.SecurityCouncilMember memory newMember = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil1,
            name: "New Member Name"
        });
        
        vm.prank(owner);
        protocolStatus.addSecurityCouncilMember(newMember);
        
        assertEq(protocolStatus.getMemberName(securityCouncil1), "New Member Name");
    }
}

