// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.31;

import { LibStorageSlot } from "../../../libraries/LibStorageSlot.sol";

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
    /// @notice Layout for the UpgradeStorage
    /// @dev The struct stores the diamond version
    struct Layout {
        uint256 diamondVersion;
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
