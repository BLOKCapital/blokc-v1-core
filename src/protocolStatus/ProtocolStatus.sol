// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/*###############################################################################

    @title ProtocolStatus
    @author BLOK Capital DAO
    @notice Exposes functionality to manage the protocol status.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface IENSRegistry {
    function resolver(bytes32 node) external view returns (address);
}

interface IENSResolver {
    function addr(bytes32 node) external view returns (address);
}

contract ProtocolStatus is IProtocolStatus, Ownable {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    // ------------------------------------------------------------------------
    // STORAGE
    // ------------------------------------------------------------------------
    State private s_protocolStatus;
    IENSRegistry public immutable ensRegistry;

    struct SCMInternal {
        bytes32 namehash;
        string ensName;
        uint256 expiryTimestamp;
        uint256 addedAt;
        address previousAddress;
        IProtocolStatus.SCMStatus status;
    }

    EnumerableSet.Bytes32Set private s_namehashes;
    mapping(bytes32 => SCMInternal) private s_scm;

    // ------------------------------------------------------------------------
    // ERRORS
    // ------------------------------------------------------------------------
    error ProtocolStatus_ProtocolIsAlreadyActive();
    /// @notice Thrown when the protocol is already inactive
    error ProtocolStatus_ProtocolIsAlreadyInactive();
    /// @notice Thrown when the address is zero
    error ProtocolStatus_ZeroAddress();
    /// @notice Thrown when the array is empty
    error ProtocolStatus_EmptyArray();
    error ProtocolStatus_ENSAlreadyMember(bytes32 namehash, string name);
    error ProtocolStatus_ENSNotMember(bytes32 namehash, string name);
    error ProtocolStatus_NotMember(bytes32 namehash);
    error ProtocolStatus_Unauthorized();
    error ProtocolStatus_InvalidExpiry();
    error ProtocolStatus_MustBeActiveToDisableUpgrades();

    // ------------------------------------------------------------------------
    // EVENTS (interface defines SCMAddressChanged with timestamp)
    // ------------------------------------------------------------------------
    event ProtocolStatusChanged(
        State indexed oldStatus, State indexed newStatus, address indexed changedBy, string name
    );
    event SecurityCouncilMemberAdded(bytes32 indexed namehash, string ensName, address resolvedAddress, uint256 expiry);
    event SecurityCouncilMemberRemoved(bytes32 indexed namehash, string ensName);
    event SecurityCouncilMemberExpiryExtended(
        bytes32 indexed namehash, string ensName, uint256 oldExpiry, uint256 newExpiry
    );

    // ------------------------------------------------------------------------
    // MODIFIER
    // ------------------------------------------------------------------------
    /**
     * onlyAuthorized(actionName)
     * - If owner: allowed
     * - Otherwise: scans SCMs, performs ENS-change detection (stateful) and only allows call if caller
     *   resolves to an ACTIVE SCM (not expired and not address-changed).
     *
     * This ensures address-rotations are detected at the time of the call and SCM loses power immediately.
     */
    modifier onlyAuthorized(string memory actionName) {
        if (msg.sender == owner()) {
            emit SCMAction(msg.sender, actionName);
            _;
            return;
        }

        uint256 len = s_namehashes.length();
        for (uint256 i = 0; i < len; i++) {
            bytes32 nh = s_namehashes.at(i);
            SCMInternal storage m = s_scm[nh];

            // if expired, skip (but status may be updated by syncResolution too)
            if (block.timestamp >= m.expiryTimestamp) {
                if (m.status != SCMStatus.EXPIRED) m.status = SCMStatus.EXPIRED;
                continue;
            }

            address resolved = _resolve(nh);

            // If resolved differs from previously approved address, detect & handle it.
            if (resolved != m.previousAddress) {
                // mark as address changed (and emit event) if not already marked
                if (m.status != SCMStatus.ADDRESS_CHANGED) {
                    _handleENSChange(nh, m, resolved);
                }
                continue; // changed addresses cannot be active
            }

            // status must be ACTIVE to allow
            if (m.status != SCMStatus.ACTIVE) continue;

            // if resolved matches caller -> authorized
            if (resolved == msg.sender) {
                emit SCMAction(msg.sender, actionName);
                _;
                return;
            }
        }

        // none matched
        emit SCMUnauthorizedAttempt(msg.sender, actionName);
        revert ProtocolStatus_Unauthorized();
    }

    // ------------------------------------------------------------------------
    // CONSTRUCTOR
    // ------------------------------------------------------------------------
    /**
     * @param _ensRegistry ENS registry address on Arbitrum chain
     * @param initialNamehashes bootstrap (parallel arrays)
     */
    constructor(
        address _ensRegistry,
        bytes32[] memory initialNamehashes,
        string[] memory initialNames,
        uint256[] memory initialExpiries
    )
        Ownable(msg.sender)
    {
        if (_ensRegistry == address(0)) revert ProtocolStatus_ZeroAddress();
        ensRegistry = IENSRegistry(_ensRegistry);

        if (initialNamehashes.length != initialNames.length || initialNamehashes.length != initialExpiries.length) {
            if (initialNamehashes.length != 0) revert ProtocolStatus_EmptyArray();
        }

        for (uint256 i = 0; i < initialNamehashes.length; i++) {
            bytes32 node = initialNamehashes[i];
            string memory n = initialNames[i];
            uint256 expiry = initialExpiries[i];

            if (node == bytes32(0)) revert ProtocolStatus_ZeroAddress();
            if (expiry <= block.timestamp) revert ProtocolStatus_InvalidExpiry();

            address resolved = _resolve(node);
            if (resolved == address(0)) revert ProtocolStatus_ENSNotMember(node, n);

            s_namehashes.add(node);
            s_scm[node] = SCMInternal({
                namehash: node,
                ensName: n,
                expiryTimestamp: expiry,
                addedAt: block.timestamp,
                previousAddress: resolved,
                status: SCMStatus.ACTIVE
            });

            emit SecurityCouncilMemberAdded(node, n, resolved, expiry);
        }

        s_protocolStatus = State.INACTIVE;
        emit ProtocolStatusChanged(State.ACTIVE, State.INACTIVE, msg.sender, "");
    }

    // ------------------------------------------------------------------------
    // DAO-ONLY MEMBERSHIP
    // ------------------------------------------------------------------------
    function addSecurityCouncilMemberByENS(
        bytes32 namehash,
        string calldata ensName,
        uint256 expiryTimestamp
    )
        external
        override
        onlyOwner
    {
        if (namehash == bytes32(0)) revert ProtocolStatus_ZeroAddress();
        if (s_namehashes.contains(namehash)) revert ProtocolStatus_ENSAlreadyMember(namehash, ensName);
        if (expiryTimestamp <= block.timestamp) revert ProtocolStatus_InvalidExpiry();

        address resolved = _resolve(namehash);
        if (resolved == address(0)) revert ProtocolStatus_ENSNotMember(namehash, ensName);

        s_namehashes.add(namehash);
        s_scm[namehash] = SCMInternal({
            namehash: namehash,
            ensName: ensName,
            expiryTimestamp: expiryTimestamp,
            addedAt: block.timestamp,
            previousAddress: resolved,
            status: SCMStatus.ACTIVE
        });

        emit SecurityCouncilMemberAdded(namehash, ensName, resolved, expiryTimestamp);
        emit SCMAction(msg.sender, "add SCM");
    }

    function removeSecurityCouncilMemberByENS(bytes32 namehash) external override onlyOwner {
        if (!s_namehashes.contains(namehash)) revert ProtocolStatus_NotMember(namehash);

        string memory n = s_scm[namehash].ensName;
        s_namehashes.remove(namehash);
        delete s_scm[namehash];

        emit SecurityCouncilMemberRemoved(namehash, n);
        emit SCMAction(msg.sender, "remove SCM");
    }

    /**
     * DAO re-approval: extend expiry and mark ACTIVE (updates previousAddress to current resolver)
     */
    function extendSCMExpiry(bytes32 namehash, uint256 newExpiry) external override onlyOwner {
        if (!s_namehashes.contains(namehash)) revert ProtocolStatus_NotMember(namehash);
        SCMInternal storage m = s_scm[namehash];
        if (newExpiry <= m.expiryTimestamp || newExpiry <= block.timestamp) revert ProtocolStatus_InvalidExpiry();

        uint256 old = m.expiryTimestamp;
        m.expiryTimestamp = newExpiry;

        // re-activate and set previousAddress to current resolved (DAO approves current owner)
        address resolved = _resolve(namehash);
        m.previousAddress = resolved;
        m.status = SCMStatus.ACTIVE;

        emit SecurityCouncilMemberExpiryExtended(namehash, m.ensName, old, newExpiry);
        emit SCMAction(msg.sender, "extend SCM expiry / reapprove");
    }

    // ------------------------------------------------------------------------
    // PROTOCOL MANAGEMENT
    // ------------------------------------------------------------------------
    function activateProtocol() external override onlyOwner {
        State currentStatus = s_protocolStatus;
        if (currentStatus == State.ACTIVE) revert ProtocolStatus_ProtocolIsAlreadyActive();
        s_protocolStatus = State.ACTIVE;
        emit ProtocolStatusChanged(currentStatus, State.ACTIVE, msg.sender, _getMemberName(msg.sender));
        emit SCMAction(msg.sender, "activate protocol");
    }

    function deactivateProtocol() external override onlyAuthorized("deactivate protocol") {
        State currentStatus = s_protocolStatus;
        if (currentStatus == State.INACTIVE) revert ProtocolStatus_ProtocolIsAlreadyInactive();
        s_protocolStatus = State.INACTIVE;
        emit ProtocolStatusChanged(currentStatus, State.INACTIVE, msg.sender, _getMemberName(msg.sender));
    }

    function disableUpgrades() external override onlyAuthorized("disable upgrades") {
        State currentStatus = s_protocolStatus;
        if (currentStatus != State.ACTIVE) revert ProtocolStatus_MustBeActiveToDisableUpgrades();
        s_protocolStatus = State.UPGRADES_DISABLED;
        emit ProtocolStatusChanged(currentStatus, State.UPGRADES_DISABLED, msg.sender, _getMemberName(msg.sender));
    }

    // ------------------------------------------------------------------------
    // SYNC (public) — proactive detection by worker/off-chain
    // Anyone (worker/DAO/offchain) can call this to update state and emit events.
    // ------------------------------------------------------------------------
    function syncResolution(bytes32 namehash) external {
        if (!s_namehashes.contains(namehash)) revert ProtocolStatus_NotMember(namehash);
        SCMInternal storage m = s_scm[namehash];

        // Expiry check
        if (block.timestamp >= m.expiryTimestamp) {
            if (m.status != SCMStatus.EXPIRED) {
                m.status = SCMStatus.EXPIRED;
            }
            return;
        }

        address resolved = _resolve(namehash);
        if (resolved != m.previousAddress) {
            // handle change
            _handleENSChange(namehash, m, resolved);
        }
    }

    // ------------------------------------------------------------------------
    // VIEWS
    // ------------------------------------------------------------------------
    function getSecurityCouncilMembers() external view override returns (ENSMember[] memory) {
        uint256 count = s_namehashes.length();
        ENSMember[] memory arr = new ENSMember[](count);
        for (uint256 i = 0; i < count; i++) {
            bytes32 node = s_namehashes.at(i);
            SCMInternal storage s = s_scm[node];
            address resolved = _resolve(node);
            arr[i] = ENSMember({
                namehash: node,
                ensName: s.ensName,
                resolvedAddress: resolved,
                previousAddress: s.previousAddress,
                expiryTimestamp: s.expiryTimestamp,
                status: _computeStatus(node, resolved)
            });
        }
        return arr;
    }

    function getProtocolStatus() external view override returns (State) {
        return s_protocolStatus;
    }

    function isSecurityCouncilMember(address member) external view override returns (bool) {
        return _isActiveSCM(member);
    }

    function getMemberName(address member) external view override returns (string memory) {
        return _getMemberName(member);
    }

    function getResolvedAddress(bytes32 namehash) external view override returns (address) {
        if (!s_namehashes.contains(namehash)) return address(0);
        return _resolve(namehash);
    }

    function getPreviousResolvedAddress(bytes32 namehash) external view override returns (address) {
        if (!s_namehashes.contains(namehash)) return address(0);
        return s_scm[namehash].previousAddress;
    }

    function getSCMStatus(bytes32 namehash) external view override returns (SCMStatus) {
        if (!s_namehashes.contains(namehash)) revert ProtocolStatus_NotMember(namehash);
        address r = _resolve(namehash);
        return _computeStatus(namehash, r);
    }

    function getExpiryTimestamp(bytes32 namehash) external view override returns (uint256) {
        if (!s_namehashes.contains(namehash)) return 0;
        return s_scm[namehash].expiryTimestamp;
    }

    function getENSName(bytes32 namehash) external view override returns (string memory) {
        if (!s_namehashes.contains(namehash)) return "";
        return s_scm[namehash].ensName;
    }

    // ------------------------------------------------------------------------
    // INTERNAL HELPERS
    // ------------------------------------------------------------------------
    function _resolve(bytes32 n) internal view returns (address) {
        address resolver = ensRegistry.resolver(n);
        if (resolver == address(0)) return address(0);
        return IENSResolver(resolver).addr(n);
    }

    /**
     * _handleENSChange:
     * - emits SCMAddressChanged(namehash, ensName, oldAddr, newAddr, timestamp)
     * - sets status = ADDRESS_CHANGED
     * - does NOT overwrite previousAddress (keeps last DAO-approved address)
     */
    function _handleENSChange(bytes32 namehash, SCMInternal storage m, address newResolved) internal {
        address old = m.previousAddress;
        // mark as address changed
        m.status = SCMStatus.ADDRESS_CHANGED;
        // emit with timestamp
        emit SCMAddressChanged(namehash, m.ensName, old, newResolved, block.timestamp);
    }

    function _computeStatus(bytes32 namehash, address resolved) internal view returns (SCMStatus) {
        SCMInternal storage s = s_scm[namehash];
        if (block.timestamp >= s.expiryTimestamp) return SCMStatus.EXPIRED;
        if (s.status == SCMStatus.ADDRESS_CHANGED) return SCMStatus.ADDRESS_CHANGED;
        if (resolved == address(0)) return SCMStatus.ADDRESS_CHANGED;
        if (resolved != s.previousAddress) return SCMStatus.ADDRESS_CHANGED;
        return SCMStatus.ACTIVE;
    }

    function _isActiveSCM(address addr) internal view returns (bool) {
        uint256 len = s_namehashes.length();
        for (uint256 i = 0; i < len; i++) {
            bytes32 nh = s_namehashes.at(i);
            SCMInternal storage m = s_scm[nh];
            if (block.timestamp >= m.expiryTimestamp) continue;
            address resolved = _resolve(nh);
            if (resolved == address(0)) continue;
            if (resolved != m.previousAddress) continue;
            if (m.status != SCMStatus.ACTIVE) continue;
            if (resolved == addr) return true;
        }
        return false;
    }

    function _getMemberName(address addr) internal view returns (string memory) {
        if (addr == owner()) return ""; // owner has no ENS name in this contract
        uint256 len = s_namehashes.length();
        for (uint256 i = 0; i < len; i++) {
            bytes32 n = s_namehashes.at(i);
            address resolved = _resolve(n);
            if (resolved == addr) return s_scm[n].ensName;
        }
        return "";
    }
}
