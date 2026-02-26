// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { LibStorageSlot } from "../../../libraries/LibStorageSlot.sol";

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

/// @title DiamondLoupeStorage
/// @author BLOK Capital DAO
/// @notice Storage for the DiamondLoupeFacet
/// @dev Stores the supported interfaces mapping for ERC-165 interface detection
library DiamondLoupeStorage {
    /// @notice Layout for the DiamondLoupeStorage
    /// @dev The map stores bytes4 -> bool for ERC-165 interface support
    struct Layout {
        /// @notice Mapping of interface IDs to boolean values
        mapping(bytes4 => bool) supportedInterfaces;
    }

    /// @notice Returns a pointer to the loupe storage layout
    /// @dev Storage slot is derived from keccak256(bytes(type(DiamondLoupeStorage).name))
    /// @return l Storage pointer to the loupe Storage struct
    function layout() internal pure returns (Layout storage l) {
        bytes32 position = LibStorageSlot.deriveStorageSlot(type(DiamondLoupeStorage).name);
        assembly {
            l.slot := position
        }
    }
}
