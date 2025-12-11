// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

interface ISBTRegistry {
    // Errors (optional but recommended for consistency)
    error NotAuthorized();
    error InvalidAddress();
    error CollectionExists(string name);
    error CollectionNotFound();
    error MintFailed(address collection);
    error NotCollectionOwner();

    // Events
    event RegisteredCollection(string indexed name, address indexed collection);
    event Minted(address indexed collection, address indexed to, uint256 tokenId);
    event OwnerSet(address indexed newOwner);

    // Owner State
    function owner() external view returns (address);

    function setOwner(address newOwner) external;

    // Collections
    function registerCollection(string calldata name, address collection) external;

    // Minting
    function mintByAddress(address collection, address to, uint256 tokenId) external returns (uint256);

    // View
    function getAllCollections() external view returns (address[] memory);
}
