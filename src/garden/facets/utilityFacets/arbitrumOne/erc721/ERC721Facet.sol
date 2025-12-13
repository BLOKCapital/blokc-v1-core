//SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    @title ERC721Facet
    @author BLOK Capital DAO
    @notice Facet exposing ERC721 functionality
    @dev This facet implements IERC721 and IERC721Metadata using the ERC721Base contract.
         Name and symbol are predefined in storage and can be set via setTokenMetadata.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import { Facet } from "src/garden/facets/Facet.sol";
import { ERC721Base } from "src/garden/facets/utilityFacets/arbitrumOne/erc721/ERC721Base.sol";
import { ERC721Storage } from "src/garden/facets/utilityFacets/arbitrumOne/erc721/ERC721Storage.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when attempting to mint a token that already exists
error ERC721Facet_TokenAlreadyExists(uint256 tokenId);

contract ERC721Facet is ERC721Base, Facet {
    // ========================================================================
    // IERC165 Implementation
    // ========================================================================

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        _supportsInterface(interfaceId);
    }

    // ========================================================================
    // IERC721 Implementation
    // ========================================================================

    /// @inheritdoc IERC721
    function balanceOf(address owner) public view override returns (uint256) {
        return _balanceOf(owner);
    }

    /// @inheritdoc IERC721
    function ownerOf(uint256 tokenId) public view override returns (address) {
        return _ownerOf(tokenId);
    }

    /// @inheritdoc IERC721
    function approve(address to, uint256 tokenId) public override {
        _approve(to, tokenId, msg.sender);
    }

    /// @inheritdoc IERC721
    function getApproved(uint256 tokenId) public view override returns (address) {
        _ownerOf(tokenId);
        return _getApproved(tokenId);
    }

    /// @inheritdoc IERC721
    function setApprovalForAll(address operator, bool approved) public override {
        _setApprovalForAll(msg.sender, operator, approved);
    }

    /// @inheritdoc IERC721
    function isApprovedForAll(address owner, address operator) public view override returns (bool) {
        return _isApprovedForAll(owner, operator);
    }

    /// @inheritdoc IERC721
    function transferFrom(address from, address to, uint256 tokenId) public override {
        _transferFrom(from, to, tokenId);
    }

    /// @inheritdoc IERC721
    function safeTransferFrom(address from, address to, uint256 tokenId) public override {
        _safeTransferFrom(from, to, tokenId, "");
    }

    /// @inheritdoc IERC721
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) public override {
        _safeTransferFrom(from, to, tokenId, data);
    }

    // ========================================================================
    // IERC721Metadata Implementation
    // ========================================================================

    /// @inheritdoc IERC721Metadata
    function name() public view override returns (string memory) {
        return _name();
    }

    /// @inheritdoc IERC721Metadata
    function symbol() public view override returns (string memory) {
        return _symbol();
    }

    /// @inheritdoc IERC721Metadata
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return _tokenURI(tokenId);
    }

    // ========================================================================
    // External Functions (State-Changing)
    // ========================================================================

    function mint(address to, uint256 tokenId) public onlyGardenOwner {
        _mint(to, tokenId);
    }

    /// @notice Burns a token
    /// @dev Only the diamond owner can burn tokens
    /// @param tokenId The token ID to burn
    function burn(uint256 tokenId) external onlyGardenOwner {
        _burn(tokenId);
    }
}
