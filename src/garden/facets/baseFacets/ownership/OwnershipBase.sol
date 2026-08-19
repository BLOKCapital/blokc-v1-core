// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { OwnershipStorage } from "./OwnershipStorage.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";

/// @notice Thrown when attempting to transfer ownership to the zero address.
/// @dev The zero address would permanently lock all onlyGardenOwner functions
///      on the garden diamond (no recoverable owner), so it must be rejected.
error OwnershipBase_InvalidNewOwner(address newOwner);

/**
 * @title OwnershipBase
 * @notice Base contract that implements internal functions for ownership management according to the ERC-173 standard.
 * This contract is intended to be inherited by an OwnershipFacet that exposes the ownership functions with appropriate
 * access control.
 */
abstract contract OwnershipBase is IERC173 {
    /// @notice Transfers ownership of the contract to a new address
    /// @param _newOwner The address of the new owner
    /// @dev Reverts if `_newOwner` is the zero address — an ownerless garden would
    ///      permanently brick all onlyGardenOwner functions.
    function _transferOwnership(address _newOwner) internal {
        if (_newOwner == address(0)) revert OwnershipBase_InvalidNewOwner(_newOwner);
        OwnershipStorage.layout().owner = _newOwner;
        emit OwnershipTransferred(msg.sender, _newOwner);
    }

    /// @notice Retrieves the address of the current owner
    /// @return owner_ The address of the current owner, or address(0) if ownerless
    function _owner() internal view returns (address owner_) {
        owner_ = OwnershipStorage.layout().owner;
    }
}
