// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.31;

/*###############################################################################

    @title ERC721Storage
    @author BLOK Capital DAO
    @notice Storage for the ERC721Facet
    @dev This storage is used to store ERC721 token state including name, symbol,
         owners, balances, and approvals

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

library ERC721Storage {
    /// @notice Fixed storage slot for ERC721 layout (unique label reduces collision risk).
    bytes32 internal constant ERC721_STORAGE_SLOT_POSITION = keccak256("erc721.storage");

    string internal constant DEFAULT_NAME = "Garden NFT";
    string internal constant DEFAULT_SYMBOL = "GARDEN";

    // ========================================================================
    // Layout
    // ========================================================================

    /// @notice Layout for the ERC721Storage
    /// @dev The struct stores all ERC721 state including name, symbol, owners, balances, and approvals
    struct Layout {
        /// @notice Mapping from token ID to owner address
        mapping(uint256 tokenId => address) owners;
        /// @notice Mapping from owner address to token count
        mapping(address owner => uint256) balances;
        /// @notice Mapping from token ID to approved address
        mapping(uint256 tokenId => address) tokenApprovals;
        /// @notice Mapping from owner to operator approvals
        mapping(address owner => mapping(address operator => bool)) operatorApprovals;
        /// @notice Mapping from interface ID to supported status
        mapping(bytes4 interfaceId => bool) supportsInterface;
    }

    /// @notice Returns the storage pointer to the ERC721 layout
    /// @return l Storage reference to Layout
    function layout() internal pure returns (Layout storage l) {
        bytes32 position = ERC721_STORAGE_SLOT_POSITION;

        assembly {
            l.slot := position
        }
    }
}
