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

/**
 * @title OwnershipBase
 * @notice Base contract that implements internal functions for ownership management according to the ERC-173 standard.
 * This contract is intended to be inherited by an OwnershipFacet that exposes the ownership functions with appropriate
 * access control.
 */
abstract contract OwnershipBase is IERC173 {
    /// @notice Transfers ownership of the contract to a new address
    /// @param _newOwner The address of the new owner
    function _transferOwnership(address _newOwner) internal {
        OwnershipStorage.layout().owner = _newOwner;
        emit OwnershipTransferred(msg.sender, _newOwner);
    }

    /// @notice Retrieves the address of the current owner
    /// @return owner_ The address of the current owner, or address(0) if ownerless
    function _owner() internal view returns (address owner_) {
        owner_ = OwnershipStorage.layout().owner;
    }
}
