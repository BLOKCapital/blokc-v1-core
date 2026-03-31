// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { ProtocolStatusTestBase } from "../ProtocolStatusTestBase.sol";
import { ProtocolStatus } from "src/protocolStatus/ProtocolStatus.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";

contract ProtocolStatusUnitTest is ProtocolStatusTestBase {
    // ═════════════════════════════════════════════════════════════════
    //                     CONSTRUCTOR
    // ═════════════════════════════════════════════════════════════════

    function test_constructor_setsOwner() public view {
        assertEq(ps.owner(), owner);
    }

    function test_constructor_startsInactive() public view {
        assertEq(uint256(ps.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }

    function test_constructor_setsENSRegistry() public view {
        assertEq(address(ps.ENS_REGISTRY()), address(ensRegistry));
    }

    function test_constructor_noSCMsInitially() public view {
        IProtocolStatus.EnsMember[] memory members = ps.getSecurityCouncilMembers();
        assertEq(members.length, 0);
    }

    function test_constructor_withBootstrapSCMs() public {
        ProtocolStatus psWithSCM = _deployWithOneSCM();
        IProtocolStatus.EnsMember[] memory members = psWithSCM.getSecurityCouncilMembers();
        assertEq(members.length, 1);
        assertEq(members[0].namehash, SCM1_NAMEHASH);
        assertEq(members[0].resolvedAddress, scm1Addr);
    }

    function test_constructor_revertsOnZeroENSRegistry() public {
        vm.expectRevert(abi.encodeWithSignature("ProtocolStatus_ZeroAddress()"));
        new ProtocolStatus(owner, address(0), new bytes32[](0), new string[](0), new uint256[](0));
    }

    function test_constructor_revertsOnMismatchedArrays() public {
        bytes32[] memory nh = new bytes32[](1);
        nh[0] = SCM1_NAMEHASH;
        vm.expectRevert(abi.encodeWithSignature("ProtocolStatus_EmptyArray()"));
        new ProtocolStatus(owner, address(ensRegistry), nh, new string[](0), new uint256[](0));
    }

    // ═════════════════════════════════════════════════════════════════
    //                     addSecurityCouncilMemberByEns
    // ═════════════════════════════════════════════════════════════════

    function test_addSCM_registersNewMember() public {
        _addSCM1();
        IProtocolStatus.EnsMember[] memory members = ps.getSecurityCouncilMembers();
        assertEq(members.length, 1);
        assertEq(members[0].namehash, SCM1_NAMEHASH);
    }

    function test_addSCM_memberIsActive() public {
        _addSCM1();
        assertTrue(ps.isSecurityCouncilMember(scm1Addr));
    }

    function test_addSCM_storesENSName() public {
        _addSCM1();
        assertEq(ps.getEnsName(SCM1_NAMEHASH), SCM1_NAME);
    }

    function test_addSCM_storesExpiry() public {
        _addSCM1();
        assertEq(ps.getExpiryTimestamp(SCM1_NAMEHASH), defaultExpiry);
    }

    function test_addSCM_storesResolvedAddress() public {
        _addSCM1();
        assertEq(ps.getResolvedAddress(SCM1_NAMEHASH), scm1Addr);
    }

    function test_addSCM_revertsOnZeroNamehash() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("ProtocolStatus_ZeroAddress()"));
        ps.addSecurityCouncilMemberByEns(bytes32(0), "zero", defaultExpiry);
    }

    function test_addSCM_revertsOnDuplicate() public {
        _addSCM1();
        vm.prank(owner);
        vm.expectRevert();
        ps.addSecurityCouncilMemberByEns(SCM1_NAMEHASH, SCM1_NAME, defaultExpiry);
    }

    function test_addSCM_revertsOnPastExpiry() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("ProtocolStatus_InvalidExpiry()"));
        ps.addSecurityCouncilMemberByEns(SCM1_NAMEHASH, SCM1_NAME, block.timestamp);
    }

    function test_addSCM_revertsOnZeroResolvedAddress() public {
        bytes32 badHash = keccak256("unresolvable.eth");
        // Not set in resolver → resolves to address(0)
        vm.prank(owner);
        vm.expectRevert();
        ps.addSecurityCouncilMemberByEns(badHash, "unresolvable.eth", defaultExpiry);
    }

    function test_addSCM_revertsWhenNotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        ps.addSecurityCouncilMemberByEns(SCM1_NAMEHASH, SCM1_NAME, defaultExpiry);
    }

    // ═════════════════════════════════════════════════════════════════
    //                     removeSecurityCouncilMemberByEns
    // ═════════════════════════════════════════════════════════════════

    function test_removeSCM_removesMember() public {
        _addSCM1();
        _removeSCM(SCM1_NAMEHASH);
        assertEq(ps.getSecurityCouncilMembers().length, 0);
        assertFalse(ps.isSecurityCouncilMember(scm1Addr));
    }

    function test_removeSCM_revertsOnNonMember() public {
        vm.prank(owner);
        vm.expectRevert();
        ps.removeSecurityCouncilMemberByEns(SCM1_NAMEHASH);
    }

    function test_removeSCM_revertsWhenNotOwner() public {
        _addSCM1();
        vm.prank(nonOwner);
        vm.expectRevert();
        ps.removeSecurityCouncilMemberByEns(SCM1_NAMEHASH);
    }

    // ═════════════════════════════════════════════════════════════════
    //                     extendScmExpiry
    // ═════════════════════════════════════════════════════════════════

    function test_extendExpiry_updatesExpiry() public {
        _addSCM1();
        uint256 newExpiry = defaultExpiry + 365 days;
        _extendExpiry(SCM1_NAMEHASH, newExpiry);
        assertEq(ps.getExpiryTimestamp(SCM1_NAMEHASH), newExpiry);
    }

    function test_extendExpiry_reactivatesAfterAddressChange() public {
        _addSCM1();

        // Change ENS address → SCM becomes ADDRESS_CHANGED
        _changeENSAddress(SCM1_NAMEHASH, alice);
        ps.syncResolution(SCM1_NAMEHASH);
        assertEq(uint256(ps.getScmStatus(SCM1_NAMEHASH)), uint256(IProtocolStatus.ScmStatus.ADDRESS_CHANGED));

        // Extend expiry → re-approves with new address
        uint256 newExpiry = defaultExpiry + 365 days;
        _extendExpiry(SCM1_NAMEHASH, newExpiry);
        assertEq(uint256(ps.getScmStatus(SCM1_NAMEHASH)), uint256(IProtocolStatus.ScmStatus.ACTIVE));
        assertEq(ps.getResolvedAddress(SCM1_NAMEHASH), alice);
    }

    function test_extendExpiry_revertsOnSameOrSmallerExpiry() public {
        _addSCM1();
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("ProtocolStatus_InvalidExpiry()"));
        ps.extendScmExpiry(SCM1_NAMEHASH, defaultExpiry);
    }

    function test_extendExpiry_revertsOnNonMember() public {
        vm.prank(owner);
        vm.expectRevert();
        ps.extendScmExpiry(SCM1_NAMEHASH, defaultExpiry + 1);
    }

    // ═════════════════════════════════════════════════════════════════
    //                     PROTOCOL STATE TRANSITIONS
    // ═════════════════════════════════════════════════════════════════

    function test_activateProtocol_fromInactive() public {
        _activate();
        assertEq(uint256(ps.getProtocolStatus()), uint256(IProtocolStatus.State.ACTIVE));
    }

    function test_activateProtocol_fromUpgradesDisabled() public {
        _activate();
        _disableUpgrades();
        _activate();
        assertEq(uint256(ps.getProtocolStatus()), uint256(IProtocolStatus.State.ACTIVE));
    }

    function test_activateProtocol_revertsWhenAlreadyActive() public {
        _activate();
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("ProtocolStatus_ProtocolIsAlreadyActive()"));
        ps.activateProtocol();
    }

    function test_activateProtocol_revertsWhenNotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        ps.activateProtocol();
    }

    function test_deactivateProtocol_fromActive() public {
        _activate();
        _deactivate();
        assertEq(uint256(ps.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }

    function test_deactivateProtocol_fromUpgradesDisabled() public {
        _activate();
        _disableUpgrades();
        _deactivate();
        assertEq(uint256(ps.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }

    function test_deactivateProtocol_revertsWhenAlreadyInactive() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("ProtocolStatus_ProtocolIsAlreadyInactive()"));
        ps.deactivateProtocol();
    }

    function test_disableUpgrades_fromActive() public {
        _activate();
        _disableUpgrades();
        assertEq(uint256(ps.getProtocolStatus()), uint256(IProtocolStatus.State.UPGRADES_DISABLED));
    }

    function test_disableUpgrades_revertsWhenNotActive() public {
        // Starts INACTIVE
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("ProtocolStatus_MustBeActiveToDisableUpgrades()"));
        ps.disableUpgrades();
    }

    // ═════════════════════════════════════════════════════════════════
    //                     SCM AUTHORIZATION
    // ═════════════════════════════════════════════════════════════════

    function test_scmCanDeactivateProtocol() public {
        _addSCM1();
        _activate();

        _deactivateAsSCM(scm1Addr);
        assertEq(uint256(ps.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }

    function test_scmCanDisableUpgrades() public {
        _addSCM1();
        _activate();

        vm.prank(scm1Addr);
        ps.disableUpgrades();
        assertEq(uint256(ps.getProtocolStatus()), uint256(IProtocolStatus.State.UPGRADES_DISABLED));
    }

    function test_scmCannotActivateProtocol() public {
        _addSCM1();
        // activateProtocol is onlyOwner, not onlyAuthorized
        vm.prank(scm1Addr);
        vm.expectRevert();
        ps.activateProtocol();
    }

    function test_expiredSCMCannotDeactivate() public {
        _addSCM1();
        _activate();

        // Warp past expiry
        vm.warp(defaultExpiry + 1);

        vm.prank(scm1Addr);
        vm.expectRevert(abi.encodeWithSignature("ProtocolStatus_Unauthorized()"));
        ps.deactivateProtocol();
    }

    function test_addressChangedSCMCannotDeactivate() public {
        _addSCM1();
        _activate();

        // Change ENS address
        _changeENSAddress(SCM1_NAMEHASH, alice);

        // Old address should be unauthorized
        vm.prank(scm1Addr);
        vm.expectRevert(abi.encodeWithSignature("ProtocolStatus_Unauthorized()"));
        ps.deactivateProtocol();
    }

    function test_unauthorizedCannotDeactivate() public {
        _activate();
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("ProtocolStatus_Unauthorized()"));
        ps.deactivateProtocol();
    }

    // ═════════════════════════════════════════════════════════════════
    //                     syncResolution
    // ═════════════════════════════════════════════════════════════════

    function test_syncResolution_detectsAddressChange() public {
        _addSCM1();
        _changeENSAddress(SCM1_NAMEHASH, alice);

        ps.syncResolution(SCM1_NAMEHASH);
        assertEq(uint256(ps.getScmStatus(SCM1_NAMEHASH)), uint256(IProtocolStatus.ScmStatus.ADDRESS_CHANGED));
    }

    function test_syncResolution_detectsExpiry() public {
        _addSCM1();
        vm.warp(defaultExpiry + 1);

        ps.syncResolution(SCM1_NAMEHASH);
        assertEq(uint256(ps.getScmStatus(SCM1_NAMEHASH)), uint256(IProtocolStatus.ScmStatus.EXPIRED));
    }

    function test_syncResolution_noChangeKeepsActive() public {
        _addSCM1();
        ps.syncResolution(SCM1_NAMEHASH);
        assertEq(uint256(ps.getScmStatus(SCM1_NAMEHASH)), uint256(IProtocolStatus.ScmStatus.ACTIVE));
    }

    function test_syncResolution_revertsOnNonMember() public {
        vm.expectRevert();
        ps.syncResolution(SCM1_NAMEHASH);
    }

    function test_syncResolution_callableByAnyone() public {
        _addSCM1();
        vm.prank(attacker);
        ps.syncResolution(SCM1_NAMEHASH); // should not revert
    }

    // ═════════════════════════════════════════════════════════════════
    //                     VIEW FUNCTIONS
    // ═════════════════════════════════════════════════════════════════

    function test_isSecurityCouncilMember_falseForNonMember() public view {
        assertFalse(ps.isSecurityCouncilMember(attacker));
    }

    function test_isSecurityCouncilMember_falseForExpired() public {
        _addSCM1();
        vm.warp(defaultExpiry + 1);
        assertFalse(ps.isSecurityCouncilMember(scm1Addr));
    }

    function test_getMemberName_returnsNameForSCM() public {
        _addSCM1();
        assertEq(ps.getMemberName(scm1Addr), SCM1_NAME);
    }

    function test_getMemberName_emptyForOwner() public view {
        assertEq(ps.getMemberName(owner), "");
    }

    function test_getMemberName_emptyForUnknown() public view {
        assertEq(ps.getMemberName(attacker), "");
    }

    function test_getResolvedAddress_returnsZeroForNonMember() public view {
        assertEq(ps.getResolvedAddress(keccak256("unknown")), address(0));
    }

    function test_getPreviousResolvedAddress_returnsZeroForNonMember() public view {
        assertEq(ps.getPreviousResolvedAddress(keccak256("unknown")), address(0));
    }

    function test_getExpiryTimestamp_returnsZeroForNonMember() public view {
        assertEq(ps.getExpiryTimestamp(keccak256("unknown")), 0);
    }

    function test_getEnsName_emptyForNonMember() public view {
        assertEq(ps.getEnsName(keccak256("unknown")), "");
    }

    function test_getScmStatus_revertsForNonMember() public {
        vm.expectRevert();
        ps.getScmStatus(keccak256("unknown"));
    }

    function test_getSecurityCouncilMembers_returnsAllMembers() public {
        _addSCM1();
        _addSCM2();

        IProtocolStatus.EnsMember[] memory members = ps.getSecurityCouncilMembers();
        assertEq(members.length, 2);
    }

    // ═════════════════════════════════════════════════════════════════
    //                     MULTIPLE SCMs
    // ═════════════════════════════════════════════════════════════════

    function test_multipleSCMs_bothCanDeactivate() public {
        _addSCM1();
        _addSCM2();
        _activate();

        _deactivateAsSCM(scm1Addr);
        assertEq(uint256(ps.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));

        _activate();
        _deactivateAsSCM(scm2Addr);
        assertEq(uint256(ps.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }

    function test_removeSCM_doesNotAffectOtherSCM() public {
        _addSCM1();
        _addSCM2();
        _removeSCM(SCM1_NAMEHASH);

        assertFalse(ps.isSecurityCouncilMember(scm1Addr));
        assertTrue(ps.isSecurityCouncilMember(scm2Addr));
    }
}
