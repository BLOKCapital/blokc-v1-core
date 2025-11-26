// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ProtocolStatusTestBase } from "./ProtocolStatusTestBase.sol";
import { ProtocolStatus } from "src/protocolStatus/ProtocolStatus.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";

/// @title ProtocolStatusAccessControlTest
/// @notice Tests for access control in ProtocolStatus
contract ProtocolStatusAccessControlTest is ProtocolStatusTestBase {
    
    function test_ActivateProtocol_OnlyOwner() public {
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.ACTIVE));
    }
    
    function test_RevertIf_ActivateProtocol_ByNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        protocolStatus.activateProtocol();
    }
    
    function test_RevertIf_ActivateProtocol_BySecurityCouncilMember() public {
        vm.prank(securityCouncil1);
        vm.expectRevert();
        protocolStatus.activateProtocol();
    }
    
    function test_DeactivateProtocol_ByOwner() public {
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        vm.prank(owner);
        protocolStatus.deactivateProtocol();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }
    
    function test_DeactivateProtocol_BySecurityCouncilMember() public {
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        vm.prank(securityCouncil1);
        protocolStatus.deactivateProtocol();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }
    
    function test_RevertIf_DeactivateProtocol_ByUnauthorized() public {
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        vm.prank(nonOwner);
        vm.expectRevert(ProtocolStatus.ProtocolStatus_Unauthorized.selector);
        protocolStatus.deactivateProtocol();
    }
    
    function test_DisableUpgrades_ByOwner() public {
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        vm.prank(owner);
        protocolStatus.disableUpgrades();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.UPGRADES_DISABLED));
    }
    
    function test_DisableUpgrades_BySecurityCouncilMember() public {
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        vm.prank(securityCouncil1);
        protocolStatus.disableUpgrades();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.UPGRADES_DISABLED));
    }
    
    function test_RevertIf_DisableUpgrades_ByUnauthorized() public {
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        vm.prank(nonOwner);
        vm.expectRevert(ProtocolStatus.ProtocolStatus_Unauthorized.selector);
        protocolStatus.disableUpgrades();
    }
    
    function test_AddSecurityCouncilMember_OnlyOwner() public {
        IProtocolStatus.SecurityCouncilMember memory newMember = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil3,
            name: "Security Council Member 3"
        });
        
        vm.prank(owner);
        protocolStatus.addSecurityCouncilMember(newMember);
        
        assertTrue(protocolStatus.isSecurityCouncilMember(securityCouncil3));
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
    
    function test_RevertIf_AddSecurityCouncilMember_BySecurityCouncilMember() public {
        IProtocolStatus.SecurityCouncilMember memory newMember = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil3,
            name: "Security Council Member 3"
        });
        
        vm.prank(securityCouncil1);
        vm.expectRevert();
        protocolStatus.addSecurityCouncilMember(newMember);
    }
    
    function test_RemoveSecurityCouncilMember_OnlyOwner() public {
        IProtocolStatus.SecurityCouncilMember memory memberToRemove = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil1,
            name: "Security Council Member 1"
        });
        
        vm.prank(owner);
        protocolStatus.removeSecurityCouncilMember(memberToRemove);
        
        assertFalse(protocolStatus.isSecurityCouncilMember(securityCouncil1));
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
    
    function test_RevertIf_RemoveSecurityCouncilMember_BySecurityCouncilMember() public {
        IProtocolStatus.SecurityCouncilMember memory memberToRemove = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil1,
            name: "Security Council Member 1"
        });
        
        vm.prank(securityCouncil1);
        vm.expectRevert();
        protocolStatus.removeSecurityCouncilMember(memberToRemove);
    }
    
    function test_ViewFunctions_AccessibleByAnyone() public view {
        // View functions should be accessible by anyone
        protocolStatus.getProtocolStatus();
        protocolStatus.getSecurityCouncilMembers();
        protocolStatus.isSecurityCouncilMember(securityCouncil1);
        protocolStatus.getMemberName(securityCouncil1);
    }
    
    function test_OnlyAuthorized_OwnerCanDeactivate() public {
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        vm.prank(owner);
        protocolStatus.deactivateProtocol();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }
    
    function test_OnlyAuthorized_SecurityCouncilCanDeactivate() public {
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        vm.prank(securityCouncil1);
        protocolStatus.deactivateProtocol();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }
    
    function test_OnlyAuthorized_OwnerCanDisableUpgrades() public {
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        vm.prank(owner);
        protocolStatus.disableUpgrades();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.UPGRADES_DISABLED));
    }
    
    function test_OnlyAuthorized_SecurityCouncilCanDisableUpgrades() public {
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        vm.prank(securityCouncil1);
        protocolStatus.disableUpgrades();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.UPGRADES_DISABLED));
    }
    
    function test_OnlyAuthorized_MultipleSecurityCouncilMembers() public {
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        // Both security council members can deactivate
        vm.prank(securityCouncil1);
        protocolStatus.deactivateProtocol();
        
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        vm.prank(securityCouncil2);
        protocolStatus.deactivateProtocol();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }
    
    function test_AccessControl_AfterMemberRemoval() public {
        // Remove a security council member
        IProtocolStatus.SecurityCouncilMember memory memberToRemove = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil1,
            name: "Security Council Member 1"
        });
        
        vm.prank(owner);
        protocolStatus.removeSecurityCouncilMember(memberToRemove);
        
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        // Removed member should no longer be able to deactivate
        vm.prank(securityCouncil1);
        vm.expectRevert(ProtocolStatus.ProtocolStatus_Unauthorized.selector);
        protocolStatus.deactivateProtocol();
        
        // Remaining member should still be able to deactivate
        vm.prank(securityCouncil2);
        protocolStatus.deactivateProtocol();
    }
    
    function test_AccessControl_AfterMemberAddition() public {
        IProtocolStatus.SecurityCouncilMember memory newMember = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil3,
            name: "Security Council Member 3"
        });
        
        vm.prank(owner);
        protocolStatus.addSecurityCouncilMember(newMember);
        
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        // New member should be able to deactivate
        vm.prank(securityCouncil3);
        protocolStatus.deactivateProtocol();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }
}

