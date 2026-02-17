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
import { LibDiamond } from "src/garden/libraries/LibDiamond.sol";

/// @notice Thrown when caller is not the diamond owner
error Garden_UnauthorizedCaller();

/// @notice Thrown when a function is called while the garden is connected to an index
error Garden_CannotCallIfConnectedToIndex();

/// @notice Thrown when a function is called while the garden is not an index garden
error Garden_NotAnIndexGarden();

/**
 * @title Facet
 * @notice Base contract for all facets in the garden diamond, providing common modifiers and access control logic.
 * This contract includes modifiers to restrict access to the garden owner and to prevent certain functions from
 * being called when the garden is connected to an index. It also allows for internal calls from the diamond itself
 * to support composability between facets.
 */
abstract contract Facet is ReentrancyGuard {
    /// @notice Restricts function access to the diamond contract owner
    /// @dev Checks msg.sender against owner stored in OwnershipStorage
    modifier onlyGardenOwner() {
        _onlyGardenOwner();
        _;
    }

    /// @notice Restricts function access if the garden is connected to an index
    /// @dev Checks if the connected index is set in the diamond storage
    modifier ifIndexNotConnected() {
        _ifIndexNotConnected();
        _;
    }

    /// @notice Checks if the caller is the garden owner
    /// @dev Also allows Diamond self-calls (msg.sender == address(this)) to support
    ///      internal facet composability (e.g. IndexFacet calling DEX facets during rebalance)
    function _onlyGardenOwner() internal view {
        if (msg.sender != OwnershipStorage.layout().owner && msg.sender != address(this)) {
            revert Garden_UnauthorizedCaller();
        }
    }

    /// @notice Checks if the garden is not connected to an index
    /// @dev Skips the check for Diamond self-calls to support internal facet composability
    ///      (e.g. IndexFacet calling DEX facets during rebalance)
    function _ifIndexNotConnected() internal view {
        if (msg.sender == address(this)) return;
        LibDiamond.Layout storage ld = LibDiamond.layout();
        if (ld.isConnectedToIndex) {
            revert Garden_CannotCallIfConnectedToIndex();
        }
    }
}
