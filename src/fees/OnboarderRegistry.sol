// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▛▀▜▌▐▛▚▖     ▐▌   ▐▌ ▐▌▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IOnboarderRegistry } from "../interfaces/IOnboarderRegistry.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when the zero address is passed as an onboarder
/// @param onboarder The invalid address
error OnboarderRegistry_InvalidOnboarderAddress(address onboarder);

/// @notice Thrown when attempting to add an already-registered onboarder
/// @param onboarder The already-registered address
error OnboarderRegistry_AlreadyRegistered(address onboarder);

/// @notice Thrown when attempting to remove an unregistered onboarder
/// @param onboarder The unregistered address
error OnboarderRegistry_NotRegistered(address onboarder);

/// @notice Thrown when renounceOwnership is called (disabled to prevent permanent lockout)
error OnboarderRegistry_CannotRenounceOwnership();

/**
 * @title OnboarderRegistry
 * @notice DAO-voted allowlist of community members eligible to be bound as the onboarder of an
 *         Index Garden connection session. Only addresses on this list may be passed as the
 *         onboarder at connect — this is what prevents an investor writing arbitrary addresses
 *         (including their own) in as onboarder.
 */
contract OnboarderRegistry is IOnboarderRegistry, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _onboarders;

    event OnboarderAdded(address indexed onboarder);
    event OnboarderRemoved(address indexed onboarder);

    /// @notice Constructs the OnboarderRegistry
    /// @param initialOwner Address of the contract owner
    constructor(address initialOwner) Ownable(initialOwner) { }

    /// @notice Adds an address to the onboarder allowlist
    function addOnboarder(address onboarder) external onlyOwner {
        if (onboarder == address(0)) revert OnboarderRegistry_InvalidOnboarderAddress(onboarder);
        if (!_onboarders.add(onboarder)) revert OnboarderRegistry_AlreadyRegistered(onboarder);
        emit OnboarderAdded(onboarder);
    }

    /// @notice Removes an address from the onboarder allowlist (existing sessions are
    ///         unaffected — the onboarder was bound and recorded at connect)
    function removeOnboarder(address onboarder) external onlyOwner {
        if (!_onboarders.remove(onboarder)) revert OnboarderRegistry_NotRegistered(onboarder);
        emit OnboarderRemoved(onboarder);
    }

    /// @notice Returns true if the address may be bound as an onboarder at connect
    function isOnboarderEligible(address onboarder) external view returns (bool) {
        return _onboarders.contains(onboarder);
    }

    /// @notice Returns all allowlisted onboarder addresses
    function getOnboarders() external view returns (address[] memory) {
        return _onboarders.values();
    }

    /// @notice Returns the allowlist size
    function getOnboarderCount() external view returns (uint256) {
        return _onboarders.length();
    }

    /// @notice Renounce ownership is disabled to prevent permanent lockout
    /// @inheritdoc Ownable
    function renounceOwnership() public pure override {
        revert OnboarderRegistry_CannotRenounceOwnership();
    }
}
