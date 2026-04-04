// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { ProtocolStatusTestBase } from "../ProtocolStatusTestBase.sol";
import { ProtocolStatusHandler } from "./ProtocolStatusHandler.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";

contract ProtocolStatusInvariantTest is ProtocolStatusTestBase {
    ProtocolStatusHandler public handler;

    function setUp() public override {
        super.setUp();
        handler = new ProtocolStatusHandler(ps, ensResolver, owner);
        targetContract(address(handler));
    }

    // ═════════════════════════════════════════════════════════════════
    //                     SCM COUNT INVARIANT
    // ═════════════════════════════════════════════════════════════════

    /// @notice SCM member count must match ghost counter
    function invariant_scmCountMatchesGhost() public view {
        assertEq(ps.getSecurityCouncilMembers().length, handler.ghost_scmCount());
    }

    // ═════════════════════════════════════════════════════════════════
    //                     PROTOCOL STATE INVARIANTS
    // ═════════════════════════════════════════════════════════════════

    /// @notice Protocol state must always be one of the three valid states
    function invariant_protocolStateIsValid() public view {
        uint256 state = uint256(ps.getProtocolStatus());
        assertTrue(state <= 2); // ACTIVE=0, UPGRADES_DISABLED=1, INACTIVE=2
    }

    /// @notice Owner should never change (no transferOwnership called by handler)
    function invariant_ownerNeverChanges() public view {
        assertEq(ps.owner(), owner);
    }

    // ═════════════════════════════════════════════════════════════════
    //                     SCM REGISTRATION INVARIANT
    // ═════════════════════════════════════════════════════════════════

    /// @notice Ghost registration state must match contract for all tracked SCMs
    function invariant_registrationMatchesGhost() public view {
        for (uint256 i = 0; i < handler.MAX_SCMS(); i++) {
            bytes32 nh = handler.scmNamehashes(i);
            bool ghostRegistered = handler.ghost_isRegistered(nh);

            // Check if ENS name query returns non-empty for registered SCMs
            string memory name = ps.getEnsName(nh);
            if (ghostRegistered) {
                assertTrue(bytes(name).length > 0);
            } else {
                assertEq(bytes(name).length, 0);
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════
    //                     SCM STATUS INVARIANT
    // ═════════════════════════════════════════════════════════════════

    /// @notice Registered SCM status must be one of ACTIVE, EXPIRED, ADDRESS_CHANGED
    function invariant_scmStatusIsValid() public view {
        IProtocolStatus.EnsMember[] memory members = ps.getSecurityCouncilMembers();
        for (uint256 i = 0; i < members.length; i++) {
            uint256 status = uint256(members[i].status);
            assertTrue(status <= 2); // ACTIVE=0, EXPIRED=1, ADDRESS_CHANGED=2
        }
    }

    /// @notice Expired SCMs (past expiry) must report EXPIRED status
    function invariant_pastExpiryMeansExpiredStatus() public view {
        IProtocolStatus.EnsMember[] memory members = ps.getSecurityCouncilMembers();
        for (uint256 i = 0; i < members.length; i++) {
            if (block.timestamp >= members[i].expiryTimestamp) {
                assertEq(uint256(members[i].status), uint256(IProtocolStatus.ScmStatus.EXPIRED));
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════
    //                     ENS RESOLUTION INVARIANT
    // ═════════════════════════════════════════════════════════════════

    /// @notice ENS registry address must never change (immutable)
    function invariant_ensRegistryNeverChanges() public view {
        assertEq(address(ps.ENS_REGISTRY()), address(ensRegistry));
    }
}
