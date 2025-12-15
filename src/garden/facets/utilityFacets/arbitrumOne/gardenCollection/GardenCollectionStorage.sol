// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.31;

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

library GardenCollectionStorage {
    /// @notice Fixed storage slot for Garden Collection layout (unique label reduces collision risk).
    bytes32 internal constant GARDEN_COLLECTION_STORAGE_SLOT_POSITION = keccak256("gardenCollection.storage");

    string internal constant DEFAULT_NAME = "Toku";
    string internal constant DEFAULT_SYMBOL = "TOKU";

    // ========================================================================
    // Layout
    // ========================================================================

    /// @notice Layout for the Garden Collection Storage
    /// @dev The struct stores all Garden Collection state including name, symbol, owners, balances, and approvals
    struct Layout {
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
    /// @return l Storage reference to Layout
    function layout() internal pure returns (Layout storage l) {
        bytes32 position = GARDEN_COLLECTION_STORAGE_SLOT_POSITION;

        assembly {
            l.slot := position
        }
    }
}
