// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.20;

/*###############################################################################

    @title OwnableStorage
    @author BLOK Capital DAO

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

library OwnershipStorage {
    /// @notice Fixed storage slot for ownable layout (unique label reduces collision risk).
    bytes32 internal constant OWNERSHIP_STORAGE_SLOT_POSITION = keccak256("ownership.storage");

    /**
     * @notice Layout describes persistent state for ownership.
     * @dev Keep this struct minimal. When adding new fields, preserve layout compatibility.
     */
    struct Layout {
        /// @notice Address of the owner. When zero, no owner is set (renounced).
        address owner;
    }

    /**
     * @notice Returns the storage pointer to the Ownership layout.
     * @dev Uses inline assembly to return a storage reference to the chosen slot.
     *      This pattern is standard for diamond/facet storage to prevent slot collisions.
     * @return l Storage reference to Layout.
     */
    function layout() internal pure returns (Layout storage l) {
        bytes32 position = OWNERSHIP_STORAGE_SLOT_POSITION;

        assembly {
            l.slot := position
        }
    }
}
