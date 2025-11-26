//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title Facet
    @author BLOK Capital DAO
    @notice Abstract base contract providing common functionality for all facets
    @dev All facets should inherit from this contract to access the following:
         - Reentrancy protection using ReentrancyGuardUpgradeable
         - Owner-only access control using onlyDiamondOwner modifier
         - Diamond storage pattern to access ownership state

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { OwnershipStorage } from "src/diamond/facets/baseFacets/ownership/OwnershipStorage.sol";
import { LibDiamond } from "src/diamond/libraries/LibDiamond.sol";

/// @notice Thrown when caller is not the diamond owner
error Diamond_UnauthorizedCaller();

/// @notice Thrown when a function is called while the garden is connected to an index
error Facet_CannotCallIfConnectedToIndex();

abstract contract Facet is ReentrancyGuardUpgradeable {
    /// @notice Restricts function access to the diamond contract owner
    /// @dev Checks msg.sender against owner stored in OwnershipStorage
    modifier onlyDiamondOwner() {
        if (msg.sender != OwnershipStorage.layout().owner) {
            revert Diamond_UnauthorizedCaller();
        }
        _;
    }

    /// @notice Restricts function access if the garden is connected to an index
    /// @dev Checks if the connected index is set in the diamond storage
    modifier ifIndexNotConnected() {
        LibDiamond.Layout storage ld = LibDiamond.layout();
        if (ld.isConnectedToIndex) {
            revert Facet_CannotCallIfConnectedToIndex();
        }
        _;
    }
}
