// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.20;

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
    /// @notice Fixed storage slot for ownable layout (unique label reduces collision risk).
    bytes32 internal constant OWNERSHIP_STORAGE_SLOT_POSITION = keccak256("ownership.storage");

    /// @notice Layout for the OwnershipStorage
    /// @dev The struct stores the address of the owner
    struct Layout {
        /// @notice Address of the owner. When zero, no owner is set (renounced).
        address owner;
    }

    /// @notice Returns the storage pointer to the Ownership layout
    /// @return l Storage reference to Layout
    function layout() internal pure returns (Layout storage l) {
        bytes32 position = OWNERSHIP_STORAGE_SLOT_POSITION;

        assembly {
            l.slot := position
        }
    }
}
