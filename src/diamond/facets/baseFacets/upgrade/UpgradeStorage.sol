// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.20;

/*###############################################################################

    @title UpgradeStorage
    @author BLOK Capital DAO
    @notice Storage for the UpgradeFacet
    @dev This storage is used to store the upgrade version of the diamond

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

library UpgradeStorage {
    /// @notice Fixed storage slot for ownable layout (unique label reduces collision risk).
    bytes32 internal constant UPGRADE_STORAGE_SLOT_POSITION = keccak256("upgrade.storage");

    /// @notice Layout for the UpgradeStorage
    /// @dev The struct stores the diamond version
    struct Layout {
        uint256 diamondVersion;
    }

    /// @notice Returns the storage pointer to the Upgrade layout
    /// @return l Storage reference to Layout
    function layout() internal pure returns (Layout storage l) {
        bytes32 position = UPGRADE_STORAGE_SLOT_POSITION;

        assembly {
            l.slot := position
        }
    }
}
