// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC5484 } from "src/interfaces/IERC5484.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { ERC721 as OZ_ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @notice Thrown when a soulbound token transfer is attempted
error NonTransferable();

/// @notice Thrown when approval is attempted on a soulbound token
error ApproveNotAllowed();

/// @notice Thrown when recipient already holds an SBT
/// @param to The address that already has an SBT
error AlreadyHasSbt(address to);

/// @notice Thrown when max supply limit is reached or token ID exceeds max supply
error MaxSupplyReached();

/// @notice Thrown when burning is attempted on a non-burnable token
error NonBurnable();

/// @notice Thrown when an invalid address (zero) is provided
error InvalidAddress();

/// @notice Thrown when querying URI for a non-existent token
error URIQueryForNonexistentToken();

/// @notice Thrown when recipient does not hold the required membership pass
/// @param to The address missing the membership pass
error NoMembershipPass(address to);

/// @notice Thrown when renouncing ownership is attempted
error RenounceDisabled();

/// @title BuilderCollection
/// @author BLOK Capital DAO
/// @notice Soulbound Video SBT collection for Builders (limited to 100 tokens)
/// @dev Implements ERC-5484 (Consensual Soulbound Tokens). Video-only (.mp4) metadata
///      is generated on-chain as base64-encoded JSON. Tokens are non-transferable and
///      non-burnable. Requires a membership pass for minting when parentPass is set.
contract BuilderCollection is ERC721, Ownable, IERC5484 {
    /// @notice Total number of tokens minted
    uint256 public mintedCount;

    /// @notice Maximum number of tokens that can be minted
    uint256 public constant MAX_SUPPLY = 100;

    /// @notice IPFS base CID for video files
    string public baseCid;

    /// @notice Address of the required membership pass contract (or address(0) if none required)
    address public parentPass;

    /// @notice Tracks whether an address already holds an SBT
    mapping(address => bool) public hasSbt;

    /// @notice Emitted when a new SBT is minted
    /// @param to Recipient address
    /// @param tokenId Token ID of the minted SBT
    /// @param tokenURI URI of the token metadata
    event Mint(address indexed to, uint256 indexed tokenId, string tokenURI);

    /// @notice Deploys the BuilderCollection with IPFS video CID and optional membership pass
    /// @param _baseCid IPFS base CID for video files
    /// @param _parentPass Address of the membership pass contract (or address(0) for open minting)
    constructor(string memory _baseCid, address _parentPass) ERC721("Builder", "BUILDER") Ownable(msg.sender) {
        baseCid = _baseCid;
        parentPass = _parentPass;
    }

    /// @notice Mints a soulbound video token to the specified address
    /// @param to Recipient address
    /// @param tokenId Token ID to mint (must be <= MAX_SUPPLY)
    /// @return The minted token ID
    /// @dev Only callable by owner. Recipient must hold a membership pass if parentPass is set.
    function mint(address to, uint256 tokenId) external onlyOwner returns (uint256) {
        if (to == address(0)) revert InvalidAddress();
        if (hasSbt[to]) revert AlreadyHasSbt(to);
        if (tokenId == 0 || tokenId > MAX_SUPPLY) revert MaxSupplyReached();
        if (_ownerOf(tokenId) != address(0)) revert AlreadyHasSbt(to);

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

        emit Issued(msg.sender, to, tokenId, BurnAuth.Neither);
        emit Mint(to, tokenId, tokenURI(tokenId));

        return tokenId;
    }

    // ----------------------------------------------------------
    //                SOULBOUND — NO TRANSFER / NO BURN
    // ----------------------------------------------------------

    /// @notice Burning is disabled for soulbound tokens
    function burn(uint256) external pure {
        revert NonBurnable();
    }

    /// @inheritdoc IERC5484
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

    // ----------------------------------------------------------
    //                          METADATA
    // ----------------------------------------------------------

    /// @notice Returns on-chain generated metadata with video animation URL
    /// @param tokenId Token ID to query
    /// @return Base64-encoded JSON metadata URI
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (ownerOf(tokenId) == address(0)) revert URIQueryForNonexistentToken();

        string memory id = Strings.toString(tokenId);
        string memory video = string(abi.encodePacked("ipfs://", baseCid, "/", id, ".mp4"));

        bytes memory json = abi.encodePacked(
            "{",
            '"name":"Builder #',
            id,
            '",',
            '"description":"Official Builder Soulbound Video Token - Proof of contribution on Blokc",',
            '"animation_url":"',
            video,
            '"',
            "}"
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(json)));
    }

    /// @notice Returns the total number of minted tokens
    function totalSupply() external view returns (uint256) {
        return mintedCount;
    }

    /// @notice Renouncing ownership is disabled
    function renounceOwnership() public override {
        revert RenounceDisabled();
    }
}
