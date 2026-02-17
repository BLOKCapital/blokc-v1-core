// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { IERC721Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { ERC721Utils } from "@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { IERC165 } from "src/interfaces/IERC165.sol";

import {
    RewardCollectionStorage
} from "src/garden/facets/utilityFacets/arbitrumOne/rewardCollection/RewardCollectionStorage.sol";

/// @notice Thrown when a query is made for a nonexistent token
error GardenCollectionBase_URIQueryForNonexistentToken();

/// @notice Thrown when attempting to mint a token that already exists
/// @param tokenId The ID of the token that already exists
error GardenCollectionFacet_TokenAlreadyExists(uint256 tokenId);

/// @title RewardCollectionBase
/// @author BLOK Capital DAO
/// @notice Base contract for the Garden reward collection ERC-721 integration
/// @dev Provides internal helpers for ERC-721 state management within the Diamond proxy
abstract contract RewardCollectionBase is IERC721, IERC721Metadata, IERC721Errors {
    using Strings for uint256;

    // CID for the rewards
    string constant REWARD_CID = "bafybeibamcvn4b6zioon65phe56u7bpnygvmi67qv2id6be5p4ybjgynju";

    /// @notice Gets the balance of an owner
    /// @param owner The address of the owner
    /// @return The balance of the owner
    function _balanceOf(address owner) internal view returns (uint256) {
        // Check if the owner is the zero address
        if (owner == address(0)) revert ERC721InvalidOwner(address(0));
        return RewardCollectionStorage.layout().balances[owner];
    }

    /// @notice Gets the owner of a token
    /// @param tokenId The ID of the token
    /// @return The owner of the token
    function _ownerOf(uint256 tokenId) internal view returns (address) {
        // Check if the token exists
        address owner = RewardCollectionStorage.layout().owners[tokenId];
        if (owner == address(0)) revert ERC721NonexistentToken(tokenId);
        return owner;
    }

    /// @notice Gets the name of the collection
    /// @return The name of the collection
    function _name() internal pure returns (string memory) {
        return RewardCollectionStorage.DEFAULT_NAME;
    }

    /// @notice Gets the symbol of the collection
    /// @return The symbol of the collection
    function _symbol() internal pure returns (string memory) {
        return RewardCollectionStorage.DEFAULT_SYMBOL;
    }

    /// @notice Gets the URI of a token
    /// @param tokenId The ID of the token
    /// @return The URI of the token as a base64-encoded JSON data URI
    function _tokenURI(uint256 tokenId) internal view returns (string memory) {
        // Check if the token exists
        address owner = RewardCollectionStorage.layout().owners[tokenId];
        if (owner == address(0)) revert GardenCollectionBase_URIQueryForNonexistentToken();

        // Get the ID of the token
        string memory id = Strings.toString(tokenId);
        // Get the video URI
        string memory video = string(abi.encodePacked("ipfs://", REWARD_CID, "/", id, ".png"));

        // Get the JSON URI
        bytes memory json = abi.encodePacked(
            "{",
            '"name":"Reward #',
            id,
            '",',
            '"description":"Official Reward Soulbound Token - Proof of contribution on Block",',
            '"animation_url":"',
            video,
            '"',
            "}"
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(json)));
    }

    /// @notice Gets the base URI of the collection
    /// @return The base URI of the collection
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /// @notice Gets the total supply of minted tokens
    /// @return The total supply of tokens
    function _totalSupply() internal view returns (uint256) {
        return RewardCollectionStorage.layout().totalSupply;
    }

    /// @notice Gets the approved address for a token
    /// @param tokenId The ID of the token
    /// @return The approved address for the token
    function _getApproved(uint256 tokenId) internal view returns (address) {
        return RewardCollectionStorage.layout().tokenApprovals[tokenId];
    }

    /// @notice Checks if an operator is approved for all tokens
    /// @param owner The address of the owner
    /// @param operator The address of the operator
    /// @return True if the operator is approved for all tokens, false otherwise
    function _isApprovedForAll(address owner, address operator) internal view returns (bool) {
        return RewardCollectionStorage.layout().operatorApprovals[owner][operator];
    }

    /// @notice Checks if the contract supports an interface
    /// @param interfaceId The ID of the interface
    /// @return True if the contract supports the interface, false otherwise
    function _supportsInterface(bytes4 interfaceId) internal pure returns (bool) {
        if (
            interfaceId == type(IERC721).interfaceId || interfaceId == type(IERC721Metadata).interfaceId
                || interfaceId == type(IERC721Errors).interfaceId || interfaceId == type(IERC165).interfaceId
        ) return true;
        return false;
    }

    // ========================================================================
    // Transfer Functions
    // ========================================================================

    /// @notice Transfers a token from one address to another
    /// @param from The address of the sender
    /// @param to The address of the recipient
    /// @param tokenId The ID of the token
    function _transferFrom(address from, address to, uint256 tokenId) internal {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }

        address previousOwner = _update(to, tokenId, msg.sender);
        if (previousOwner != from) {
            revert ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
    }

    /// @notice Safely transfers a token from one address to another
    /// @param from The address of the sender
    /// @param to The address of the recipient
    /// @param tokenId The ID of the token
    /// @param data Additional data to send with the transfer callback
    function _safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) internal {
        _transferFrom(from, to, tokenId);
        ERC721Utils.checkOnERC721Received(msg.sender, from, to, tokenId, data);
    }

    // ========================================================================
    // Mint & Burn Functions
    // ========================================================================

    /// @notice Mints a token to an address
    /// @param to The address of the recipient
    /// @param tokenId The ID of the token to mint
    function _mint(address to, uint256 tokenId) internal {
        if (RewardCollectionStorage.layout().owners[tokenId] != address(0)) {
            revert GardenCollectionFacet_TokenAlreadyExists(tokenId);
        }
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        address previousOwner = _update(to, tokenId, address(0));
        if (previousOwner != address(0)) {
            revert ERC721InvalidSender(address(0));
        }
        RewardCollectionStorage.layout().totalSupply += 1;
    }

    /// @notice Burns a token
    /// @param tokenId The ID of the token to burn
    function _burn(uint256 tokenId) internal {
        address previousOwner = _update(address(0), tokenId, address(0));
        if (previousOwner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
        RewardCollectionStorage.layout().totalSupply -= 1;
    }

    // ========================================================================
    // Approval Functions
    // ========================================================================

    /// @notice Approves an address for a token
    /// @param to The address to approve
    /// @param tokenId The ID of the token
    /// @param auth The address of the authorizer
    function _approve(address to, uint256 tokenId, address auth) internal {
        address owner = _ownerOf(tokenId);
        if (auth != address(0) && owner != auth && !_isApprovedForAll(owner, auth)) {
            revert ERC721InvalidApprover(auth);
        }
        RewardCollectionStorage.layout().tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    /// @notice Sets the approval for all tokens
    /// @param owner The address of the owner
    /// @param operator The address of the operator
    /// @param approved True if the operator is approved for all tokens, false otherwise
    function _setApprovalForAll(address owner, address operator, bool approved) internal {
        if (operator == address(0)) {
            revert ERC721InvalidOperator(operator);
        }
        RewardCollectionStorage.layout().operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    // ========================================================================
    // Internal Helper Functions
    // ========================================================================

    /// @notice Updates the ownership of a token
    /// @param to The address of the new owner (address(0) for burn)
    /// @param tokenId The ID of the token
    /// @param auth The address of the authorizer (address(0) to skip auth check)
    /// @return The previous owner of the token
    function _update(address to, uint256 tokenId, address auth) internal returns (address) {
        // Get the previous owner of the token
        address from = RewardCollectionStorage.layout().owners[tokenId];

        // Check authorization if needed
        if (auth != address(0) && from != address(0)) {
            if (from != auth && !_isApprovedForAll(from, auth) && _getApproved(tokenId) != auth) {
                revert ERC721InsufficientApproval(auth, tokenId);
            }
        }

        // Clear approval when transferring
        if (from != address(0)) {
            RewardCollectionStorage.layout().tokenApprovals[tokenId] = address(0);
            unchecked {
                RewardCollectionStorage.layout().balances[from] -= 1;
            }
        }

        // Update balances and ownership
        if (to != address(0)) {
            unchecked {
                RewardCollectionStorage.layout().balances[to] += 1;
            }
        }

        RewardCollectionStorage.layout().owners[tokenId] = to;

        // Emit the transfer event
        emit Transfer(from, to, tokenId);

        // Return the previous owner
        return from;
    }
}
