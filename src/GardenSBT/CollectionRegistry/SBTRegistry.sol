// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Thrown when caller is not the owner
error NotAuthorized();

/// @notice Thrown when an invalid address (zero) is provided
error InvalidAddress();

/// @notice Thrown when a collection with the given name already exists
/// @param name The duplicate collection name
error CollectionExists(string name);

/// @notice Thrown when the specified collection is not registered
error CollectionNotFound();

/// @notice Thrown when minting fails on the target collection
/// @param collection The collection address where minting failed
error MintFailed(address collection);

/// @notice Thrown when the registry is not the owner of the collection
error NotCollectionOwner();

/// @title SBTRegistry
/// @author BLOK Capital DAO
/// @notice Registry for managing soulbound token collections and their minting
/// @dev Maintains a registry of deployed SBT collections and provides owner-only
///      minting capabilities. Collections must transfer ownership to this registry
///      before registration.
contract SBTRegistry {
    /// @notice Address of the registry owner
    address public owner;

    /// @notice Mapping from collection name to collection contract address
    mapping(string => address) public collections;

    /// @notice Array of all registered collection addresses
    address[] public allCollections;

    /// @notice Emitted when a new collection is registered
    /// @param name Collection name
    /// @param collection Collection contract address
    event RegisteredCollection(string indexed name, address indexed collection);

    /// @notice Emitted when an SBT is minted through the registry
    /// @param collection Collection contract address
    /// @param to Recipient address
    /// @param tokenId Minted token ID
    event Minted(address indexed collection, address indexed to, uint256 tokenId);

    /// @notice Emitted when the registry owner is changed
    /// @param newOwner New owner address
    event OwnerSet(address indexed newOwner);

    /// @notice Restricts access to the registry owner
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    /// @notice Deploys the registry with the specified owner
    /// @param initialOwner Address of the initial registry owner
    constructor(address initialOwner) {
        owner = initialOwner;
        if (initialOwner == address(0)) revert InvalidAddress();
    }

    /// @notice Transfers ownership of the registry
    /// @param newOwner Address of the new owner
    function setOwner(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidAddress();
        owner = newOwner;
        emit OwnerSet(newOwner);
    }

    /// @notice Registers a manually deployed collection with the registry
    /// @param name Unique name for the collection
    /// @param collection Address of the deployed collection contract
    /// @dev The collection must have transferred ownership to this registry before calling.
    function registerCollection(string calldata name, address collection) external onlyOwner {
        if (collection == address(0)) revert InvalidAddress();
        if (collections[name] != address(0)) revert CollectionExists(name);

        // registry must own the collection
        try Ownable(collection).owner() returns (address collOwner) {
            if (collOwner != address(this)) revert NotCollectionOwner();
        } catch {
            revert NotCollectionOwner();
        }

        collections[name] = collection;
        allCollections.push(collection);

        emit RegisteredCollection(name, collection);
    }

    /// @notice Mints an SBT from a registered collection by its address
    /// @param collection Address of the collection to mint from
    /// @param to Recipient address
    /// @param tokenId Token ID to mint
    /// @return The minted token ID
    function mintByAddress(address collection, address to, uint256 tokenId) external onlyOwner returns (uint256) {
        if (collection == address(0)) revert InvalidAddress();

        bool exists = false;
        for (uint256 i = 0; i < allCollections.length; i++) {
            if (allCollections[i] == collection) {
                exists = true;
                break;
            }
        }
        if (!exists) revert CollectionNotFound();

        return _mint(collection, to, tokenId);
    }

    /// @dev Internal mint function that calls the collection's mint function via low-level call
    function _mint(address collection, address to, uint256 tokenId) private returns (uint256) {
        (bool ok, bytes memory result) = collection.call(abi.encodeWithSignature("mint(address,uint256)", to, tokenId));

        if (!ok) revert MintFailed(collection);

        uint256 mintedId = abi.decode(result, (uint256));
        emit Minted(collection, to, mintedId);
        return mintedId;
    }

    /// @notice Returns all registered collection addresses
    /// @return Array of collection contract addresses
    function getAllCollections() external view returns (address[] memory) {
        return allCollections;
    }
}
