// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { BaseTest } from "../base/BaseTest.sol";
import { ProtocolStatus } from "src/protocolStatus/ProtocolStatus.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";
import { MockENSRegistry, MockENSResolver } from "../mock/MockENS.sol";

/// @title ProtocolStatusTestBase
/// @notice Shared setup for ProtocolStatus tests.
///         Deploys MockENS (registry + resolver), configures SCM addresses,
///         and provides helpers for SCM management and protocol state transitions.
abstract contract ProtocolStatusTestBase is BaseTest {
    ProtocolStatus public ps;
    MockENSResolver public ensResolver;
    MockENSRegistry public ensRegistry;

    // ── SCM identities ──────────────────────────────────────────────
    bytes32 public constant SCM1_NAMEHASH = keccak256("scm1.eth");
    bytes32 public constant SCM2_NAMEHASH = keccak256("scm2.eth");
    bytes32 public constant SCM3_NAMEHASH = keccak256("scm3.eth");

    string public constant SCM1_NAME = "scm1.eth";
    string public constant SCM2_NAME = "scm2.eth";
    string public constant SCM3_NAME = "scm3.eth";

    address public scm1Addr = makeAddr("scm1Addr");
    address public scm2Addr = makeAddr("scm2Addr");
    address public scm3Addr = makeAddr("scm3Addr");

    uint256 public defaultExpiry;

    function setUp() public virtual override {
        super.setUp();

        // Warp to a sane timestamp so expiry math works
        vm.warp(1_000_000);
        defaultExpiry = block.timestamp + 365 days;

        // Deploy ENS mocks
        ensResolver = new MockENSResolver();
        ensRegistry = new MockENSRegistry(address(ensResolver));

        // Set up ENS resolution: namehash -> address
        ensResolver.setAddr(SCM1_NAMEHASH, scm1Addr);
        ensResolver.setAddr(SCM2_NAMEHASH, scm2Addr);
        ensResolver.setAddr(SCM3_NAMEHASH, scm3Addr);

        // Deploy ProtocolStatus with no bootstrap SCMs (starts INACTIVE)
        ps = _deployProtocolStatus(new bytes32[](0), new string[](0), new uint256[](0));
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     DEPLOYMENT HELPERS
    // ═══════════════════════════════════════════════════════════════════

    function _deployProtocolStatus(
        bytes32[] memory namehashes,
        string[] memory names,
        uint256[] memory expiries
    )
        internal
        returns (ProtocolStatus)
    {
        return new ProtocolStatus(owner, address(ensRegistry), namehashes, names, expiries);
    }

    /// @notice Deploy with a single bootstrap SCM
    function _deployWithOneSCM() internal returns (ProtocolStatus) {
        bytes32[] memory nh = new bytes32[](1);
        nh[0] = SCM1_NAMEHASH;
        string[] memory names = new string[](1);
        names[0] = SCM1_NAME;
        uint256[] memory expiries = new uint256[](1);
        expiries[0] = defaultExpiry;
        return _deployProtocolStatus(nh, names, expiries);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     SCM MANAGEMENT HELPERS
    // ═══════════════════════════════════════════════════════════════════

    function _addSCM(bytes32 namehash, string memory name, uint256 expiry) internal {
        vm.prank(owner);
        ps.addSecurityCouncilMemberByEns(namehash, name, expiry);
    }

    function _addSCM1() internal {
        _addSCM(SCM1_NAMEHASH, SCM1_NAME, defaultExpiry);
    }

    function _addSCM2() internal {
        _addSCM(SCM2_NAMEHASH, SCM2_NAME, defaultExpiry);
    }

    function _removeSCM(bytes32 namehash) internal {
        vm.prank(owner);
        ps.removeSecurityCouncilMemberByEns(namehash);
    }

    function _extendExpiry(bytes32 namehash, uint256 newExpiry) internal {
        vm.prank(owner);
        ps.extendScmExpiry(namehash, newExpiry);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                     PROTOCOL STATE HELPERS
    // ═══════════════════════════════════════════════════════════════════

    function _activate() internal {
        vm.prank(owner);
        ps.activateProtocol();
    }

    function _deactivate() internal {
        vm.prank(owner);
        ps.deactivateProtocol();
    }

    function _deactivateAsSCM(address scmAddr_) internal {
        vm.prank(scmAddr_);
        ps.deactivateProtocol();
    }

    function _disableUpgrades() internal {
        vm.prank(owner);
        ps.disableUpgrades();
    }

    /// @notice Change an SCM's ENS-resolved address in the mock resolver
    function _changeENSAddress(bytes32 namehash, address newAddr) internal {
        ensResolver.setAddr(namehash, newAddr);
    }
}
