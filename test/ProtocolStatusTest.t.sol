// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
import "forge-std/Vm.sol";

import { ProtocolStatus } from "src/protocolStatus/ProtocolStatus.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";

import { MockENSRegistry, MockENSResolver } from "./Mocks.t.sol";

contract ProtocolStatusTest is Test {
    ProtocolStatus internal protocol;
    MockENSRegistry internal ens;
    MockENSResolver internal resolver1;
    MockENSResolver internal resolver2;

    address internal deployer = address(0xDEAD);
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal charlie = address(0xC0FFEE);

    bytes32 internal nhAlice;
    bytes32 internal nhBob;
    bytes32 internal nhCharlie;

    uint256 internal constant TWO_WEEKS = 2 weeks;

    /// events from interface/contract
    event SCMAddressChanged(
        bytes32 indexed namehash, string ensName, address oldAddress, address newAddress, uint256 timestamp
    );
    event SCMAction(address indexed scm, string action);
    event SCMUnauthorizedAttempt(address indexed caller, string attemptedAction);
    event SecurityCouncilMemberAdded(bytes32 indexed namehash, string ensName, address resolvedAddress, uint256 expiry);
    event SecurityCouncilMemberRemoved(bytes32 indexed namehash, string ensName);
    event SecurityCouncilMemberExpiryExtended(
        bytes32 indexed namehash, string ensName, uint256 oldExpiry, uint256 newExpiry
    );
    event ProtocolStatusChanged(
        IProtocolStatus.State oldStatus, IProtocolStatus.State newStatus, address changedBy, string name
    );

    function setUp() public {
        vm.startPrank(deployer);
        ens = new MockENSRegistry();
        resolver1 = new MockENSResolver();
        resolver2 = new MockENSResolver();

        nhAlice = keccak256(abi.encodePacked("alice.eth"));
        nhBob = keccak256(abi.encodePacked("bob.eth"));
        nhCharlie = keccak256(abi.encodePacked("charlie.eth"));

        ens.setResolver(nhAlice, address(resolver1));
        ens.setResolver(nhBob, address(resolver1));
        ens.setResolver(nhCharlie, address(resolver2));

        resolver1.setAddr(nhAlice, alice);
        resolver1.setAddr(nhBob, bob);
        resolver2.setAddr(nhCharlie, charlie);

        // Correct way: pass empty arrays inline
        protocol = new ProtocolStatus(address(ens), new bytes32[](0), new string[](0), new uint256[](0));

        vm.stopPrank();
    }

    // ---------- Helper: add SCM via owner (deployer) ----------
    function _addSCM(bytes32 namehash, string memory name, uint256 expiry, address asDeployer) internal {
        vm.prank(asDeployer);
        protocol.addSecurityCouncilMemberByENS(namehash, name, expiry);
    }

    // ---------- Test: add + view SCM ----------
    function testAddAndGetSCM() public {
        uint256 expiry = block.timestamp + TWO_WEEKS;
        vm.prank(deployer);
        vm.expectEmit(true, true, true, true);
        emit SecurityCouncilMemberAdded(nhAlice, "alice.eth", alice, expiry);
        protocol.addSecurityCouncilMemberByENS(nhAlice, "alice.eth", expiry);

        // get members returns the SCM with resolved address alice
        IProtocolStatus.ENSMember[] memory members = protocol.getSecurityCouncilMembers();
        assertEq(members.length, 1);
        assertEq(members[0].namehash, nhAlice);
        assertEq(members[0].ensName, "alice.eth");
        assertEq(members[0].resolvedAddress, alice);
        assertEq(members[0].expiryTimestamp, expiry);
        assertEq(uint256(members[0].status), uint256(IProtocolStatus.SCMStatus.ACTIVE));
    }

    // ---------- Only owner can add/remove/extend ----------
    function testOnlyOwnerCanManageSCM() public {
        uint256 expiry = block.timestamp + TWO_WEEKS;
        // bob cannot add
        vm.prank(bob);
        vm.expectRevert();
        protocol.addSecurityCouncilMemberByENS(nhBob, "bob.eth", expiry);

        // deployer can add
        vm.prank(deployer);
        protocol.addSecurityCouncilMemberByENS(nhBob, "bob.eth", expiry);

        // non-owner cannot remove
        vm.prank(bob);
        vm.expectRevert();
        protocol.removeSecurityCouncilMemberByENS(nhBob);

        // owner can remove
        vm.prank(deployer);
        vm.expectEmit(true, true, true, true);
        emit SecurityCouncilMemberRemoved(nhBob, "bob.eth");
        protocol.removeSecurityCouncilMemberByENS(nhBob);
    }

    // ---------- SCM can call deactivateProtocol and disableUpgrades; cannot activate ----------
    function testSCMPrivilegedActions() public {
        uint256 expiry = block.timestamp + TWO_WEEKS;
        _addSCM(nhAlice, "alice.eth", expiry, deployer);

        // Owner activates
        vm.prank(deployer);
        protocol.activateProtocol();

        // SCM can deactivate
        vm.prank(alice);
        protocol.deactivateProtocol();

        // Owner activates again
        vm.prank(deployer);
        protocol.activateProtocol();

        // SCM can disable upgrades
        vm.prank(alice);
        protocol.disableUpgrades();

        assertEq(uint256(protocol.getProtocolStatus()), uint256(IProtocolStatus.State.UPGRADES_DISABLED));

        // SCM cannot activate
        vm.prank(alice);
        vm.expectRevert();
        protocol.activateProtocol();
    }

    // ---------- ENS rotation detection on action (modifier path) ----------
    function testENSRotationDetectedAndEmittedOnAction() public {
        uint256 expiry = block.timestamp + TWO_WEEKS;
        // add alice
        vm.prank(deployer);
        protocol.addSecurityCouncilMemberByENS(nhAlice, "alice.eth", expiry);

        // change resolver's addr to new address (simulate ENS rotation)
        address newAlice = address(0xA1CE2);
        resolver1.setAddr(nhAlice, newAlice);

        // When alice (old address) attempts action, modifier should:
        // - detect change
        // - emit SCMAddressChanged
        // - then revert with unauthorized
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit SCMAddressChanged(nhAlice, "alice.eth", alice, newAlice, block.timestamp);
        vm.expectRevert(); // unauthorized
        protocol.deactivateProtocol();

        // After change, getSCMStatus should be ADDRESS_CHANGED
        IProtocolStatus.SCMStatus st = protocol.getSCMStatus(nhAlice);
        assertEq(uint256(st), uint256(IProtocolStatus.SCMStatus.ADDRESS_CHANGED));

        // New address cannot automatically act (must be reapproved)
        vm.prank(newAlice);
        vm.expectRevert();
        protocol.deactivateProtocol();
    }

    // ---------- syncResolution public function behavior ----------
    function testSyncResolutionEmitsAndUpdates() public {
        uint256 expiry = block.timestamp + TWO_WEEKS;
        vm.prank(deployer);
        protocol.addSecurityCouncilMemberByENS(nhBob, "bob.eth", expiry);

        // Change resolver
        address newBob = address(0xB0B2);
        resolver1.setAddr(nhBob, newBob);

        // Call syncResolution as a worker
        vm.prank(charlie);
        vm.expectEmit(true, true, true, true);
        emit SCMAddressChanged(nhBob, "bob.eth", bob, newBob, block.timestamp);
        protocol.syncResolution(nhBob);

        // status should be ADDRESS_CHANGED
        assertEq(uint256(protocol.getSCMStatus(nhBob)), uint256(IProtocolStatus.SCMStatus.ADDRESS_CHANGED));

        // owner re-approves via extendSCMExpiry -> re-activates and previousAddress updated
        uint256 newExpiry = block.timestamp + 4 weeks;
        vm.prank(deployer);
        vm.expectEmit(true, true, true, true);
        emit SecurityCouncilMemberExpiryExtended(nhBob, "bob.eth", expiry, newExpiry);
        protocol.extendSCMExpiry(nhBob, newExpiry);

        // now status should be ACTIVE and resolved address equals newBob
        assertEq(uint256(protocol.getSCMStatus(nhBob)), uint256(IProtocolStatus.SCMStatus.ACTIVE));
        assertEq(protocol.getResolvedAddress(nhBob), newBob);
        assertEq(protocol.getPreviousResolvedAddress(nhBob), newBob);
    }

    // ---------- expiry behaviour ----------
    function testExpiryRemovesAuthority() public {
        uint256 expiry = block.timestamp + 1 days;
        vm.prank(deployer);
        protocol.addSecurityCouncilMemberByENS(nhCharlie, "charlie.eth", expiry);

        // advance time past expiry
        vm.warp(expiry + 1);

        // charlie cannot act
        vm.prank(charlie);
        vm.expectEmit(true, true, true, true);
        // SCMUnauthorizedAttempt will be emitted by modifier
        emit SCMUnauthorizedAttempt(charlie, "deactivate protocol");
        vm.expectRevert();
        protocol.deactivateProtocol();

        // status should be EXPIRED
        assertEq(uint256(protocol.getSCMStatus(nhCharlie)), uint256(IProtocolStatus.SCMStatus.EXPIRED));

        // owner extends expiry to re-enable
        vm.prank(deployer);
        uint256 newExpiry = block.timestamp + 2 days;
        protocol.extendSCMExpiry(nhCharlie, newExpiry);

        assertEq(uint256(protocol.getSCMStatus(nhCharlie)), uint256(IProtocolStatus.SCMStatus.ACTIVE));
    }

    // ---------- unauthorized attempts emit and revert ----------
    function testUnauthorizedAttemptEmits() public {
        uint256 expiry = block.timestamp + TWO_WEEKS;
        vm.prank(deployer);
        protocol.addSecurityCouncilMemberByENS(nhAlice, "alice.eth", expiry);

        // unknown address tries to call
        vm.prank(address(0xBAD));
        vm.expectEmit(true, true, true, true);
        emit SCMUnauthorizedAttempt(address(0xBAD), "deactivate protocol");
        vm.expectRevert();
        protocol.deactivateProtocol();
    }

    // ---------- owner always allowed ----------
    function testOwnerAlwaysAllowed() public {
        // owner (deployer) can call deactivate/activate at any time
        vm.prank(deployer);
        protocol.activateProtocol();

        assertEq(uint256(protocol.getProtocolStatus()), uint256(IProtocolStatus.State.ACTIVE));

        vm.prank(deployer);
        protocol.deactivateProtocol();
        assertEq(uint256(protocol.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }

    // ---------- getSecurityCouncilMembers returns proper metadata ----------
    function testGetSecurityCouncilMembersMetadata() public {
        uint256 expiryA = block.timestamp + TWO_WEEKS;
        uint256 expiryB = block.timestamp + 3 days;

        vm.prank(deployer);
        protocol.addSecurityCouncilMemberByENS(nhAlice, "alice.eth", expiryA);

        vm.prank(deployer);
        protocol.addSecurityCouncilMemberByENS(nhBob, "bob.eth", expiryB);

        IProtocolStatus.ENSMember[] memory members = protocol.getSecurityCouncilMembers();
        assertEq(members.length, 2);

        // Find alice record
        bool foundAlice = false;
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].namehash == nhAlice) {
                foundAlice = true;
                assertEq(members[i].ensName, "alice.eth");
                assertEq(members[i].resolvedAddress, alice);
                assertEq(uint256(members[i].status), uint256(IProtocolStatus.SCMStatus.ACTIVE));
            }
        }
        assertTrue(foundAlice);
    }

    // ---------- helper sanity test: multiple SCMs and action rights ----------
    function testMultipleSCMsAndActions() public {
        uint256 expiryA = block.timestamp + TWO_WEEKS;
        uint256 expiryB = block.timestamp + TWO_WEEKS;

        vm.prank(deployer);
        protocol.addSecurityCouncilMemberByENS(nhAlice, "alice.eth", expiryA);

        vm.prank(deployer);
        protocol.addSecurityCouncilMemberByENS(nhBob, "bob.eth", expiryB);

        // alice and bob can both call disableUpgrades (when ACTIVE)
        vm.prank(deployer);
        protocol.activateProtocol();

        vm.prank(alice);
        protocol.disableUpgrades();

        // After disableUpgrades (UPGRADES_DISABLED), trying again should revert for SCM due checks
        vm.prank(bob);
        vm.expectRevert();
        protocol.disableUpgrades();
    }
}
