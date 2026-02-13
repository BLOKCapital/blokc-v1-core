// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { LibStorageSlot } from "../../../libraries/LibStorageSlot.sol";

/*###############################################################################

    @title OwnableStorage
    @author BLOK Capital DAO
    @notice Storage for the OwnershipFacet
    @dev This storage is used to store the ownership of the contract

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

library OwnershipStorage {
    /// @notice Layout for the OwnershipStorage
    /// @dev The struct stores the address of the owner
    struct Layout {
        /// @notice Address of the owner. When zero, no owner is set (renounced).
        address owner;
    }

    /// @notice Returns the storage pointer to the Ownership layout
    /// @dev Storage slot is derived from keccak256(bytes(type(OwnershipStorage).name))
    /// @return l Storage reference to Layout
    function layout() internal pure returns (Layout storage l) {
        bytes32 position = LibStorageSlot.deriveStorageSlot(type(OwnershipStorage).name);

        assembly {
            l.slot := position
        }
    }
}
