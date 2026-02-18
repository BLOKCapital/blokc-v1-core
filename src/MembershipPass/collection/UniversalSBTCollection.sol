// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC5484 } from "src/interfaces/IERC5484.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/// @notice Thrown when caller is not the factory contract
error NotFactory();

/// @notice Thrown when an invalid address (zero) is provided
error InvalidAddress();

/// @notice Thrown when a soulbound token transfer is attempted
error NonTransferable();

/// @notice Thrown when approval is attempted on a soulbound token
error ApproveNotAllowed();

/// @notice Thrown when recipient already holds an SBT
/// @param to The address that already has an SBT
error AlreadyHasSBT(address to);

/// @notice Thrown when max supply limit is reached
error MaxSupplyReached();

/// @notice Thrown when minting has been permanently closed
error MintingClosed();

/// @notice Thrown when burning is attempted on a non-burnable token
error NonBurnable();

/// @notice Thrown when burn is attempted by non-issuer on an IssuerOnly token
error IssuerOnly();

/// @notice Thrown when burn is attempted by non-owner on an OwnerOnly token
error OwnerOnly();

/// @notice Thrown when burn is attempted by neither owner nor issuer on a Both-auth token
error Both();

/// @notice Thrown when querying URI for a non-existent token
error URIQueryForNonexistentToken();

/// @title UniversalSBTCollection
/// @author BLOK Capital DAO
/// @notice Universal Soulbound Token collection with configurable burn authority
/// @dev Implements ERC-5484 (Consensual Soulbound Tokens). Deployed by SBTMembershipFactory.
///      Tokens are non-transferable. Burn authority is configurable per collection
///      (Neither, IssuerOnly, OwnerOnly, or Both). Metadata stored on IPFS.
contract UniversalSBTCollection is ERC721, Ownable, IERC5484 {
    /// @notice Per-token data storing holder and burn authority
    /// @param holder Original token holder address
    /// @param burnAuth Burn authority for this specific token
    struct TokenData {
        address holder;
        IERC5484.BurnAuth burnAuth;
    }

    /// @notice Human-readable description of the collection
    string public description;

    /// @notice IPFS base CID for token metadata
    string public baseCid;

    /// @notice Maximum supply (0 = unlimited)
    uint256 public maxSupply;

    /// @notice Address of the factory that deployed this collection (only factory can mint)
    address public factory;

    /// @notice Default burn authority applied to newly minted tokens
    IERC5484.BurnAuth public defaultBurnAuth;

    /// @notice Total number of tokens minted
    uint256 public mintedCount;

    /// @notice Whether minting has been permanently closed
    bool public mintingClosed;

    /// @notice Per-token metadata mapping
    mapping(uint256 => TokenData) private _tokenData;

    /// @notice Tracks whether an address already holds an SBT
    mapping(address => bool) public hasSbt;

    /// @notice Emitted when a new SBT is minted
    /// @param to Recipient address
    /// @param tokenId Minted token ID
    /// @param metadataURI IPFS metadata URI
    event Mint(address indexed to, uint256 indexed tokenId, string metadataURI);

    /// @notice Deploys the collection with the specified parameters
    /// @param _name ERC721 token name
    /// @param _symbol ERC721 token symbol
    /// @param _description Human-readable collection description
    /// @param _baseCid IPFS base CID for metadata
    /// @param _maxSupply Maximum supply (0 = unlimited)
    /// @param _defaultBurnAuth Default burn authority for minted tokens
    /// @param _factory Address of the SBTMembershipFactory (becomes owner)
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _description,
        string memory _baseCid,
        uint256 _maxSupply,
        IERC5484.BurnAuth _defaultBurnAuth,
        address _factory
    )
        ERC721(_name, _symbol)
        Ownable(_factory)
    {
        description = _description;
        baseCid = _baseCid;
        maxSupply = _maxSupply;
        defaultBurnAuth = _defaultBurnAuth;
        factory = _factory;

        // Make factory actual owner
        _transferOwnership(_factory);
    }

    modifier onlyFactory() {
        _onlyFactory();
        _;
    }

    function _onlyFactory() internal view {
        if (msg.sender != factory) revert NotFactory();
    }

    modifier whenMintingOpen() {
        _whenMintingOpen();
        _;
    }

    function _whenMintingOpen() internal view {
        if (mintingClosed) revert MintingClosed();
    }

    /// @notice Mints a new soulbound token to the specified address
    /// @param to Recipient address
    /// @return The minted token ID (auto-incremented)
    /// @dev Only callable by the factory. Auto-increments token ID.
    function mint(address to) external onlyFactory whenMintingOpen returns (uint256) {
        if (to == address(0)) revert InvalidAddress();
        if (hasSbt[to]) revert AlreadyHasSBT(to);
        if (maxSupply != 0 && mintedCount >= maxSupply) revert MaxSupplyReached();

        uint256 tokenId = ++mintedCount;

        _safeMint(to, tokenId);

        _tokenData[tokenId] = TokenData({ holder: to, burnAuth: defaultBurnAuth });

        hasSbt[to] = true;

        string memory metadataURI =
            string(abi.encodePacked("ipfs://", baseCid, "/", Strings.toString(tokenId), ".json"));

        emit Issued(msg.sender, to, tokenId, defaultBurnAuth);
        emit Mint(to, tokenId, metadataURI);

        return tokenId;
    }

    /// @notice Permanently closes minting for this collection
    function closeMinting() external onlyFactory {
        mintingClosed = true;
    }

    /// @notice Burns a token according to its burn authority
    /// @param tokenId Token ID to burn
    /// @dev Authorization depends on the token's burnAuth: IssuerOnly (factory), OwnerOnly (holder),
    ///      Both (either), or Neither (reverts always).
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

        hasSbt[holder] = false;
        delete _tokenData[tokenId];

        _burn(tokenId);
    }

    /// @inheritdoc IERC5484
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

    /// @notice Returns the IPFS metadata URI for a given token
    /// @param tokenId Token ID to query
    /// @return IPFS metadata URI string
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (ownerOf(tokenId) == address(0)) revert URIQueryForNonexistentToken();
        return string(abi.encodePacked("ipfs://", baseCid, "/", Strings.toString(tokenId), ".json"));
    }

    /// @notice Returns the token data including holder and burn authority
    /// @param tokenId Token ID to query
    /// @return holder Original token holder address
    /// @return auth Burn authority for this token
    function getTokenData(uint256 tokenId) external view returns (address holder, IERC5484.BurnAuth auth) {
        if (ownerOf(tokenId) == address(0)) revert URIQueryForNonexistentToken();
        TokenData memory data = _tokenData[tokenId];
        return (data.holder, data.burnAuth);
    }

    /// @notice Returns the total number of minted tokens
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
