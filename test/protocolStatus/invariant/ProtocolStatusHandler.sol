// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Test } from "forge-std/Test.sol";
import { ProtocolStatus } from "src/protocolStatus/ProtocolStatus.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";
import { MockENSResolver } from "../../mock/MockENS.sol";

/// @title ProtocolStatusHandler
/// @notice Invariant handler for ProtocolStatus. Performs bounded SCM management
///         and protocol state actions, tracking ghost state.
contract ProtocolStatusHandler is Test {
    ProtocolStatus public ps;
    MockENSResolver public resolver;
    address public protocolOwner;

    // ── SCM pool
    // ────────────────────────────────────────────────────
    uint256 public constant MAX_SCMS = 5;
    bytes32[] public scmNamehashes;
    string[] public scmNames;
    address[] public scmAddrs;

    // ── Ghost state
    // ─────────────────────────────────────────────────
    uint256 public ghost_scmCount;
    mapping(bytes32 => bool) public ghost_isRegistered;
    uint256 public ghost_activateCalls;
    uint256 public ghost_deactivateCalls;

    constructor(ProtocolStatus ps_, MockENSResolver resolver_, address protocolOwner_) {
        ps = ps_;
        resolver = resolver_;
        protocolOwner = protocolOwner_;

        // Pre-build SCM identities
        for (uint256 i = 0; i < MAX_SCMS; i++) {
            bytes32 nh = keccak256(abi.encodePacked("handler-scm-", i));
            address addr = address(uint160(0x5000 + i));
            scmNamehashes.push(nh);
            scmNames.push(string(abi.encodePacked("handler-scm-", vm.toString(i))));
            scmAddrs.push(addr);

            // Register in resolver
            resolver.setAddr(nh, addr);
            vm.deal(addr, 1 ether);
        }
    }

    function addSCM(uint256 scmSeed) external {
        uint256 idx = scmSeed % MAX_SCMS;
        bytes32 nh = scmNamehashes[idx];
        if (ghost_isRegistered[nh]) return;

        uint256 expiry = block.timestamp + 365 days;

        vm.prank(protocolOwner);
        try ps.addSecurityCouncilMemberByEns(nh, scmNames[idx], expiry) {
            ghost_isRegistered[nh] = true;
            ghost_scmCount++;
        } catch { }
    }

    function removeSCM(uint256 scmSeed) external {
        uint256 idx = scmSeed % MAX_SCMS;
        bytes32 nh = scmNamehashes[idx];
        if (!ghost_isRegistered[nh]) return;

        vm.prank(protocolOwner);
        try ps.removeSecurityCouncilMemberByEns(nh) {
            ghost_isRegistered[nh] = false;
            ghost_scmCount--;
        } catch { }
    }

    function activateProtocol() external {
        vm.prank(protocolOwner);
        try ps.activateProtocol() {
            ghost_activateCalls++;
        } catch { }
    }

    function deactivateProtocol() external {
        vm.prank(protocolOwner);
        try ps.deactivateProtocol() {
            ghost_deactivateCalls++;
        } catch { }
    }

    function disableUpgrades() external {
        vm.prank(protocolOwner);
        try ps.disableUpgrades() { } catch { }
    }

    function syncResolution(uint256 scmSeed) external {
        uint256 idx = scmSeed % MAX_SCMS;
        bytes32 nh = scmNamehashes[idx];
        if (!ghost_isRegistered[nh]) return;

        try ps.syncResolution(nh) { } catch { }
    }

    function changeENSAddress(uint256 scmSeed, uint256 newAddrSeed) external {
        uint256 idx = scmSeed % MAX_SCMS;
        address newAddr = address(uint160(bound(newAddrSeed, 100, type(uint160).max)));
        resolver.setAddr(scmNamehashes[idx], newAddr);
    }

    function warpForward(uint256 seconds_) external {
        seconds_ = bound(seconds_, 1, 400 days);
        vm.warp(block.timestamp + seconds_);
    }
}
