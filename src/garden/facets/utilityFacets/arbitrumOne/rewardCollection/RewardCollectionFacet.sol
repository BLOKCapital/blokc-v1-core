// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    @title GardenCollectionFacet
    @author BLOK Capital DAO
    @notice Facet contract for Garden Collection integration
    @dev This contract provides the functionality for Garden Collection which is a collection of rewards for the Garden
        contract. This contract inherits IERC721 and makes garden a collection in itself which is already a Diamond Proxy(EIP-2535).

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

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

contract RewardCollectionFacet is RewardCollectionBase, Facet {
    /// @inheritdoc IERC165
    /// @notice Checks if the contract supports an interface
    /// @param interfaceId The ID of the interface
    /// @return True if the contract supports the interface, false otherwise
    function supportsInterface(bytes4 interfaceId) public pure override(IERC165) returns (bool) {
        return _supportsInterface(interfaceId);
    }

    /// @notice Gets the balance of an owner
    /// @param owner The address of the owner
    /// @return The balance of the owner
    function balanceOf(address owner) public view override returns (uint256) {
        return _balanceOf(owner);
    }

    /// @notice Gets the owner of a token
    /// @param tokenId The ID of the token
    /// @return The owner of the token
    function ownerOf(uint256 tokenId) public view override returns (address) {
        return _ownerOf(tokenId);
    }

    /// @notice Approves an address for a token
    /// @param to The address of the to address
    /// @param tokenId The ID of the token
    function approve(address to, uint256 tokenId) public override onlyGardenOwner {
        _approve(to, tokenId, msg.sender);
    }

    /// @notice Gets the approved address for a token
    /// @param tokenId The ID of the token
    /// @return The approved address for the token
    function getApproved(uint256 tokenId) public view override returns (address) {
        _ownerOf(tokenId);
        return _getApproved(tokenId);
    }

    /// @notice Sets the approval for all tokens
    /// @param operator The address of the operator
    /// @param approved True if the operator is approved for all tokens, false otherwise
    function setApprovalForAll(address operator, bool approved) public override onlyGardenOwner {
        _setApprovalForAll(msg.sender, operator, approved);
    }

    /// @notice Checks if an operator is approved for all tokens
    /// @param owner The address of the owner
    /// @param operator The address of the operator
    /// @return True if the operator is approved for all tokens, false otherwise
    function isApprovedForAll(address owner, address operator) public view override returns (bool) {
        return _isApprovedForAll(owner, operator);
    }

    /// @notice Transfers a token from one address to another
    /// @param from The address of the from address
    /// @param to The address of the to address
    /// @param tokenId The ID of the token
    function transferFrom(address from, address to, uint256 tokenId) public override onlyGardenOwner {
        _transferFrom(from, to, tokenId);
    }

    /// @notice Safely transfers a token from one address to another
    /// @param from The address of the from address
    /// @param to The address of the to address
    /// @param tokenId The ID of the token
    function safeTransferFrom(address from, address to, uint256 tokenId) public override onlyGardenOwner {
        _safeTransferFrom(from, to, tokenId, "");
    }

    /// @notice Safely transfers a token from one address to another
    /// @param from The address of the from address
    /// @param to The address of the to address
    /// @param tokenId The ID of the token
    /// @param data The data to send with the transfer
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

    /// @notice Gets the name of the collection
    /// @return The name of the collection
    function name() public pure override returns (string memory) {
        return _name();
    }

    /// @notice Gets the symbol of the collection
    /// @return The symbol of the collection
    function symbol() public pure override returns (string memory) {
        return _symbol();
    }

    /// @notice Gets the URI of a token
    /// @param tokenId The ID of the token
    /// @return The URI of the token
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return _tokenURI(tokenId);
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply();
    }

    /// @notice Mints a token
    /// @param tokenId The ID of the token
    function mint(uint256 tokenId) public onlyGardenOwner {
        _mint(address(this), tokenId);
    }

    /// @notice Burns a token
    /// @param tokenId The ID of the token
    function burn(uint256 tokenId) external onlyGardenOwner {
        _burn(tokenId);
    }
}
