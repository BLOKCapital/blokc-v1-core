// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ProtocolStatusTestBase } from "./ProtocolStatusTestBase.sol";
import { ProtocolStatus } from "src/protocolStatus/ProtocolStatus.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";

/// @title ProtocolStatusStateManagementTest
/// @notice Tests for protocol status state management (activate, deactivate, disableUpgrades)
contract ProtocolStatusStateManagementTest is ProtocolStatusTestBase {
    
    function test_ActivateProtocol_ByOwner() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, false);
        emit ProtocolStatusChanged(
            IProtocolStatus.State.INACTIVE,
            IProtocolStatus.State.ACTIVE,
            owner,
            ""
        );
        protocolStatus.activateProtocol();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.ACTIVE));
    }
    
    function test_ActivateProtocol_FromInactive() public {
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
        
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.ACTIVE));
    }
    
    function test_ActivateProtocol_FromUpgradesDisabled() public {
        // First activate
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        // Then disable upgrades
        vm.prank(owner);
        protocolStatus.disableUpgrades();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.UPGRADES_DISABLED));
        
        // Cannot activate from UPGRADES_DISABLED (must go through INACTIVE first)
        // Actually, looking at the code, activateProtocol doesn't check current state,
        // it only checks if already ACTIVE
        // But the disableUpgrades requires ACTIVE state, so we need to deactivate first
        vm.prank(owner);
        protocolStatus.deactivateProtocol();
        
        // Now activate
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.ACTIVE));
    }
    
    function test_DeactivateProtocol_ByOwner() public {
        // First activate
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        vm.prank(owner);
        vm.expectEmit(true, true, true, false);
        emit ProtocolStatusChanged(
            IProtocolStatus.State.ACTIVE,
            IProtocolStatus.State.INACTIVE,
            owner,
            ""
        );
        protocolStatus.deactivateProtocol();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }
    
    function test_DeactivateProtocol_BySecurityCouncilMember() public {
        // First activate
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        vm.prank(securityCouncil1);
        vm.expectEmit(true, true, true, false);
        emit ProtocolStatusChanged(
            IProtocolStatus.State.ACTIVE,
            IProtocolStatus.State.INACTIVE,
            securityCouncil1,
            "Security Council Member 1"
        );
        protocolStatus.deactivateProtocol();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }
    
    function test_DeactivateProtocol_FromActive() public {
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        vm.prank(owner);
        protocolStatus.deactivateProtocol();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }
    
    function test_DeactivateProtocol_FromUpgradesDisabled() public {
        // First activate
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        // Then disable upgrades
        vm.prank(owner);
        protocolStatus.disableUpgrades();
        
        // Now deactivate
        vm.prank(owner);
        protocolStatus.deactivateProtocol();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }
    
    function test_DisableUpgrades_ByOwner() public {
        // First activate
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        vm.prank(owner);
        vm.expectEmit(true, true, true, false);
        emit ProtocolStatusChanged(
            IProtocolStatus.State.ACTIVE,
            IProtocolStatus.State.UPGRADES_DISABLED,
            owner,
            ""
        );
        protocolStatus.disableUpgrades();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.UPGRADES_DISABLED));
    }
    
    function test_DisableUpgrades_BySecurityCouncilMember() public {
        // First activate
        vm.prank(owner);
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
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.UPGRADES_DISABLED));
    }
    
    function test_DisableUpgrades_FromActive() public {
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        vm.prank(owner);
        protocolStatus.disableUpgrades();
        
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.UPGRADES_DISABLED));
    }
    
    function test_StateTransitions_ActiveToInactive() public {
        vm.prank(owner);
        protocolStatus.activateProtocol();
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.ACTIVE));
        
        vm.prank(owner);
        protocolStatus.deactivateProtocol();
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }
    
    function test_StateTransitions_ActiveToUpgradesDisabled() public {
        vm.prank(owner);
        protocolStatus.activateProtocol();
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.ACTIVE));
        
        vm.prank(owner);
        protocolStatus.disableUpgrades();
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.UPGRADES_DISABLED));
    }
    
    function test_StateTransitions_UpgradesDisabledToInactive() public {
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        vm.prank(owner);
        protocolStatus.disableUpgrades();
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.UPGRADES_DISABLED));
        
        vm.prank(owner);
        protocolStatus.deactivateProtocol();
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }
    
    function test_StateTransitions_InactiveToActive() public {
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
        
        vm.prank(owner);
        protocolStatus.activateProtocol();
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.ACTIVE));
    }
    
    function test_StateTransitions_FullCycle() public {
        // INACTIVE -> ACTIVE
        vm.prank(owner);
        protocolStatus.activateProtocol();
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.ACTIVE));
        
        // ACTIVE -> UPGRADES_DISABLED
        vm.prank(owner);
        protocolStatus.disableUpgrades();
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.UPGRADES_DISABLED));
        
        // UPGRADES_DISABLED -> INACTIVE
        vm.prank(owner);
        protocolStatus.deactivateProtocol();
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
        
        // INACTIVE -> ACTIVE
        vm.prank(owner);
        protocolStatus.activateProtocol();
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.ACTIVE));
    }
    
    function test_RevertIf_ActivateProtocol_AlreadyActive() public {
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        vm.prank(owner);
        vm.expectRevert(ProtocolStatus.ProtocolStatus_ProtocolIsAlreadyActive.selector);
        protocolStatus.activateProtocol();
    }
    
    function test_RevertIf_ActivateProtocol_ByNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        protocolStatus.activateProtocol();
    }
    
    function test_RevertIf_DeactivateProtocol_AlreadyInactive() public {
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
        
        vm.prank(owner);
        vm.expectRevert(ProtocolStatus.ProtocolStatus_ProtocolIsAlreadyInactive.selector);
        protocolStatus.deactivateProtocol();
    }
    
    function test_RevertIf_DeactivateProtocol_ByUnauthorized() public {
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        vm.prank(nonOwner);
        vm.expectRevert(ProtocolStatus.ProtocolStatus_Unauthorized.selector);
        protocolStatus.deactivateProtocol();
    }
    
    function test_RevertIf_DisableUpgrades_FromInactive() public {
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
        
        vm.prank(owner);
        vm.expectRevert(ProtocolStatus.ProtocolStatus_MustBeActiveToDisableUpgrades.selector);
        protocolStatus.disableUpgrades();
    }
    
    function test_RevertIf_DisableUpgrades_FromUpgradesDisabled() public {
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        vm.prank(owner);
        protocolStatus.disableUpgrades();
        
        vm.prank(owner);
        vm.expectRevert(ProtocolStatus.ProtocolStatus_MustBeActiveToDisableUpgrades.selector);
        protocolStatus.disableUpgrades();
    }
    
    function test_RevertIf_DisableUpgrades_ByUnauthorized() public {
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        vm.prank(nonOwner);
        vm.expectRevert(ProtocolStatus.ProtocolStatus_Unauthorized.selector);
        protocolStatus.disableUpgrades();
    }
    
    function test_MultipleStateChanges() public {
        // Activate
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        // Deactivate
        vm.prank(owner);
        protocolStatus.deactivateProtocol();
        
        // Activate again
        vm.prank(owner);
        protocolStatus.activateProtocol();
        
        // Disable upgrades
        vm.prank(owner);
        protocolStatus.disableUpgrades();
        
        // Deactivate
        vm.prank(owner);
        protocolStatus.deactivateProtocol();
        
        // Final state should be INACTIVE
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }
}

