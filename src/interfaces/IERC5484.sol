// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

/// @title IERC5484
/// @notice Interface of the ERC-5484 standard for Consensual Soulbound Tokens.
/// @dev See https://eips.ethereum.org/EIPS/eip-5484.
interface IERC5484 {
    /// @notice Enumerates the burn authorization modes for a soulbound token.
    /// @dev `IssuerOnly` — only the issuer can burn.
    ///      `OwnerOnly` — only the token owner can burn.
    ///      `Both` — either the issuer or the owner can burn.
    ///      `Neither` — the token is permanently non-burnable.
    enum BurnAuth {
        IssuerOnly,
        OwnerOnly,
        Both,
        Neither
    }

    /// @notice Emitted when a soulbound token is issued.
    /// @dev Supplements the ERC-721 `Transfer` event to distinguish SBTs from transferable NFTs
    ///      while maintaining backward compatibility.
    /// @param from The issuer address.
    /// @param to The receiver address.
    /// @param tokenId The identifier of the issued token.
    /// @param burnAuth The burn authorization mode assigned to the token.
    event Issued(address indexed from, address indexed to, uint256 indexed tokenId, BurnAuth burnAuth);

    /// @notice Returns the burn authorization mode for a given token.
    /// @dev Reverts if `tokenId` has not been issued.
    /// @param tokenId The identifier of the token to query.
    /// @return The `BurnAuth` value assigned to the token.
    function burnAuth(uint256 tokenId) external view returns (BurnAuth);
}
