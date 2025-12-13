//SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

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

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { OwnershipStorage } from "src/garden/facets/baseFacets/ownership/OwnershipStorage.sol";
import { LibDiamond } from "src/garden/libraries/LibDiamond.sol";

/// @notice Thrown when caller is not the diamond owner
error Garden_UnauthorizedCaller();

/// @notice Thrown when a function is called while the garden is connected to an index
error Garden_CannotCallIfConnectedToIndex();

abstract contract Facet is ReentrancyGuard {
    /// @notice Restricts function access to the diamond contract owner
    /// @dev Checks msg.sender against owner stored in OwnershipStorage
    modifier onlyGardenOwner() {
        if (msg.sender != OwnershipStorage.layout().owner) {
            revert Garden_UnauthorizedCaller();
        }
        _;
    }

    /// @notice Restricts function access if the garden is connected to an index
    /// @dev Checks if the connected index is set in the diamond storage
    modifier ifIndexNotConnected() {
        LibDiamond.Layout storage ld = LibDiamond.layout();
        if (ld.isConnectedToIndex) {
            revert Garden_CannotCallIfConnectedToIndex();
        }
        _;
    }
}
