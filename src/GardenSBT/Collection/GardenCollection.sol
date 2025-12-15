// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC5484 } from "src/interfaces/IERC5484.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";  // ← ADD THIS
import { ERC721 as OZ_ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

error NonTransferable();
error ApproveNotAllowed();
error AlreadyHasSBT(address to);
error InvalidAddress();
error URIQueryForNonexistentToken();
error NoMembershipPass(address to);
error RenounceDisabled();
error NonBurnable();

/// @title GardenCollection – Soulbound PFP (Image)
contract GardenCollection is ERC721, Ownable, IERC5484 {
    uint256 public mintedCount;
    string public baseCID;
    address public parentPass;

    mapping(address => bool) public hasSBT;

    event Mint(address indexed to, uint256 indexed tokenId, string ipfsURI);

    constructor(string memory _baseCID, address _parentPass) 
        ERC721("Garden", "GARDEN") 
        Ownable(msg.sender) 
    {
        baseCID = _baseCID;
        parentPass = _parentPass;
    }

    /// @notice Owner-only mint. User must have protocol pass.
    function mint(address to, uint256 tokenId) external onlyOwner returns (uint256) {
        if (to == address(0)) revert InvalidAddress();
        if (hasSBT[to]) revert AlreadyHasSBT(to);
        if (tokenId == 0) revert InvalidAddress();
        if (_ownerOf(tokenId) != address(0)) revert AlreadyHasSBT(to);

        // Membership pass check
        if (parentPass != address(0)) {
            try OZ_ERC721(parentPass).balanceOf(to) returns (uint256 bal) {
                if (bal == 0) revert NoMembershipPass(to);
            } catch {
                revert NoMembershipPass(to);
            }
        }

        hasSBT[to] = true;
        mintedCount++;  // ← Increment BEFORE or AFTER both work, but be consistent

        _safeMint(to, tokenId);

        string memory ipfsURI = string(
            abi.encodePacked("ipfs://", baseCID, "/", Strings.toString(tokenId), ".jpg")
        );

        emit Issued(msg.sender, to, tokenId, BurnAuth.Neither);
        emit Mint(to, tokenId, ipfsURI);

        return tokenId;
    }

    // ─────── Soulbound ───────
    
    function burn(uint256) external pure {
        revert NonBurnable();
    }

    function burnAuth(uint256) external pure override returns (BurnAuth) {
        return BurnAuth.Neither;
    }

    function transferFrom(address, address, uint256) public pure override {
        revert NonTransferable();
    }

    function safeTransferFrom(address, address, uint256, bytes memory) public pure override {
        revert NonTransferable();
    }

    function approve(address, uint256) public pure override {
        revert ApproveNotAllowed();
    }

    function setApprovalForAll(address, bool) public pure override {
        revert ApproveNotAllowed();
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0)) revert NonTransferable();
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 amount) internal override {
        super._increaseBalance(account, amount);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721) returns (bool) {
        return interfaceId == type(IERC5484).interfaceId || super.supportsInterface(interfaceId);
    }

    // ─────── Metadata (Base64 encoded, like BaddieCollection) ───────
    
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (ownerOf(tokenId) == address(0)) revert URIQueryForNonexistentToken();

        string memory image = string(
            abi.encodePacked("ipfs://", baseCID, "/", Strings.toString(tokenId), ".jpg")
        );

        bytes memory json = abi.encodePacked(
            "{",
            '"name":"Garden #',
            Strings.toString(tokenId),
            '",',
            '"description":"Soulbound Garden PFP Collection",',
            '"image":"',
            image,
            '",',
            '"attributes":[]',
            "}"
        );

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(json)
            )
        );
    }

    function totalSupply() external view returns (uint256) {
        return mintedCount;
    }

    function renounceOwnership() public override {
        revert RenounceDisabled();
    }
}