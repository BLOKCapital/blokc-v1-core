// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.20;

/*###############################################################################

    @title DiamondLoupeStorage
    @author BLOK Capital DAO
    @notice Storage for the DiamondLoupeFacet
    @dev This storage is used to store the supported interfaces for the DiamondLoupeFacet

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

library DiamondLoupeStorage {
    /// @notice Fixed storage slot for loupe persistent state.
    bytes32 internal constant DIAMOND_LOUPE_STORAGE_POSITION = keccak256("diamond.loupe.storage");

    /// @notice Layout for the DiamondLoupeStorage
    /// @dev The map stores bytes4 -> bool for ERC-165 interface support
    struct Layout {
        /// @notice Mapping of interface IDs to boolean values
        mapping(bytes4 => bool) supportedInterfaces;
    }

    /// @notice Returns a pointer to the loupe storage layout
    /// @return l Storage pointer to the loupe Storage struct
    function layout() internal pure returns (Layout storage l) {
        bytes32 position = DIAMOND_LOUPE_STORAGE_POSITION;
        assembly {
            l.slot := position
        }
    }
}
