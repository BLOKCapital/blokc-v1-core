// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC5484 } from "src/interfaces/IERC5484.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

error NotFactory();
error InvalidAddress();
error NonTransferable();
error ApproveNotAllowed();
error AlreadyHasSBT(address to);
error MaxSupplyReached();
error MintingClosed();
error NonBurnable();
error IssuerOnly();
error OwnerOnly();
error Both();
error URIQueryForNonexistentToken();

/// @title UniversalSBTCollection – Soulbound SBTs (no ENS)
/// @notice Clean minimal version matching updated factory
contract UniversalSBTCollection is ERC721, Ownable, IERC5484 {
    struct TokenData {
        address holder;
        IERC5484.BurnAuth burnAuth;
    }

    // Immutable
    string public description;
    string public baseCID;
    uint256 public maxSupply;

    address public factory; // only factory can mint
    IERC5484.BurnAuth public defaultBurnAuth;

    // State
    uint256 public mintedCount;
    bool public mintingClosed;

    mapping(uint256 => TokenData) private _tokenData;
    mapping(address => bool) public hasSBT;

    event Mint(address indexed to, uint256 indexed tokenId, string metadataURI);

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _description,
        string memory _baseCID,
        uint256 _maxSupply,
        IERC5484.BurnAuth _defaultBurnAuth,
        address _factory
    )
        ERC721(_name, _symbol)
        Ownable(_factory)
    {
        description = _description;
        baseCID = _baseCID;
        maxSupply = _maxSupply;
        defaultBurnAuth = _defaultBurnAuth;
        factory = _factory;

        // Make factory actual owner
        _transferOwnership(_factory);
    }

    modifier onlyFactory() {
        if (msg.sender != factory) revert NotFactory();
        _;
    }

    modifier whenMintingOpen() {
        if (mintingClosed) revert MintingClosed();
        _;
    }

    // -------------------------------------------------------
    //                     MINT
    // -------------------------------------------------------
    function mint(address to) external onlyFactory whenMintingOpen returns (uint256) {
        if (to == address(0)) revert InvalidAddress();
        if (hasSBT[to]) revert AlreadyHasSBT(to);
        if (maxSupply != 0 && mintedCount >= maxSupply) revert MaxSupplyReached();

        uint256 tokenId = ++mintedCount;

        _safeMint(to, tokenId);

        _tokenData[tokenId] = TokenData({ holder: to, burnAuth: defaultBurnAuth });

        hasSBT[to] = true;

        string memory metadataURI =
            string(abi.encodePacked("ipfs://", baseCID, "/", Strings.toString(tokenId), ".json"));

        emit Issued(msg.sender, to, tokenId, defaultBurnAuth);
        emit Mint(to, tokenId, metadataURI);

        return tokenId;
    }

    function closeMinting() external onlyFactory {
        mintingClosed = true;
    }

    // -------------------------------------------------------
    //                       BURN
    // -------------------------------------------------------
    function burn(uint256 tokenId) external {
        if (ownerOf(tokenId) == address(0)) revert URIQueryForNonexistentToken();

        TokenData memory data = _tokenData[tokenId];
        address holder = data.holder;

        if (data.burnAuth == IERC5484.BurnAuth.Neither) revert NonBurnable();

        if (data.burnAuth == IERC5484.BurnAuth.IssuerOnly) {
            if (msg.sender != factory) revert IssuerOnly();
        } else if (data.burnAuth == IERC5484.BurnAuth.OwnerOnly) {
            if (msg.sender != holder) revert OwnerOnly();
        } else if (data.burnAuth == IERC5484.BurnAuth.Both) {
            if (msg.sender != holder && msg.sender != factory) revert Both();
        }

        hasSBT[holder] = false;
        delete _tokenData[tokenId];

        _burn(tokenId);
    }

    function burnAuth(uint256 tokenId) external view override returns (IERC5484.BurnAuth) {
        return _tokenData[tokenId].burnAuth;
    }

    // -------------------------------------------------------
    //                SOULBOUND ENFORCEMENT
    // -------------------------------------------------------
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

    // -------------------------------------------------------
    //                     METADATA
    // -------------------------------------------------------
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (ownerOf(tokenId) == address(0)) revert URIQueryForNonexistentToken();

        string memory image = string(
            abi.encodePacked(
                "ipfs://",
                baseCID,
                "/",
                Strings.toString(tokenId),
                ".jpg"
            )
        );

        bytes memory json = abi.encodePacked(
            "{",
                '"name":"', name(), " #", Strings.toString(tokenId), '",',
                '"description":"', description, '",',
                '"image":"', image, '",',
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


    function getTokenData(uint256 tokenId) external view returns (address holder, IERC5484.BurnAuth auth) {
        if (ownerOf(tokenId) == address(0)) revert URIQueryForNonexistentToken();
        TokenData memory data = _tokenData[tokenId];
        return (data.holder, data.burnAuth);
    }

    function totalSupply() external view returns (uint256) {
        return mintedCount;
    }

    // -------------------------------------------------------
    //                     INTERFACE
    // -------------------------------------------------------
    function supportsInterface(bytes4 interfaceId) public view override(ERC721) returns (bool) {
        return interfaceId == type(IERC5484).interfaceId || super.supportsInterface(interfaceId);
    }
}
