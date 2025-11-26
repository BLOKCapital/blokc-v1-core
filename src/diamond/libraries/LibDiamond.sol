// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title LibDiamond
    @author BLOK Capital DAO
    @notice Library for the Diamond contract

################################################################################*/

library LibDiamond {
    bytes32 internal constant DIAMOND_STORAGE_POSITION = keccak256("diamond.storage");

    struct Layout {
        //facet registry address
        address facetRegistry;
        // protocol status address
        address protocolStatus;
        // whether the diamond is connected to an index
        bool isConnectedToIndex;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            l.slot := position
        }
    }
}
