// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { UniversalSBTCollection } from "src/MembershipPass/collection/UniversalSBTCollection.sol";
import { SBTNoDelegateCall } from "src/MembershipPass/factory/SBTNoDelegateCall.sol";
import { IERC5484 } from "src/interfaces/IERC5484.sol";

error NotOwner();
error InvalidAddress();
error CollectionNotFound();
error CollectionAlreadyExists(string name);
error NotAuthorized();
error AlreadyWorkerForCollection(address worker, address collection);
error NotWorkerForCollection(address worker, address collection);

contract SBTMembershipFactory is SBTNoDelegateCall {
    address public owner;

    // name → collection address
    mapping(string => address) public collections;

    // collection → name (for event readability)
    mapping(address => string) public collectionNameOf;

    // list of created collections
    address[] public allCollections;
    mapping(address => bool) public isCollection;

    // Per-collection mint policy
    enum MintPolicy {
        DAO_ONLY,
        DAO_OR_WORKER
    }

    mapping(address => MintPolicy) public mintPolicyOf;

    // Worker → collection → allowed
    mapping(address => mapping(address => bool)) public isWorkerForCollection;

    event CollectionDeployed(string indexed name, address indexed collection, address indexed deployer);
    event Minted(string indexed collectionName, address indexed collection, address indexed to, uint256 tokenId);
    event WorkerForCollectionAdded(address indexed worker, address indexed collection);
    event WorkerForCollectionRemoved(address indexed worker, address indexed collection);
    event OwnerSet(address indexed newOwner);
    event MintPolicySet(address indexed collection, MintPolicy policy);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address dao) {
        owner = dao;
    }

    // ----------------------------------------------------------------
    //                        DEPLOY NEW COLLECTION
    // ----------------------------------------------------------------
    function deployCollection(
        string memory name,
        string memory symbol,
        string memory description,
        string memory baseCID,
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
        if (bytes(baseCID).length == 0) revert InvalidAddress();

        collection = address(
            new UniversalSBTCollection(name, symbol, description, baseCID, maxSupply, defaultBurnAuth, address(this))
        );

        collections[name] = collection;
        collectionNameOf[collection] = name;

        allCollections.push(collection);
        isCollection[collection] = true;
        mintPolicyOf[collection] = policy;

        emit CollectionDeployed(name, collection, msg.sender);
    }

    // ----------------------------------------------------------------
    //                       POLICY MANAGEMENT
    // ----------------------------------------------------------------
    function setMintPolicy(address collection, MintPolicy policy) external onlyOwner noDelegateCall {
        if (!isCollection[collection]) revert CollectionNotFound();
        mintPolicyOf[collection] = policy;
        emit MintPolicySet(collection, policy);
    }

    function addWorkerForCollection(address worker, address collection) external onlyOwner noDelegateCall {
        if (!isCollection[collection]) revert CollectionNotFound();
        if (isWorkerForCollection[worker][collection]) revert AlreadyWorkerForCollection(worker, collection);

        isWorkerForCollection[worker][collection] = true;
        emit WorkerForCollectionAdded(worker, collection);
    }

    function removeWorkerForCollection(address worker, address collection) external onlyOwner noDelegateCall {
        if (!isCollection[collection]) revert CollectionNotFound();
        if (!isWorkerForCollection[worker][collection]) revert NotWorkerForCollection(worker, collection);

        isWorkerForCollection[worker][collection] = false;
        emit WorkerForCollectionRemoved(worker, collection);
    }

    // ----------------------------------------------------------------
    //                             MINTING
    // ----------------------------------------------------------------
    /// @notice Mint from a collection by its address (ONLY mint function)
    function mintFromCollection(address collection, address to) external noDelegateCall returns (uint256) {
        if (!isCollection[collection]) revert CollectionNotFound();
        if (to == address(0)) revert InvalidAddress();

        MintPolicy policy = mintPolicyOf[collection];

        // Authorization: DAO or workers depending on policy
        if (policy == MintPolicy.DAO_ONLY) {
            if (msg.sender != owner) revert NotAuthorized();
        } else {
            if (msg.sender != owner && !isWorkerForCollection[msg.sender][collection]) {
                revert NotAuthorized();
            }
        }

        uint256 tokenId = UniversalSBTCollection(collection).mint(to);

        emit Minted(collectionNameOf[collection], collection, to, tokenId);
        return tokenId;
    }

    // ----------------------------------------------------------------
    //                               BURN
    // ----------------------------------------------------------------
    function burn(address collection, uint256 tokenId) external noDelegateCall {
        if (!isCollection[collection]) revert CollectionNotFound();
        if (msg.sender != owner && !isWorkerForCollection[msg.sender][collection]) revert NotAuthorized();

        UniversalSBTCollection(collection).burn(tokenId);
    }

    // ----------------------------------------------------------------
    //                           VIEW HELPERS
    // ----------------------------------------------------------------
    function getCollection(string memory name) external view returns (address) {
        return collections[name];
    }

    function getCollectionCount() external view returns (uint256) {
        return allCollections.length;
    }

    function getAllCollections() external view returns (address[] memory) {
        return allCollections;
    }
}
