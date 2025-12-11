// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC5484 } from "src/interfaces/IERC5484.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { ERC721 as OZ_ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

error NonTransferable();
error ApproveNotAllowed();
error AlreadyHasSBT(address to);
error MaxSupplyReached();
error NonBurnable();
error URIQueryForNonexistentToken();
error InvalidAddress();
error NoMembershipPass(address to);
error RenounceDisabled();

/// @title BaddieCollection – Soulbound Video SBT Collection
/// @notice Video-only (.mp4). parentPass enforced in mint.
/// @dev Owner (msg.sender at deploy) should be registry so registry can mint.
contract BaddieCollection is ERC721, Ownable, IERC5484 {
    uint256 public mintedCount;
    uint256 public constant MAX_SUPPLY = 50;

    string public baseCID; // e.g. "bafy...".
    address public parentPass; // membership pass required (BaddiePass) or address(0) for open

    mapping(address => bool) public hasSBT;

    event Mint(address indexed to, uint256 indexed tokenId, string tokenURI);

    constructor(string memory _baseCID, address _parentPass) ERC721("Baddie", "BADDIE") Ownable(msg.sender) {
        baseCID = _baseCID;
        parentPass = _parentPass;
        // owner will be msg.sender (the deployer). If you want registry to be owner,
        // deploy from registry or call transferOwnership(registry) after deploy.
    }

    // ----------------------------------------------------------
    //                           MINT (registry = owner)
    // ----------------------------------------------------------
    function mint(address to, uint256 tokenId) external onlyOwner returns (uint256) {
        if (to == address(0)) revert InvalidAddress();
        if (hasSBT[to]) revert AlreadyHasSBT(to);
        if (tokenId == 0 || tokenId > MAX_SUPPLY) revert MaxSupplyReached();
        if (_ownerOf(tokenId) != address(0)) revert AlreadyHasSBT(to);

        if (parentPass != address(0)) {
            try OZ_ERC721(parentPass).balanceOf(to) returns (uint256 bal) {
                if (bal == 0) revert NoMembershipPass(to);
            } catch {
                revert NoMembershipPass(to);
            }
        }

        mintedCount++;
        hasSBT[to] = true;

        _safeMint(to, tokenId);

        emit Issued(msg.sender, to, tokenId, BurnAuth.Neither);
        emit Mint(to, tokenId, tokenURI(tokenId));

        return tokenId;
    }

    // ----------------------------------------------------------
    //                    SOULBOUND LOGIC
    // ----------------------------------------------------------
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

    // OZ v4.9+ soulbound transfer block
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

    // ----------------------------------------------------------
    //                          METADATA
    // ----------------------------------------------------------
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (ownerOf(tokenId) == address(0)) revert URIQueryForNonexistentToken();

        string memory id = Strings.toString(tokenId);
        string memory video = string(abi.encodePacked("ipfs://", baseCID, "/", id, ".mp4"));

        bytes memory json = abi.encodePacked(
            "{",
            '"name":"Baddie #',
            id,
            '",',
            '"description":"Soulbound Baddie Video Token",',
            '"animation_url":"',
            video,
            '"',
            "}"
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(json)));
    }

    function totalSupply() external view returns (uint256) {
        return mintedCount;
    }

    function renounceOwnership() public override {
        revert RenounceDisabled();
    }
}
