// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

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
    State private _protocolStatus;
    IENSRegistry public immutable ENS_REGISTRY;

    struct ScmInternal {
        bytes32 namehash;
        string ensName;
        uint256 expiryTimestamp;
        uint256 addedAt;
        address previousAddress;
        IProtocolStatus.ScmStatus status;
    }

    EnumerableSet.Bytes32Set private _namehashes;
    mapping(bytes32 => ScmInternal) private _scm;

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
    // EVENTS (interface defines ScmAddressChanged with timestamp)
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
        _onlyAuthorized(actionName);
        _;
    }

    function _onlyAuthorized(string memory actionName) internal {
        if (msg.sender == owner()) {
            emit ScmAction(msg.sender, actionName);
            return;
        }

        uint256 len = _namehashes.length();
        for (uint256 i = 0; i < len; i++) {
            bytes32 nh = _namehashes.at(i);
            ScmInternal storage m = _scm[nh];

            // if expired, skip (but status may be updated by syncResolution too)
            if (block.timestamp >= m.expiryTimestamp) {
                if (m.status != ScmStatus.EXPIRED) m.status = ScmStatus.EXPIRED;
                continue;
            }

            address resolved = _resolve(nh);

            // If resolved differs from previously approved address, detect & handle it.
            if (resolved != m.previousAddress) {
                // mark as address changed (and emit event) if not already marked
                if (m.status != ScmStatus.ADDRESS_CHANGED) {
                    _handleEnsChange(nh, m, resolved);
                }
                continue; // changed addresses cannot be active
            }

            // status must be ACTIVE to allow
            if (m.status != ScmStatus.ACTIVE) continue;

            // if resolved matches caller -> authorized
            if (resolved == msg.sender) {
                emit ScmAction(msg.sender, actionName);

                return;
            }
        }

        // none matched
        emit ScmUnauthorizedAttempt(msg.sender, actionName);
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
        address initialOwner,
        address _ensRegistry,
        bytes32[] memory initialNamehashes,
        string[] memory initialNames,
        uint256[] memory initialExpiries
    )
        Ownable(initialOwner)
    {
        if (_ensRegistry == address(0)) revert ProtocolStatus_ZeroAddress();
        ENS_REGISTRY = IENSRegistry(_ensRegistry);

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

            _namehashes.add(node);
            _scm[node] = ScmInternal({
                namehash: node,
                ensName: n,
                expiryTimestamp: expiry,
                addedAt: block.timestamp,
                previousAddress: resolved,
                status: ScmStatus.ACTIVE
            });

            emit SecurityCouncilMemberAdded(node, n, resolved, expiry);
        }

        _protocolStatus = State.INACTIVE;
        emit ProtocolStatusChanged(State.ACTIVE, State.INACTIVE, msg.sender, "");
    }

    // ------------------------------------------------------------------------
    // DAO-ONLY MEMBERSHIP
    // ------------------------------------------------------------------------
    function addSecurityCouncilMemberByEns(
        bytes32 namehash,
        string calldata ensName,
        uint256 expiryTimestamp
    )
        external
        override
        onlyOwner
    {
        if (namehash == bytes32(0)) revert ProtocolStatus_ZeroAddress();
        if (_namehashes.contains(namehash)) revert ProtocolStatus_ENSAlreadyMember(namehash, ensName);
        if (expiryTimestamp <= block.timestamp) revert ProtocolStatus_InvalidExpiry();

        address resolved = _resolve(namehash);
        if (resolved == address(0)) revert ProtocolStatus_ENSNotMember(namehash, ensName);

        _namehashes.add(namehash);
        _scm[namehash] = ScmInternal({
            namehash: namehash,
            ensName: ensName,
            expiryTimestamp: expiryTimestamp,
            addedAt: block.timestamp,
            previousAddress: resolved,
            status: ScmStatus.ACTIVE
        });

        emit SecurityCouncilMemberAdded(namehash, ensName, resolved, expiryTimestamp);
        emit ScmAction(msg.sender, "add SCM");
    }

    function removeSecurityCouncilMemberByEns(bytes32 namehash) external override onlyOwner {
        if (!_namehashes.contains(namehash)) revert ProtocolStatus_NotMember(namehash);

        string memory n = _scm[namehash].ensName;
        _namehashes.remove(namehash);
        delete _scm[namehash];

        emit SecurityCouncilMemberRemoved(namehash, n);
        emit ScmAction(msg.sender, "remove SCM");
    }

    /**
     * DAO re-approval: extend expiry and mark ACTIVE (updates previousAddress to current resolver)
     */
    function extendScmExpiry(bytes32 namehash, uint256 newExpiry) external override onlyOwner {
        if (!_namehashes.contains(namehash)) revert ProtocolStatus_NotMember(namehash);
        ScmInternal storage m = _scm[namehash];
        if (newExpiry <= m.expiryTimestamp || newExpiry <= block.timestamp) revert ProtocolStatus_InvalidExpiry();

        uint256 old = m.expiryTimestamp;
        m.expiryTimestamp = newExpiry;

        // re-activate and set previousAddress to current resolved (DAO approves current owner)
        address resolved = _resolve(namehash);
        m.previousAddress = resolved;
        m.status = ScmStatus.ACTIVE;

        emit SecurityCouncilMemberExpiryExtended(namehash, m.ensName, old, newExpiry);
        emit ScmAction(msg.sender, "extend SCM expiry / reapprove");
    }

    // ------------------------------------------------------------------------
    // PROTOCOL MANAGEMENT
    // ------------------------------------------------------------------------
    function activateProtocol() external override onlyOwner {
        State currentStatus = _protocolStatus;
        if (currentStatus == State.ACTIVE) revert ProtocolStatus_ProtocolIsAlreadyActive();
        _protocolStatus = State.ACTIVE;
        emit ProtocolStatusChanged(currentStatus, State.ACTIVE, msg.sender, _getMemberName(msg.sender));
        emit ScmAction(msg.sender, "activate protocol");
    }

    function deactivateProtocol() external override onlyAuthorized("deactivate protocol") {
        State currentStatus = _protocolStatus;
        if (currentStatus == State.INACTIVE) revert ProtocolStatus_ProtocolIsAlreadyInactive();
        _protocolStatus = State.INACTIVE;
        emit ProtocolStatusChanged(currentStatus, State.INACTIVE, msg.sender, _getMemberName(msg.sender));
    }

    function disableUpgrades() external override onlyAuthorized("disable upgrades") {
        State currentStatus = _protocolStatus;
        if (currentStatus != State.ACTIVE) revert ProtocolStatus_MustBeActiveToDisableUpgrades();
        _protocolStatus = State.UPGRADES_DISABLED;
        emit ProtocolStatusChanged(currentStatus, State.UPGRADES_DISABLED, msg.sender, _getMemberName(msg.sender));
    }

    // ------------------------------------------------------------------------
    // SYNC (public) — proactive detection by worker/off-chain
    // Anyone (worker/DAO/offchain) can call this to update state and emit events.
    // ------------------------------------------------------------------------
    function syncResolution(bytes32 namehash) external {
        if (!_namehashes.contains(namehash)) revert ProtocolStatus_NotMember(namehash);
        ScmInternal storage m = _scm[namehash];

        // Expiry check
        if (block.timestamp >= m.expiryTimestamp) {
            if (m.status != ScmStatus.EXPIRED) {
                m.status = ScmStatus.EXPIRED;
            }
            return;
        }

        address resolved = _resolve(namehash);
        if (resolved != m.previousAddress) {
            // handle change
            _handleEnsChange(namehash, m, resolved);
        }
    }

    // ------------------------------------------------------------------------
    // VIEWS
    // ------------------------------------------------------------------------
    function getSecurityCouncilMembers() external view override returns (EnsMember[] memory) {
        uint256 count = _namehashes.length();
        EnsMember[] memory arr = new EnsMember[](count);
        for (uint256 i = 0; i < count; i++) {
            bytes32 node = _namehashes.at(i);
            ScmInternal storage s = _scm[node];
            address resolved = _resolve(node);
            arr[i] = EnsMember({
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
        return _protocolStatus;
    }

    function isSecurityCouncilMember(address member) external view override returns (bool) {
        return _isActiveScm(member);
    }

    function getMemberName(address member) external view override returns (string memory) {
        return _getMemberName(member);
    }

    function getResolvedAddress(bytes32 namehash) external view override returns (address) {
        if (!_namehashes.contains(namehash)) return address(0);
        return _resolve(namehash);
    }

    function getPreviousResolvedAddress(bytes32 namehash) external view override returns (address) {
        if (!_namehashes.contains(namehash)) return address(0);
        return _scm[namehash].previousAddress;
    }

    function getScmStatus(bytes32 namehash) external view override returns (ScmStatus) {
        if (!_namehashes.contains(namehash)) revert ProtocolStatus_NotMember(namehash);
        address r = _resolve(namehash);
        return _computeStatus(namehash, r);
    }

    function getExpiryTimestamp(bytes32 namehash) external view override returns (uint256) {
        if (!_namehashes.contains(namehash)) return 0;
        return _scm[namehash].expiryTimestamp;
    }

    function getEnsName(bytes32 namehash) external view override returns (string memory) {
        if (!_namehashes.contains(namehash)) return "";
        return _scm[namehash].ensName;
    }

    // ------------------------------------------------------------------------
    // INTERNAL HELPERS
    // ------------------------------------------------------------------------
    function _resolve(bytes32 n) internal view returns (address) {
        address resolver = ENS_REGISTRY.resolver(n);
        if (resolver == address(0)) return address(0);
        return IENSResolver(resolver).addr(n);
    }

    /**
     * _handleEnsChange:
     * - emits ScmAddressChanged(namehash, ensName, oldAddr, newAddr, timestamp)
     * - sets status = ADDRESS_CHANGED
     * - does NOT overwrite previousAddress (keeps last DAO-approved address)
     */
    function _handleEnsChange(bytes32 namehash, ScmInternal storage m, address newResolved) internal {
        address old = m.previousAddress;
        // mark as address changed
        m.status = ScmStatus.ADDRESS_CHANGED;
        // emit with timestamp
        emit ScmAddressChanged(namehash, m.ensName, old, newResolved, block.timestamp);
    }

    function _computeStatus(bytes32 namehash, address resolved) internal view returns (ScmStatus) {
        ScmInternal storage s = _scm[namehash];
        if (block.timestamp >= s.expiryTimestamp) return ScmStatus.EXPIRED;
        if (s.status == ScmStatus.ADDRESS_CHANGED) return ScmStatus.ADDRESS_CHANGED;
        if (resolved == address(0)) return ScmStatus.ADDRESS_CHANGED;
        if (resolved != s.previousAddress) return ScmStatus.ADDRESS_CHANGED;
        return ScmStatus.ACTIVE;
    }

    function _isActiveScm(address addr) internal view returns (bool) {
        uint256 len = _namehashes.length();
        for (uint256 i = 0; i < len; i++) {
            bytes32 nh = _namehashes.at(i);
            ScmInternal storage m = _scm[nh];
            if (block.timestamp >= m.expiryTimestamp) continue;
            address resolved = _resolve(nh);
            if (resolved == address(0)) continue;
            if (resolved != m.previousAddress) continue;
            if (m.status != ScmStatus.ACTIVE) continue;
            if (resolved == addr) return true;
        }
        return false;
    }

    function _getMemberName(address addr) internal view returns (string memory) {
        if (addr == owner()) return ""; // owner has no ENS name in this contract
        uint256 len = _namehashes.length();
        for (uint256 i = 0; i < len; i++) {
            bytes32 n = _namehashes.at(i);
            address resolved = _resolve(n);
            if (resolved == addr) return _scm[n].ensName;
        }
        return "";
    }
}
