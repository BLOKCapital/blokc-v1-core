// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Facet } from "src/garden/facets/Facet.sol";
import {
    RewardCollectionBase
} from "src/garden/facets/utilityFacets/arbitrumOne/rewardCollection/RewardCollectionBase.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {
    RewardCollectionStorage
} from "src/garden/facets/utilityFacets/arbitrumOne/rewardCollection/RewardCollectionStorage.sol";

/// @title RewardCollectionFacet
/// @author BLOK Capital DAO
/// @notice Diamond facet exposing ERC-721 reward collection functionality for Gardens
/// @dev Implements IERC721 and IERC721Metadata on top of RewardCollectionBase,
///      making the Garden diamond itself an NFT collection
contract RewardCollectionFacet is RewardCollectionBase, Facet {
    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public pure override(IERC165) returns (bool) {
        return _supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC721
    function balanceOf(address owner) public view override returns (uint256) {
        return _balanceOf(owner);
    }

    /// @inheritdoc IERC721
    function ownerOf(uint256 tokenId) public view override returns (address) {
        return _ownerOf(tokenId);
    }

    /// @inheritdoc IERC721
    function approve(address to, uint256 tokenId) public override onlyGardenOwner {
        _approve(to, tokenId, msg.sender);
    }

    /// @inheritdoc IERC721
    function getApproved(uint256 tokenId) public view override returns (address) {
        _ownerOf(tokenId);
        return _getApproved(tokenId);
    }

    /// @inheritdoc IERC721
    function setApprovalForAll(address operator, bool approved) public override onlyGardenOwner {
        _setApprovalForAll(msg.sender, operator, approved);
    }

    /// @inheritdoc IERC721
    function isApprovedForAll(address owner, address operator) public view override returns (bool) {
        return _isApprovedForAll(owner, operator);
    }

    /// @inheritdoc IERC721
    function transferFrom(address from, address to, uint256 tokenId) public override onlyGardenOwner {
        _transferFrom(from, to, tokenId);
    }

    /// @inheritdoc IERC721
    function safeTransferFrom(address from, address to, uint256 tokenId) public override onlyGardenOwner {
        _safeTransferFrom(from, to, tokenId, "");
    }

    /// @inheritdoc IERC721
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    )
        public
        override
        onlyGardenOwner
    {
        _safeTransferFrom(from, to, tokenId, data);
    }

    // IERC721Metadata

    /// @inheritdoc IERC721Metadata
    function name() public pure override returns (string memory) {
        return _name();
    }

    /// @inheritdoc IERC721Metadata
    function symbol() public pure override returns (string memory) {
        return _symbol();
    }

    /// @inheritdoc IERC721Metadata
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return _tokenURI(tokenId);
    }

    /// @notice Returns the total number of minted reward tokens
    /// @return The total supply of tokens
    function totalSupply() public view returns (uint256) {
        return _totalSupply();
    }

    /// @notice Mints a new reward token to the contract itself
    /// @param tokenId The ID of the token to mint
    function mint(uint256 tokenId) public onlyGardenOwner {
        _mint(address(this), tokenId);
    }

    /// @notice Burns a reward token
    /// @param tokenId The ID of the token to burn
    function burn(uint256 tokenId) external onlyGardenOwner {
        _burn(tokenId);
    }
}
