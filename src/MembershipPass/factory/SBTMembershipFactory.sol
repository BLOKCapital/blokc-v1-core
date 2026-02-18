// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { UniversalSBTCollection } from "src/MembershipPass/collection/UniversalSBTCollection.sol";
import { SBTNoDelegateCall } from "src/MembershipPass/factory/SBTNoDelegateCall.sol";
import { IERC5484 } from "src/interfaces/IERC5484.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Thrown when an invalid address (zero) is provided
error InvalidAddress();

/// @notice Thrown when the specified collection is not registered
error CollectionNotFound();

/// @notice Thrown when a collection with the given name already exists
/// @param name The duplicate collection name
error CollectionAlreadyExists(string name);

/// @notice Thrown when caller is not authorized for the operation
error NotAuthorized();

/// @notice Thrown when the worker is already authorized for the collection
/// @param worker The worker address
/// @param collection The collection address
error AlreadyWorkerForCollection(address worker, address collection);

/// @notice Thrown when the worker is not authorized for the collection
/// @param worker The worker address
/// @param collection The collection address
error NotWorkerForCollection(address worker, address collection);

/// @title SBTMembershipFactory
/// @author BLOK Capital DAO
/// @notice Factory for deploying and managing UniversalSBTCollection membership passes
/// @dev Deploys new SBT collections, manages per-collection mint policies (DAO-only or
///      DAO + authorized workers), and handles minting/burning through the factory.
///      Uses SBTNoDelegateCall to prevent delegatecall attacks.
contract SBTMembershipFactory is SBTNoDelegateCall, Ownable {
    /// @notice Mapping from collection name to collection contract address
    mapping(string => address) public collections;

    /// @notice Reverse mapping from collection address to name (for event readability)
    mapping(address => string) public collectionNameOf;

    /// @notice Array of all deployed collection addresses
    address[] public allCollections;

    /// @notice Whether an address is a registered collection
    mapping(address => bool) public isCollection;

    /// @notice Defines who can mint from a collection
    /// @dev DAO_ONLY: only the factory owner can mint. DAO_OR_WORKER: owner or authorized workers.
    enum MintPolicy {
        DAO_ONLY,
        DAO_OR_WORKER
    }

    /// @notice Mint policy for each collection
    mapping(address => MintPolicy) public mintPolicyOf;

    /// @notice Whether a worker is authorized to mint from a specific collection
    mapping(address => mapping(address => bool)) public isWorkerForCollection;

    /// @notice Emitted when a new collection is deployed
    /// @param name Collection name
    /// @param collection Deployed collection contract address
    /// @param deployer Address that triggered the deployment
    event CollectionDeployed(string indexed name, address indexed collection, address indexed deployer);

    /// @notice Emitted when an SBT is minted through the factory
    /// @param collectionName Name of the collection
    /// @param collection Collection contract address
    /// @param to Recipient address
    /// @param tokenId Minted token ID
    event Minted(string indexed collectionName, address indexed collection, address indexed to, uint256 tokenId);

    /// @notice Emitted when a worker is authorized for a collection
    /// @param worker Worker address
    /// @param collection Collection contract address
    event WorkerForCollectionAdded(address indexed worker, address indexed collection);

    /// @notice Emitted when a worker is deauthorized for a collection
    /// @param worker Worker address
    /// @param collection Collection contract address
    event WorkerForCollectionRemoved(address indexed worker, address indexed collection);

    /// @notice Emitted when a collection's mint policy is changed
    /// @param collection Collection contract address
    /// @param policy New mint policy
    event MintPolicySet(address indexed collection, MintPolicy policy);

    /// @notice Deploys the factory with the specified owner
    /// @param initialOwner Address of the initial factory owner
    constructor(address initialOwner) Ownable(initialOwner) {
        if (initialOwner == address(0)) revert InvalidAddress();
    }

    /// @notice Deploys a new UniversalSBTCollection with the specified parameters
    /// @param name Unique name for the collection
    /// @param symbol ERC721 token symbol
    /// @param description Human-readable description
    /// @param baseCid IPFS base CID for metadata
    /// @param maxSupply Maximum supply (0 = unlimited)
    /// @param defaultBurnAuth Default burn authority for minted tokens
    /// @param policy Mint policy (DAO_ONLY or DAO_OR_WORKER)
    /// @return collection Address of the deployed collection contract
    function deployCollection(
        string memory name,
        string memory symbol,
        string memory description,
        string memory baseCid,
        uint256 maxSupply,
        IERC5484.BurnAuth defaultBurnAuth,
        MintPolicy policy
    )
        external
        onlyOwner
        noDelegateCall
        returns (address collection)
    {
        if (collections[name] != address(0)) revert CollectionAlreadyExists(name);
        if (bytes(name).length == 0) revert InvalidAddress();
        if (bytes(symbol).length == 0) revert InvalidAddress();
        if (bytes(description).length == 0) revert InvalidAddress();
        if (bytes(baseCid).length == 0) revert InvalidAddress();

        collection = address(
            new UniversalSBTCollection(name, symbol, description, baseCid, maxSupply, defaultBurnAuth, address(this))
        );

        collections[name] = collection;
        collectionNameOf[collection] = name;

        allCollections.push(collection);
        isCollection[collection] = true;
        mintPolicyOf[collection] = policy;

        emit CollectionDeployed(name, collection, msg.sender);
    }

    /// @notice Updates the mint policy for a collection
    /// @param collection Collection contract address
    /// @param policy New mint policy to apply
    function setMintPolicy(address collection, MintPolicy policy) external onlyOwner noDelegateCall {
        if (!isCollection[collection]) revert CollectionNotFound();
        mintPolicyOf[collection] = policy;
        emit MintPolicySet(collection, policy);
    }

    /// @notice Authorizes a worker to mint from a specific collection
    /// @param worker Worker address to authorize
    /// @param collection Collection contract address
    function addWorkerForCollection(address worker, address collection) external onlyOwner noDelegateCall {
        if (!isCollection[collection]) revert CollectionNotFound();
        if (isWorkerForCollection[worker][collection]) revert AlreadyWorkerForCollection(worker, collection);

        isWorkerForCollection[worker][collection] = true;
        emit WorkerForCollectionAdded(worker, collection);
    }

    /// @notice Removes a worker's authorization to mint from a specific collection
    /// @param worker Worker address to deauthorize
    /// @param collection Collection contract address
    function removeWorkerForCollection(address worker, address collection) external onlyOwner noDelegateCall {
        if (!isCollection[collection]) revert CollectionNotFound();
        if (!isWorkerForCollection[worker][collection]) revert NotWorkerForCollection(worker, collection);

        isWorkerForCollection[worker][collection] = false;
        emit WorkerForCollectionRemoved(worker, collection);
    }

    /// @notice Mints an SBT from a registered collection
    /// @param collection Collection contract address to mint from
    /// @param to Recipient address
    /// @return The minted token ID
    /// @dev Authorization depends on the collection's MintPolicy. DAO_ONLY requires owner.
    ///      DAO_OR_WORKER accepts owner or authorized workers.
    function mintFromCollection(address collection, address to) external noDelegateCall returns (uint256) {
        if (!isCollection[collection]) revert CollectionNotFound();
        if (to == address(0)) revert InvalidAddress();

        MintPolicy policy = mintPolicyOf[collection];

        // Authorization: DAO or workers depending on policy
        if (policy == MintPolicy.DAO_ONLY) {
            if (msg.sender != owner()) revert NotAuthorized();
        } else {
            if (msg.sender != owner() && !isWorkerForCollection[msg.sender][collection]) {
                revert NotAuthorized();
            }
        }

        uint256 tokenId = UniversalSBTCollection(collection).mint(to);

        emit Minted(collectionNameOf[collection], collection, to, tokenId);
        return tokenId;
    }

    /// @notice Burns a token from a registered collection
    /// @param collection Collection contract address
    /// @param tokenId Token ID to burn
    /// @dev Only callable by owner or authorized workers.
    function burn(address collection, uint256 tokenId) external noDelegateCall {
        if (!isCollection[collection]) revert CollectionNotFound();
        if (msg.sender != owner() && !isWorkerForCollection[msg.sender][collection]) revert NotAuthorized();

        UniversalSBTCollection(collection).burn(tokenId);
    }

    /// @notice Returns the collection address for a given name
    /// @param name Collection name
    /// @return Collection contract address (or address(0) if not found)
    function getCollection(string memory name) external view returns (address) {
        return collections[name];
    }

    /// @notice Returns the total number of deployed collections
    function getCollectionCount() external view returns (uint256) {
        return allCollections.length;
    }

    /// @notice Returns all deployed collection addresses
    function getAllCollections() external view returns (address[] memory) {
        return allCollections;
    }
}
