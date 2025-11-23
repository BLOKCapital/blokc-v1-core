// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ProtocolStatusTestBase } from "./ProtocolStatusTestBase.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";

/// @title ProtocolStatusIntegrationTest
/// @notice Integration tests for ProtocolStatus
contract ProtocolStatusIntegrationTest is ProtocolStatusTestBase {
    
    function test_Integration_CompleteWorkflow() public {
        // Initial state
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
        
        // Add a new member
        IProtocolStatus.SecurityCouncilMember memory newMember = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil3,
            name: "Security Council Member 3"
        });
        
        vm.prank(owner);
        protocolStatus.addSecurityCouncilMember(newMember);
        
        // Activate protocol
        vm.prank(owner);
        protocolStatus.activateProtocol();
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.ACTIVE));
        
        // Security council member disables upgrades
        vm.prank(securityCouncil1);
        protocolStatus.disableUpgrades();
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.UPGRADES_DISABLED));
        
        // Security council member deactivates protocol
        vm.prank(securityCouncil2);
        protocolStatus.deactivateProtocol();
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
        
        // Remove a member
        IProtocolStatus.SecurityCouncilMember memory memberToRemove = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil1,
            name: "Security Council Member 1"
        });
        
        vm.prank(owner);
        protocolStatus.removeSecurityCouncilMember(memberToRemove);
        
        // Verify final state
        IProtocolStatus.SecurityCouncilMember[] memory members = protocolStatus.getSecurityCouncilMembers();
        assertEq(members.length, 2); // securityCouncil2 and securityCouncil3
        assertFalse(protocolStatus.isSecurityCouncilMember(securityCouncil1));
        assertTrue(protocolStatus.isSecurityCouncilMember(securityCouncil2));
        assertTrue(protocolStatus.isSecurityCouncilMember(securityCouncil3));
    }
    
    function test_Integration_MemberManagementAndStateChanges() public {
        // Add multiple members
        IProtocolStatus.SecurityCouncilMember memory member3 = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil3,
            name: "Security Council Member 3"
        });
        
        address member4 = makeAddr("member4");
        IProtocolStatus.SecurityCouncilMember memory member4Struct = IProtocolStatus.SecurityCouncilMember({
            memberAddress: member4,
            name: "Security Council Member 4"
        });
        
        vm.prank(owner);
        protocolStatus.addSecurityCouncilMember(member3);
        
        vm.prank(owner);
        protocolStatus.addSecurityCouncilMember(member4Struct);
        
        // Activate protocol
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        // All members can disable upgrades
        vm.prank(securityCouncil1);
        protocolStatus.disableUpgrades();
        
        // Reactivate
        vm.prank(owner);
        protocolStatus.deactivateProtocol();
        
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        // Different member disables upgrades
        vm.prank(securityCouncil2);
        protocolStatus.disableUpgrades();
        
        // Remove a member while protocol is UPGRADES_DISABLED
        IProtocolStatus.SecurityCouncilMember memory memberToRemove = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil1,
            name: "Security Council Member 1"
        });
        
        vm.prank(owner);
        protocolStatus.removeSecurityCouncilMember(memberToRemove);
        
        // Remaining members can still deactivate
        vm.prank(securityCouncil2);
        protocolStatus.deactivateProtocol();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }
    
    function test_Integration_StateTransitionsWithMemberChanges() public {
        // Start with inactive state
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
        
        // Add member
        IProtocolStatus.SecurityCouncilMember memory newMember = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil3,
            name: "Security Council Member 3"
        });
        
        vm.prank(owner);
        protocolStatus.addSecurityCouncilMember(newMember);
        
        // Activate
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        // New member can disable upgrades
        vm.prank(securityCouncil3);
        protocolStatus.disableUpgrades();
        
        // Remove member
        vm.prank(owner);
        protocolStatus.removeSecurityCouncilMember(newMember);
        
        // Removed member can no longer deactivate
        vm.prank(securityCouncil3);
        vm.expectRevert();
        protocolStatus.deactivateProtocol();
        
        // Owner can still deactivate
        vm.prank(owner);
        protocolStatus.deactivateProtocol();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }
    
    function test_Integration_MultipleMembersCoordination() public {
        // Add multiple members
        IProtocolStatus.SecurityCouncilMember memory member3 = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil3,
            name: "Security Council Member 3"
        });
        
        vm.prank(owner);
        protocolStatus.addSecurityCouncilMember(member3);
        
        // Activate protocol
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        // Member 1 disables upgrades
        vm.prank(securityCouncil1);
        protocolStatus.disableUpgrades();
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.UPGRADES_DISABLED));
        
        // Member 2 deactivates
        vm.prank(securityCouncil2);
        protocolStatus.deactivateProtocol();
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
        
        // Owner reactivates
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        // Member 3 disables upgrades
        vm.prank(securityCouncil3);
        protocolStatus.disableUpgrades();
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.UPGRADES_DISABLED));
        
        // Verify all members are still registered
        assertTrue(protocolStatus.isSecurityCouncilMember(securityCouncil1));
        assertTrue(protocolStatus.isSecurityCouncilMember(securityCouncil2));
        assertTrue(protocolStatus.isSecurityCouncilMember(securityCouncil3));
    }
    
    function test_Integration_OwnerAndSecurityCouncilInteraction() public {
        // Owner activates
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        // Security council disables upgrades
        vm.prank(securityCouncil1);
        protocolStatus.disableUpgrades();
        
        // Owner deactivates (owner can always deactivate)
        vm.prank(owner);
        protocolStatus.deactivateProtocol();
        
        // Owner reactivates
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        // Security council deactivates
        vm.prank(securityCouncil2);
        protocolStatus.deactivateProtocol();
        
        // Owner manages members while inactive
        IProtocolStatus.SecurityCouncilMember memory newMember = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil3,
            name: "Security Council Member 3"
        });
        
        vm.prank(owner);
        protocolStatus.addSecurityCouncilMember(newMember);
        
        // Owner activates again
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        // New member can now disable upgrades
        vm.prank(securityCouncil3);
        protocolStatus.disableUpgrades();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.UPGRADES_DISABLED));
    }
    
    function test_Integration_ViewFunctionsConsistency() public {
        // Get initial state
        IProtocolStatus.State initialState = protocolStatus.getProtocolStatus();
        IProtocolStatus.SecurityCouncilMember[] memory initialMembers = protocolStatus.getSecurityCouncilMembers();
        
        // Perform operations
        IProtocolStatus.SecurityCouncilMember memory newMember = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil3,
            name: "Security Council Member 3"
        });
        
        vm.prank(owner);
        protocolStatus.addSecurityCouncilMember(newMember);
        
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        // Verify view functions are consistent
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.ACTIVE));
        
        IProtocolStatus.SecurityCouncilMember[] memory members = protocolStatus.getSecurityCouncilMembers();
        assertEq(members.length, initialMembers.length + 1);
        assertTrue(protocolStatus.isSecurityCouncilMember(securityCouncil3));
        assertEq(protocolStatus.getMemberName(securityCouncil3), "Security Council Member 3");
    }
    
    function test_Integration_EventEmissions() public {
        // Test that events are emitted correctly through the workflow
        vm.prank(owner);
        vm.expectEmit(true, true, true, false);
        emit ProtocolStatusChanged(
            IProtocolStatus.State.INACTIVE,
            IProtocolStatus.State.ACTIVE,
            owner,
            ""
        );
        protocolStatus.activateProtocol();
        
        vm.prank(securityCouncil1);
        vm.expectEmit(true, true, true, false);
        emit ProtocolStatusChanged(
            IProtocolStatus.State.ACTIVE,
            IProtocolStatus.State.UPGRADES_DISABLED,
            securityCouncil1,
            "Security Council Member 1"
        );
        protocolStatus.disableUpgrades();
        
        IProtocolStatus.SecurityCouncilMember memory newMember = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil3,
            name: "Security Council Member 3"
        });
        
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit SecurityCouncilMemberAdded(securityCouncil3, "Security Council Member 3");
        protocolStatus.addSecurityCouncilMember(newMember);
    }
}

