// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC5484 } from "src/interfaces/IERC5484.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC721 as OZ_ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

error NonTransferable();
error ApproveNotAllowed();
error AlreadyHasSbt(address to);
error InvalidAddress();
error URIQueryForNonexistentToken();
error NoMembershipPass(address to);
error RenounceDisabled();

/// @title GardenCollection – Soulbound PFP (Image + Video)
contract GardenCollection is ERC721, Ownable, IERC5484 {
    uint256 public mintedCount;
    string public baseCid;

    /// NEW: protocol-wide pass required
    address public parentPass;

    mapping(address => bool) public hasSbt;

    event Mint(address indexed to, uint256 indexed tokenId, string metadataURI);

    constructor(string memory _baseCid, address _parentPass) ERC721("Garden", "GARDEN") Ownable(msg.sender) {
        baseCid = _baseCid;
        parentPass = _parentPass;
    }

    /// @notice Owner-only mint. User must have protocol pass.
    function mint(address to, uint256 tokenId) external onlyOwner returns (uint256) {
        if (to == address(0)) revert InvalidAddress();
        if (hasSbt[to]) revert AlreadyHasSbt(to);
        if (tokenId == 0) revert InvalidAddress();
        if (_ownerOf(tokenId) != address(0)) revert AlreadyHasSbt(to);

        // -----------------------------
        // NEW: membership pass check
        // -----------------------------
        if (parentPass != address(0)) {
            try OZ_ERC721(parentPass).balanceOf(to) returns (uint256 bal) {
                if (bal == 0) revert NoMembershipPass(to);
            } catch {
                revert NoMembershipPass(to);
            }
        }

        mintedCount++;
        hasSbt[to] = true;

        _safeMint(to, tokenId);

        string memory metadataURI =
            string(abi.encodePacked("ipfs://", baseCid, "/", Strings.toString(tokenId), ".json"));

        emit Issued(msg.sender, to, tokenId, BurnAuth.Neither);
        emit Mint(to, tokenId, metadataURI);

        return tokenId;
    }

    // ─────── Soulbound (no burn, no transfer, no approve) ───────

    function burn(uint256) external pure {
        revert("Burn disabled");
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

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721) returns (bool) {
        return interfaceId == type(IERC5484).interfaceId || super.supportsInterface(interfaceId);
    }

    // Metadata
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (ownerOf(tokenId) == address(0)) revert URIQueryForNonexistentToken();

        return string(abi.encodePacked("ipfs://", baseCid, "/", Strings.toString(tokenId), ".json"));
    }

    function totalSupply() external view returns (uint256) {
        return mintedCount;
    }

    function renounceOwnership() public override {
        revert RenounceDisabled();
    }
}
