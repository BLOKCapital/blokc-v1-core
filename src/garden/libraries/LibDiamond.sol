// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { LibStorageSlot } from "./LibStorageSlot.sol";

/*###############################################################################

    @title LibDiamond
    @author BLOK Capital DAO
    @notice Library for the Diamond contract

################################################################################*/

library LibDiamond {
    struct Layout {
        //facet registry address
        address facetRegistry;
        // protocol status address
        address protocolStatus;
        // whether the diamond is connected to an index
        bool isConnectedToIndex;
    }

    /// @dev Storage slot is derived from keccak256(bytes(type(LibDiamond).name))
    function layout() internal pure returns (Layout storage l) {
        bytes32 position = LibStorageSlot.deriveStorageSlot(type(LibDiamond).name);
        assembly {
            l.slot := position
        }
    }
}
