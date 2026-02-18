// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { LibStorageSlot } from "./LibStorageSlot.sol";

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

/// @title LibDiamond
/// @author BLOK Capital DAO
/// @notice Core storage library for the Diamond proxy, holding registry addresses and garden metadata.
/// @dev Uses EIP-7201 namespaced storage via LibStorageSlot to avoid slot collisions.
library LibDiamond {
    /// @notice Persistent storage layout for a Diamond proxy instance.
    /// @param facetRegistry Address of the facet registry contract.
    /// @param protocolStatus Address of the protocol status contract.
    /// @param isConnectedToIndex Whether the diamond is connected to an index.
    /// @param gardenType The garden type identifier that determines which modules are allowed.
    struct Layout {
        address facetRegistry;
        address protocolStatus;
        bool isConnectedToIndex;
        bytes32 gardenType;
    }

    /// @notice Returns a reference to the diamond's namespaced storage layout.
    /// @dev Storage slot is derived from keccak256(bytes(type(LibDiamond).name)) with the low byte masked.
    /// @return l A storage pointer to the Layout struct.
    function layout() internal pure returns (Layout storage l) {
        bytes32 position = LibStorageSlot.deriveStorageSlot(type(LibDiamond).name);
        assembly {
            l.slot := position
        }
    }
}
