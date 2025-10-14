// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/// @title ISBTCollection
/// @notice Minimal interface for an SBT collection used by the SbtFacet.
interface ISBTCollection {
    /// @notice Mint a new soulbound token to `to`.
    /// @dev Implementations are expected to enforce non-transferability and control minting.
    /// @param to Recipient of the minted SBT.
    /// @return tokenId The minted token id (optional for implementations).
    function mint(address to) external returns (uint256 tokenId);

    /// @notice Number of tokens owned by `owner`.
    function balanceOf(address owner) external view returns (uint256);
}
