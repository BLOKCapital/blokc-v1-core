// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

error NotAuthorized();
error InvalidAddress();
error CollectionExists(string name);
error CollectionNotFound();
error MintFailed(address collection);
error NotCollectionOwner();

contract SBTRegistry {
    address public owner;

    // name → collection address
    mapping(string => address) public collections;
    address[] public allCollections;

    event RegisteredCollection(string indexed name, address indexed collection);
    event Minted(address indexed collection, address indexed to, uint256 tokenId);
    event OwnerSet(address indexed newOwner);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    constructor(address initialOwner) {
        owner = initialOwner;
        if (initialOwner == address(0)) revert InvalidAddress();
    }

    // -------------------------------------------------------
    //                     OWNER FUNCTIONS
    // -------------------------------------------------------

    function setOwner(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidAddress();
        owner = newOwner;
        emit OwnerSet(newOwner);
    }

    // -------------------------------------------------------
    //        REGISTER MANUALLY DEPLOYED COLLECTION
    // -------------------------------------------------------

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

    // -------------------------------------------------------
    //                      MINTING (OWNER ONLY)
    // -------------------------------------------------------

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

    function _mint(address collection, address to, uint256 tokenId) private returns (uint256) {
        (bool ok, bytes memory result) = collection.call(abi.encodeWithSignature("mint(address,uint256)", to, tokenId));

        if (!ok) revert MintFailed(collection);

        uint256 mintedId = abi.decode(result, (uint256));
        emit Minted(collection, to, mintedId);
        return mintedId;
    }

    // -------------------------------------------------------
    //                      VIEW
    // -------------------------------------------------------

    function getAllCollections() external view returns (address[] memory) {
        return allCollections;
    }
}
