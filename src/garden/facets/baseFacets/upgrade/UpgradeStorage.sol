// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { LibStorageSlot } from "../../../libraries/LibStorageSlot.sol";

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

/// @title UpgradeStorage
/// @author BLOK Capital DAO
/// @notice Storage for the UpgradeFacet
/// @dev Tracks per-module versions for determining which modules need upgrading
library UpgradeStorage {
    /// @notice Layout for the UpgradeStorage
    /// @dev Tracks per-module versions only. Upgrade logic is driven by module versions;
    ///      the garden installs only modules allowed for its type
    uint256 internal constant STORAGE_LAYOUT_VERSION = 1;

    struct Layout {
        /// @notice Storage layout version — MUST be first field. Validated during upgrades.
        uint256 _storageLayoutVersion;
        /// @notice When true and garden is connected to an index, anyone can call upgrade().
        ///         When false (default), only the garden owner can upgrade regardless of index connection.
        bool autoUpgradeEnabled;
        mapping(bytes32 => uint256) moduleVersions;
    }

    /// @notice Returns the storage pointer to the Upgrade layout
    /// @dev Storage slot is derived from keccak256(bytes(type(UpgradeStorage).name))
    /// @return l Storage reference to Layout
    function layout() internal pure returns (Layout storage l) {
        bytes32 position = LibStorageSlot.deriveStorageSlot(type(UpgradeStorage).name);

        assembly {
            l.slot := position
        }
    }
}
