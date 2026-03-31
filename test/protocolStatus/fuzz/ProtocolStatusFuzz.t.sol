// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { ProtocolStatusTestBase } from "../ProtocolStatusTestBase.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";

contract ProtocolStatusFuzzTest is ProtocolStatusTestBase {
    // ═════════════════════════════════════════════════════════════════
    //                  FUZZ — SCM add with valid expiry
    // ═════════════════════════════════════════════════════════════════

    function testFuzz_addSCM_validExpiryRegistersSuccessfully(uint256 expiryOffset) public {
        expiryOffset = bound(expiryOffset, 1, 365 days * 10);
        uint256 expiry = block.timestamp + expiryOffset;

        _addSCM(SCM1_NAMEHASH, SCM1_NAME, expiry);

        assertTrue(ps.isSecurityCouncilMember(scm1Addr));
        assertEq(ps.getExpiryTimestamp(SCM1_NAMEHASH), expiry);
    }

    function testFuzz_addSCM_pastOrCurrentExpiryAlwaysReverts(uint256 expiry) public {
        expiry = bound(expiry, 0, block.timestamp);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("ProtocolStatus_InvalidExpiry()"));
        ps.addSecurityCouncilMemberByEns(SCM1_NAMEHASH, SCM1_NAME, expiry);
    }

    // ═════════════════════════════════════════════════════════════════
    //                  FUZZ — SCM expiry behavior
    // ═════════════════════════════════════════════════════════════════

    function testFuzz_scmBecomesInactiveAfterExpiry(uint256 warpOffset) public {
        _addSCM1();
        assertTrue(ps.isSecurityCouncilMember(scm1Addr));

        // Warp to or past expiry
        warpOffset = bound(warpOffset, 0, 365 days * 10);
        vm.warp(defaultExpiry + warpOffset);

        assertFalse(ps.isSecurityCouncilMember(scm1Addr));
    }

    function testFuzz_scmStaysActiveBeforeExpiry(uint256 warpTo) public {
        _addSCM1();
        warpTo = bound(warpTo, block.timestamp, defaultExpiry - 1);
        vm.warp(warpTo);

        assertTrue(ps.isSecurityCouncilMember(scm1Addr));
    }

    // ═════════════════════════════════════════════════════════════════
    //                  FUZZ — extendScmExpiry
    // ═════════════════════════════════════════════════════════════════

    function testFuzz_extendExpiry_validExtensionSucceeds(uint256 extraTime) public {
        _addSCM1();
        extraTime = bound(extraTime, 1, 365 days * 10);
        uint256 newExpiry = defaultExpiry + extraTime;

        _extendExpiry(SCM1_NAMEHASH, newExpiry);
        assertEq(ps.getExpiryTimestamp(SCM1_NAMEHASH), newExpiry);
    }

    function testFuzz_extendExpiry_invalidExpiryAlwaysReverts(uint256 badExpiry) public {
        _addSCM1();
        badExpiry = bound(badExpiry, 0, defaultExpiry);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("ProtocolStatus_InvalidExpiry()"));
        ps.extendScmExpiry(SCM1_NAMEHASH, badExpiry);
    }

    // ═════════════════════════════════════════════════════════════════
    //                  FUZZ — ENS address change detection
    // ═════════════════════════════════════════════════════════════════

    function testFuzz_addressChange_detectsAndRevokesAuth(address newAddr) public {
        newAddr = _boundAddress(newAddr);
        vm.assume(newAddr != scm1Addr);

        _addSCM1();
        _changeENSAddress(SCM1_NAMEHASH, newAddr);

        // Old address loses membership
        assertFalse(ps.isSecurityCouncilMember(scm1Addr));
        // New address is not automatically authorized
        assertFalse(ps.isSecurityCouncilMember(newAddr));
    }

    function testFuzz_addressChange_extendReactivatesWithNewAddress(address newAddr) public {
        newAddr = _boundAddress(newAddr);
        vm.assume(newAddr != scm1Addr);

        _addSCM1();
        _changeENSAddress(SCM1_NAMEHASH, newAddr);
        ps.syncResolution(SCM1_NAMEHASH);

        // Extend expiry → re-approve with new address
        uint256 newExpiry = defaultExpiry + 365 days;
        _extendExpiry(SCM1_NAMEHASH, newExpiry);

        assertTrue(ps.isSecurityCouncilMember(newAddr));
        assertFalse(ps.isSecurityCouncilMember(scm1Addr));
    }

    // ═════════════════════════════════════════════════════════════════
    //                  FUZZ — protocol state transitions
    // ═════════════════════════════════════════════════════════════════

    function testFuzz_onlyOwnerCanActivate(address caller) public {
        caller = _boundAddress(caller);
        vm.assume(caller != owner);

        vm.prank(caller);
        vm.expectRevert();
        ps.activateProtocol();
    }

    function testFuzz_unauthorizedCannotDeactivate(address caller) public {
        caller = _boundAddress(caller);
        vm.assume(caller != owner);
        // No SCMs registered, so only owner can deactivate

        _activate();

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("ProtocolStatus_Unauthorized()"));
        ps.deactivateProtocol();
    }

    // ═════════════════════════════════════════════════════════════════
    //                  FUZZ — syncResolution idempotent
    // ═════════════════════════════════════════════════════════════════

    function testFuzz_syncResolution_idempotentOnNoChange(uint256 callCount) public {
        _addSCM1();
        callCount = bound(callCount, 1, 10);

        for (uint256 i = 0; i < callCount; i++) {
            ps.syncResolution(SCM1_NAMEHASH);
        }

        // Should still be active
        assertEq(uint256(ps.getScmStatus(SCM1_NAMEHASH)), uint256(IProtocolStatus.ScmStatus.ACTIVE));
    }
}
