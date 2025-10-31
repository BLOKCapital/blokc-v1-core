//SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

// import { SBTCollection } from "src/SBTCollection/SBTCollection.sol";

error NotGardenFactory();
error CollectionNotFound();
error CollectionSoldOut();
error GardenAlreadyRegistered();
error NonTransferable();
error ApproveNotAllowed();

// contract SBTCollectionRegistry {
//     address public gardenFactory;

//     struct CollectionInfo {
//         address collectionAddress;
//         string collectionURI;
//         uint256 priceInBlokCTokens;
//         uint256 size;
//         uint256 minted;
//         bool exists;
//     }

//     mapping(address => CollectionInfo) public collections;
//     address[] public collectionList;

//     // collection => garden => tokenId (0 means not registered)
//     mapping(address => mapping(address => uint256)) public gardenToSBT;

//     event CollectionDeployed(address indexed collection, string uri, uint256 size, uint256 price);
//     event SBTMinted(address indexed collection, address indexed garden, uint256 indexed tokenId);

//     error SBTCollectionRegistry_CanBeCalledOnlyByGardenFactory();

//     modifier onlyGardenFactory() {
//         if (msg.sender != gardenFactory) revert SBTCollectionRegistry_CanBeCalledOnlyByGardenFactory();
//         _;
//     }

//     function setGardenFactory(address _gardenFactory) external {
//         gardenFactory = _gardenFactory;
//     }

//     /// @notice deploys a new SBT collection contract (non-transferable tokens)
//     /// @dev callable by gardenFactory. Registry becomes the minter of the deployed collection.
//     function deployCollection(
//         string calldata name,
//         string calldata symbol,
//         string memory collectionURI,
//         uint256 priceInBlokCTokens,
//         uint256 size
//     )
//         external
//         onlyGardenFactory
//     {
//         SBTCollection deployed = new SBTCollection(name, symbol, collectionURI, size);
//         address colAddr = address(deployed);

//         collections[colAddr] = CollectionInfo({
//             collectionAddress: colAddr,
//             collectionURI: collectionURI,
//             priceInBlokCTokens: priceInBlokCTokens,
//             size: size,
//             minted: 0,
//             exists: true
//         });
//         collectionList.push(colAddr);

//         emit CollectionDeployed(colAddr, collectionURI, size, priceInBlokCTokens);
//     }

//     /// @notice mint one SBT from a particular collection to a garden address and register it
//     /// @dev Callable only by gardenFactory when a garden (diamond) is created.
//     function mintSBT(address garden, address collection) external onlyGardenFactory returns (uint256) {
//         CollectionInfo storage info = collections[collection];
//         if (!info.exists) revert CollectionNotFound();
//         if (info.minted + 1 > info.size) revert CollectionSoldOut();
//         if (gardenToSBT[collection][garden] != 0) revert GardenAlreadyRegistered();

//         uint256 tokenId = SBTCollection(collection).mint(garden);
//         info.minted += 1;
//         gardenToSBT[collection][garden] = tokenId;

//         emit SBTMinted(collection, garden, tokenId);
//         return tokenId;
//     }

//     // helper getters
//     function collectionsCount() external view returns (uint256) {
//         return collectionList.length;
//     }

//     function getCollectionAt(uint256 idx) external view returns (address) {
//         return collectionList[idx];
//     }
// }
