// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @title IENSRegistry
/// @notice Minimal interface for the ENS Registry to look up resolvers.
interface IENSRegistry {
    /// @notice Returns the resolver address for a given ENS node.
    /// @param node The ENS namehash of the domain.
    /// @return The resolver contract address.
    function resolver(bytes32 node) external view returns (address);
}

/// @title IENSResolver
/// @notice Minimal interface for an ENS Resolver to look up addresses.
interface IENSResolver {
    /// @notice Returns the address associated with an ENS node.
    /// @param node The ENS namehash of the domain.
    /// @return The resolved Ethereum address.
    function addr(bytes32 node) external view returns (address);
}

/// @title ProtocolStatus
/// @author BLOK Capital DAO
/// @notice Manages protocol-level state (active / upgrades-disabled / inactive) and Security
///         Council Members (SCMs) tracked via ENS. SCM authorization is verified on each
///         restricted call with real-time ENS resolution and expiry checks.
/// @dev SCMs are identified by ENS namehash. An SCM loses authorization immediately if:
///      - Their ENS-resolved address changes (detected at call time or via `syncResolution`).
///      - Their membership expires based on `expiryTimestamp`.
///      The DAO (owner) can re-approve an SCM by extending their expiry.
contract ProtocolStatus is IProtocolStatus, Ownable {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    // ------------------------------------------------------------------------
    // STORAGE
    // ------------------------------------------------------------------------

    /// @dev Current protocol state (ACTIVE, UPGRADES_DISABLED, or INACTIVE).
    State private _protocolStatus;

    /// @notice The immutable ENS registry used for SCM address resolution.
    IENSRegistry public immutable ENS_REGISTRY;

    /// @notice Internal representation of an SCM with mutable state fields.
    /// @param namehash ENS namehash of the SCM.
    /// @param ensName Human-readable ENS name.
    /// @param expiryTimestamp Timestamp after which the membership is expired.
    /// @param addedAt Timestamp when the SCM was added.
    /// @param previousAddress The last DAO-approved resolved address.
    /// @param status Current SCM status.
    struct ScmInternal {
        bytes32 namehash;
        string ensName;
        uint256 expiryTimestamp;
        uint256 addedAt;
        address previousAddress;
        IProtocolStatus.ScmStatus status;
    }

    /// @dev Set of registered SCM ENS namehashes.
    EnumerableSet.Bytes32Set private _namehashes;

    /// @dev Mapping from ENS namehash to internal SCM data.
    mapping(bytes32 => ScmInternal) private _scm;

    // ------------------------------------------------------------------------
    // ERRORS
    // ------------------------------------------------------------------------
    /// @notice Thrown when attempting to activate an already-active protocol.
    error ProtocolStatus_ProtocolIsAlreadyActive();

    /// @notice Thrown when attempting to deactivate an already-inactive protocol.
    error ProtocolStatus_ProtocolIsAlreadyInactive();

    /// @notice Thrown when a required address argument is the zero address.
    error ProtocolStatus_ZeroAddress();

    /// @notice Thrown when constructor arrays have mismatched or empty lengths.
    error ProtocolStatus_EmptyArray();

    /// @notice Thrown when attempting to add an ENS namehash that is already a member.
    /// @param namehash The ENS namehash of the duplicate member.
    /// @param name The human-readable ENS name.
    error ProtocolStatus_ENSAlreadyMember(bytes32 namehash, string name);

    /// @notice Thrown when the ENS namehash does not resolve to a valid address.
    /// @param namehash The ENS namehash that failed to resolve.
    /// @param name The human-readable ENS name.
    error ProtocolStatus_ENSNotMember(bytes32 namehash, string name);

    /// @notice Thrown when the ENS namehash is not a registered SCM.
    /// @param namehash The ENS namehash that is not a member.
    error ProtocolStatus_NotMember(bytes32 namehash);

    /// @notice Thrown when the caller is not authorized (neither owner nor active SCM).
    error ProtocolStatus_Unauthorized();

    /// @notice Thrown when a provided expiry timestamp is in the past or not greater than the current one.
    error ProtocolStatus_InvalidExpiry();

    /// @notice Thrown when attempting to disable upgrades while the protocol is not active.
    error ProtocolStatus_MustBeActiveToDisableUpgrades();

    // ------------------------------------------------------------------------
    // EVENTS (interface defines ScmAddressChanged with timestamp)
    // ------------------------------------------------------------------------
    /// @notice Emitted when the protocol state transitions.
    /// @param oldStatus The previous protocol state.
    /// @param newStatus The new protocol state.
    /// @param changedBy The address that triggered the change.
    /// @param name The ENS name of the caller (empty for owner).
    event ProtocolStatusChanged(
        State indexed oldStatus, State indexed newStatus, address indexed changedBy, string name
    );

    /// @notice Emitted when a new Security Council Member is added.
    /// @param namehash The ENS namehash of the new SCM.
    /// @param ensName The human-readable ENS name.
    /// @param resolvedAddress The current ENS-resolved address.
    /// @param expiry The membership expiry timestamp.
    event SecurityCouncilMemberAdded(bytes32 indexed namehash, string ensName, address resolvedAddress, uint256 expiry);

    /// @notice Emitted when a Security Council Member is removed.
    /// @param namehash The ENS namehash of the removed SCM.
    /// @param ensName The human-readable ENS name.
    event SecurityCouncilMemberRemoved(bytes32 indexed namehash, string ensName);

    /// @notice Emitted when an SCM's expiry is extended and membership re-approved.
    /// @param namehash The ENS namehash of the SCM.
    /// @param ensName The human-readable ENS name.
    /// @param oldExpiry The previous expiry timestamp.
    /// @param newExpiry The new expiry timestamp.
    event SecurityCouncilMemberExpiryExtended(
        bytes32 indexed namehash, string ensName, uint256 oldExpiry, uint256 newExpiry
    );

    // ------------------------------------------------------------------------
    // MODIFIER
    // ------------------------------------------------------------------------
    /// @notice Restricts access to the owner or an active SCM whose ENS resolution is current.
    /// @dev Performs real-time ENS resolution to detect address rotations. If the resolved
    ///      address differs from the DAO-approved address, the SCM is marked `ADDRESS_CHANGED`
    ///      and loses authorization immediately. Expired SCMs are also skipped.
    /// @param actionName A human-readable action label emitted in `ScmAction` events.
    modifier onlyAuthorized(string memory actionName) {
        _onlyAuthorized(actionName);
        _;
    }

    /// @dev Internal logic for the `onlyAuthorized` modifier.
    /// @param actionName Label for the action being authorized.
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
    /// @notice Initializes the protocol with an ENS registry and optional bootstrap SCMs.
    /// @dev The protocol starts in `INACTIVE` state. Bootstrap arrays must have equal length.
    /// @param initialOwner The address that will own this contract.
    /// @param _ensRegistry The ENS registry address used for SCM address resolution.
    /// @param initialNamehashes Array of ENS namehashes for bootstrap SCMs.
    /// @param initialNames Array of human-readable ENS names (parallel to namehashes).
    /// @param initialExpiries Array of expiry timestamps (parallel to namehashes).
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

    /// @inheritdoc IProtocolStatus
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

    /// @inheritdoc IProtocolStatus
    function removeSecurityCouncilMemberByEns(bytes32 namehash) external override onlyOwner {
        if (!_namehashes.contains(namehash)) revert ProtocolStatus_NotMember(namehash);

        string memory n = _scm[namehash].ensName;
        _namehashes.remove(namehash);
        delete _scm[namehash];

        emit SecurityCouncilMemberRemoved(namehash, n);
        emit ScmAction(msg.sender, "remove SCM");
    }

    /// @inheritdoc IProtocolStatus
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
    /// @inheritdoc IProtocolStatus
    function activateProtocol() external override onlyOwner {
        State currentStatus = _protocolStatus;
        if (currentStatus == State.ACTIVE) revert ProtocolStatus_ProtocolIsAlreadyActive();
        _protocolStatus = State.ACTIVE;
        emit ProtocolStatusChanged(currentStatus, State.ACTIVE, msg.sender, _getMemberName(msg.sender));
        emit ScmAction(msg.sender, "activate protocol");
    }

    /// @inheritdoc IProtocolStatus
    function deactivateProtocol() external override onlyAuthorized("deactivate protocol") {
        State currentStatus = _protocolStatus;
        if (currentStatus == State.INACTIVE) revert ProtocolStatus_ProtocolIsAlreadyInactive();
        _protocolStatus = State.INACTIVE;
        emit ProtocolStatusChanged(currentStatus, State.INACTIVE, msg.sender, _getMemberName(msg.sender));
    }

    /// @inheritdoc IProtocolStatus
    function disableUpgrades() external override onlyAuthorized("disable upgrades") {
        State currentStatus = _protocolStatus;
        if (currentStatus != State.ACTIVE) revert ProtocolStatus_MustBeActiveToDisableUpgrades();
        _protocolStatus = State.UPGRADES_DISABLED;
        emit ProtocolStatusChanged(currentStatus, State.UPGRADES_DISABLED, msg.sender, _getMemberName(msg.sender));
    }

    // ------------------------------------------------------------------------
    // SYNC
    // ------------------------------------------------------------------------

    /// @notice Proactively syncs an SCM's ENS resolution and updates their status.
    /// @dev Can be called by anyone (off-chain worker, DAO, etc.) to detect ENS
    ///      address changes or expiry without waiting for the next authorized call.
    /// @param namehash The ENS namehash of the SCM to sync.
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
    /// @inheritdoc IProtocolStatus
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

    /// @inheritdoc IProtocolStatus
    function getProtocolStatus() external view override returns (State) {
        return _protocolStatus;
    }

    /// @inheritdoc IProtocolStatus
    function isSecurityCouncilMember(address member) external view override returns (bool) {
        return _isActiveScm(member);
    }

    /// @inheritdoc IProtocolStatus
    function getMemberName(address member) external view override returns (string memory) {
        return _getMemberName(member);
    }

    /// @inheritdoc IProtocolStatus
    function getResolvedAddress(bytes32 namehash) external view override returns (address) {
        if (!_namehashes.contains(namehash)) return address(0);
        return _resolve(namehash);
    }

    /// @inheritdoc IProtocolStatus
    function getPreviousResolvedAddress(bytes32 namehash) external view override returns (address) {
        if (!_namehashes.contains(namehash)) return address(0);
        return _scm[namehash].previousAddress;
    }

    /// @inheritdoc IProtocolStatus
    function getScmStatus(bytes32 namehash) external view override returns (ScmStatus) {
        if (!_namehashes.contains(namehash)) revert ProtocolStatus_NotMember(namehash);
        address r = _resolve(namehash);
        return _computeStatus(namehash, r);
    }

    /// @inheritdoc IProtocolStatus
    function getExpiryTimestamp(bytes32 namehash) external view override returns (uint256) {
        if (!_namehashes.contains(namehash)) return 0;
        return _scm[namehash].expiryTimestamp;
    }

    /// @inheritdoc IProtocolStatus
    function getEnsName(bytes32 namehash) external view override returns (string memory) {
        if (!_namehashes.contains(namehash)) return "";
        return _scm[namehash].ensName;
    }

    // ------------------------------------------------------------------------
    // INTERNAL HELPERS
    // ------------------------------------------------------------------------
    /// @dev Resolves an ENS namehash to an address via the ENS registry and resolver.
    /// @param n The ENS namehash to resolve.
    /// @return The resolved address, or `address(0)` if no resolver is set.
    function _resolve(bytes32 n) internal view returns (address) {
        address resolver = ENS_REGISTRY.resolver(n);
        if (resolver == address(0)) return address(0);
        return IENSResolver(resolver).addr(n);
    }

    /// @dev Handles an ENS address change for an SCM by marking them as `ADDRESS_CHANGED`
    ///      and emitting an event. Does NOT overwrite `previousAddress` (keeps the last
    ///      DAO-approved address for comparison).
    /// @param namehash The ENS namehash of the SCM.
    /// @param m The SCM's internal storage reference.
    /// @param newResolved The newly resolved address that differs from the approved one.
    function _handleEnsChange(bytes32 namehash, ScmInternal storage m, address newResolved) internal {
        address old = m.previousAddress;
        // mark as address changed
        m.status = ScmStatus.ADDRESS_CHANGED;
        // emit with timestamp
        emit ScmAddressChanged(namehash, m.ensName, old, newResolved, block.timestamp);
    }

    /// @dev Computes the current SCM status by checking expiry and ENS resolution.
    /// @param namehash The ENS namehash of the SCM.
    /// @param resolved The currently resolved address from ENS.
    /// @return The computed `ScmStatus`.
    function _computeStatus(bytes32 namehash, address resolved) internal view returns (ScmStatus) {
        ScmInternal storage s = _scm[namehash];
        if (block.timestamp >= s.expiryTimestamp) return ScmStatus.EXPIRED;
        if (s.status == ScmStatus.ADDRESS_CHANGED) return ScmStatus.ADDRESS_CHANGED;
        if (resolved == address(0)) return ScmStatus.ADDRESS_CHANGED;
        if (resolved != s.previousAddress) return ScmStatus.ADDRESS_CHANGED;
        return ScmStatus.ACTIVE;
    }

    /// @dev Checks whether an address corresponds to an active (non-expired, non-changed) SCM.
    /// @param addr The address to check.
    /// @return `true` if the address is an active SCM.
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

    /// @dev Returns the ENS name for a given address if it matches an SCM's resolved address.
    /// @param addr The address to look up.
    /// @return The ENS name, or an empty string if not found or if the address is the owner.
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
