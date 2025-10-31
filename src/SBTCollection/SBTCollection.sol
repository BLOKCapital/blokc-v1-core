// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

error NotGardenFactory();
error CollectionNotFound();
error CollectionSoldOut();
error GardenAlreadyRegistered();
error NonTransferable();
error ApproveNotAllowed();

// contract SBTCollection is ERC721 {
//     string public baseUri;
//     address public collectionRegistry;
//     uint256 public immutable collectionSize;
//     uint256 public mintedCount;

//     mapping(address => uint256) private _balanceOf;

//     event Mint(address indexed to, uint256 indexed tokenId);

//     constructor(
//         string memory _name,
//         string memory _symbol,
//         string memory _baseUri,
//         uint256 _size
//     )
//         ERC721(_name, _symbol)
//     {
//         baseUri = _baseUri;
//         collectionRegistry = msg.sender;
//         collectionSize = _size;
//     }

//     modifier onlyRegistry() {
//         if (msg.sender != collectionRegistry) revert NotGardenFactory();
//         _;
//     }

//     function size() external view returns (uint256) {
//         return collectionSize;
//     }

//     function minted() external view returns (uint256) {
//         return mintedCount;
//     }

//     function mint(address to) external onlyRegistry returns (uint256) {
//         if (mintedCount + 1 > collectionSize) revert CollectionSoldOut();
//         mintedCount += 1;
//         uint256 tokenId = mintedCount;
//         _balanceOf[to] += 1;
//         emit Transfer(address(0), to, tokenId);
//         emit Mint(to, tokenId);
//     }

//     // --- Block all transfer/approval methods ---
//     function transferFrom(address, address, uint256) public pure override {
//         revert NonTransferable();
//     }

//     function approve(address, uint256) public pure override {
//         revert ApproveNotAllowed();
//     }

//     function setApprovalForAll(address, bool) public pure override {
//         revert ApproveNotAllowed();
//     }
// }
