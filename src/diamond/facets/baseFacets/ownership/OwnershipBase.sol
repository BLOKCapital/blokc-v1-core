// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title OwnershipBase
    @author BLOK Capital DAO
    @notice Base contract for OwnershipFacet

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import { OwnershipStorage } from "./OwnershipStorage.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";

abstract contract OwnershipBase is IERC173 {
    /**
     * @notice Transfer ownership of the contract to a new address
     * @dev Only the current owner can transfer ownership. The function emits an
     *      OwnershipTransferred event upon successful transfer.
     *
     *      WARNING: Transferring ownership to address(0) will renounce ownership,
     *      making the contract ownerless. This action is irreversible.
     *
     * @param _newOwner The address of the new owner. Can be address(0) to renounce ownership.
     */
    function _transferOwnership(address _newOwner) internal {
        OwnershipStorage.layout().owner = _newOwner;
        emit OwnershipTransferred(msg.sender, _newOwner);
    }

    /**
     * @notice Get the address of the current owner
     * @dev Returns the address that owns the diamond contract. Returns address(0)
     *      if ownership has been renounced.
     * @return The address of the current owner, or address(0) if ownerless
     */
    function _owner() internal view returns (address) {
        return OwnershipStorage.layout().owner;
    }
}
