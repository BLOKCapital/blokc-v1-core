// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { OwnershipStorage } from "src/garden/facets/baseFacets/ownership/OwnershipStorage.sol";
import { UpgradeStorage } from "src/garden/facets/baseFacets/upgrade/UpgradeStorage.sol";
import { LibDiamond } from "src/garden/libraries/LibDiamond.sol";

/// @notice Thrown when caller is not the diamond owner
error Garden_UnauthorizedCaller();

/// @notice Thrown when a function is called while the garden is connected to an index
error Garden_CannotCallIfConnectedToIndex();

/// @notice Thrown when a function is called while the garden is not an index garden
error Garden_NotAnIndexGarden();

/// @notice Thrown when a DEX function is called by someone other than the Garden itself while connected to an index
error Garden_OnlyGardenCanCallDexWhenIndexConnected();

/**
 * @title Facet
 * @notice Base contract for all facets in the garden diamond, providing common modifiers and access control logic.
 * This contract includes modifiers to restrict access to the garden owner, to prevent certain functions from
 * being called when the garden is connected to an index, and to enforce that DEX functions are only callable
 * via Diamond self-calls when connected to an index (to preserve token ratios).
 */
abstract contract Facet is ReentrancyGuard {
    /// @notice Restricts function access to the diamond contract owner
    /// @dev Checks msg.sender against owner stored in OwnershipStorage.
    modifier onlyGardenOwner() {
        _onlyGardenOwner();
        _;
    }

    /// @notice Restricts function access if the garden is connected to an index
    /// @dev Checks if the connected index is set in the diamond storage.
    ///      Used only by DiamondCutFacet and IndexFacet.connectToIndex.
    modifier ifIndexNotConnected() {
        _ifIndexNotConnected();
        _;
    }

    /// @notice Restricts DEX function access to the garden itself when connected to an index, otherwise restricts to
    /// garden owner @dev When connected to an index, only allows Diamond self-calls (msg.sender == address(this)) to
    /// support internal facet composability (e.g. IndexFacet calling DEX facets during rebalance). When not connected
    /// to an index, checks msg.sender against owner stored in OwnershipStorage.
    modifier onlyGardenCanCallDexWhenIndexConnected() {
        _onlyGardenCanCallDexWhenIndexConnected();
        _;
    }

    /// @notice Restricts function access to the garden owner unless the garden is connected to an index
    /// @dev When connected to an index, allows all callers. When not connected to an index, checks msg.sender against
    /// owner stored in OwnershipStorage.
    modifier onlyOwnerUnlessIndexConnected() {
        _onlyOwnerUnlessIndexConnected();
        _;
    }

    /// @notice Checks if the caller is the garden owner
    /// @dev Does NOT allow Diamond self-calls. For internal facet composability
    ///      (e.g. IndexFacet calling DEX facets during rebalance), use
    ///      onlyGardenCanCallDexWhenIndexConnected instead.
    function _onlyGardenOwner() internal view {
        if (msg.sender != OwnershipStorage.layout().owner) {
            revert Garden_UnauthorizedCaller();
        }
    }

    /// @notice Checks if the garden is not connected to an index
    /// @dev Blocks all external callers when connected to an index.
    ///      Used by DiamondCutFacet and IndexFacet.connectToIndex only.
    function _ifIndexNotConnected() internal view {
        if (msg.sender == address(this)) return;
        LibDiamond.Layout storage ld = LibDiamond.layout();
        if (ld.isConnectedToIndex) {
            revert Garden_CannotCallIfConnectedToIndex();
        }
    }

    /// @notice Checks if the caller is the garden itself when connected to an index,
    ///          otherwise checks if caller is garden owner
    function _onlyGardenCanCallDexWhenIndexConnected() internal view {
        LibDiamond.Layout storage ld = LibDiamond.layout();
        if (ld.isConnectedToIndex) {
            if (msg.sender != address(this)) {
                revert Garden_OnlyGardenCanCallDexWhenIndexConnected();
            }
        } else {
            if (msg.sender != OwnershipStorage.layout().owner) {
                revert Garden_UnauthorizedCaller();
            }
        }
    }

    /// @notice Checks if the caller is the garden owner unless the garden is connected to an index
    ///         AND the owner has opted into automatic upgrades via autoUpgradeEnabled.
    /// @dev When connected to an index, the owner must explicitly enable auto-upgrades before
    ///      non-owner callers can trigger them. This gives garden owners an inspection/delay window.
    function _onlyOwnerUnlessIndexConnected() internal view {
        LibDiamond.Layout storage ld = LibDiamond.layout();
        if (ld.isConnectedToIndex && UpgradeStorage.layout().autoUpgradeEnabled) {
            return;
        } else {
            if (msg.sender != OwnershipStorage.layout().owner) {
                revert Garden_UnauthorizedCaller();
            }
        }
    }
}
