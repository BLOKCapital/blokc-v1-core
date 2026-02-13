// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.31;

import { LibStorageSlot } from "../../../../libraries/LibStorageSlot.sol";

/*###############################################################################

    @title GardenCollectionStorage
    @author BLOK Capital DAO
    @notice Storage for the Garden Collection Facet
    @dev This storage is used to store Garden Collection token state including name, symbol,
         owners, balances, and approvals

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

library RewardCollectionStorage {
    string internal constant DEFAULT_NAME = "Reward Token";
    string internal constant DEFAULT_SYMBOL = "RT";

    // ========================================================================
    // Layout
    // ========================================================================

    /// @notice Layout for the Garden Collection Storage
    /// @dev The struct stores all Garden Collection state including name, symbol, owners, balances, and approvals
    struct Layout {
        /// @notice Total supply of tokens
        uint256 totalSupply;
        /// @notice Mapping from token ID to owner address
        mapping(uint256 tokenId => address) owners;
        /// @notice Mapping from owner address to token count
        mapping(address owner => uint256) balances;
        /// @notice Mapping from token ID to approved address
        mapping(uint256 tokenId => address) tokenApprovals;
        /// @notice Mapping from owner to operator approvals
        mapping(address owner => mapping(address operator => bool)) operatorApprovals;
    }

    /// @notice Returns the storage pointer to the Garden Collection layout
    /// @dev Storage slot is derived from keccak256(bytes(type(RewardCollectionStorage).name))
    /// @return l Storage reference to Layout
    function layout() internal pure returns (Layout storage l) {
        bytes32 position = LibStorageSlot.deriveStorageSlot(type(RewardCollectionStorage).name);

        assembly {
            l.slot := position
        }
    }
}
