// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.20;

/*###############################################################################

    @title UpgradeStorage
    @author BLOK Capital DAO

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

library UpgradeStorage {
    /// @notice Fixed storage slot for ownable layout (unique label reduces collision risk).
    bytes32 internal constant UPGRADE_STORAGE_SLOT_POSITION = keccak256("upgrade.storage");

    /**
     * @notice Layout describes persistent state for ownership.
     * @dev Keep this struct minimal. When adding new fields, preserve layout compatibility.
     */
    struct Layout {
        uint256 diamondVersion;
    }

    /**
     * @notice Returns the storage pointer to the Upgrade layout.
     * @dev Uses inline assembly to return a storage reference to the chosen slot.
     *      This pattern is standard for diamond/facet storage to prevent slot collisions.
     * @return l Storage reference to Layout.
     */
    function layout() internal pure returns (Layout storage l) {
        bytes32 position = UPGRADE_STORAGE_SLOT_POSITION;

        assembly {
            l.slot := position
        }
    }
}
