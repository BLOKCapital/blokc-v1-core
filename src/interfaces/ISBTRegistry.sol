// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

/// @title ISBTRegistry
/// @author BLOK Capital DAO
/// @notice Interface for the Soulbound Token (SBT) Registry that manages collections and minting.
/// @dev Provides collection registration, minting dispatch, and ownership management.
interface ISBTRegistry {
    // ========================================================================
    //                              ERRORS
    // ========================================================================

    /// @notice Thrown when the caller is not authorized to perform the action.
    error NotAuthorized();

    /// @notice Thrown when a provided address is the zero address.
    error InvalidAddress();

    /// @notice Thrown when attempting to register a collection with a name that already exists.
    /// @param name The duplicate collection name.
    error CollectionExists(string name);

    /// @notice Thrown when the referenced collection is not found in the registry.
    error CollectionNotFound();

    /// @notice Thrown when a mint call to the underlying collection reverts.
    /// @param collection The collection address that failed to mint.
    error MintFailed(address collection);

    /// @notice Thrown when the caller is not the owner of the collection.
    error NotCollectionOwner();

    // ========================================================================
    //                              EVENTS
    // ========================================================================

    /// @notice Emitted when a new SBT collection is registered.
    /// @param name The name of the registered collection.
    /// @param collection The address of the collection contract.
    event RegisteredCollection(string indexed name, address indexed collection);

    /// @notice Emitted when a token is minted from a collection.
    /// @param collection The collection the token was minted from.
    /// @param to The recipient of the minted token.
    /// @param tokenId The identifier of the minted token.
    event Minted(address indexed collection, address indexed to, uint256 tokenId);

    /// @notice Emitted when the registry owner is updated.
    /// @param newOwner The address of the new owner.
    event OwnerSet(address indexed newOwner);

    // ========================================================================
    //                          OWNER MANAGEMENT
    // ========================================================================

    /// @notice Returns the current owner of the registry.
    /// @return The owner address.
    function owner() external view returns (address);

    /// @notice Transfers ownership of the registry to a new address.
    /// @param newOwner The address of the new owner.
    function setOwner(address newOwner) external;

    // ========================================================================
    //                        COLLECTION MANAGEMENT
    // ========================================================================

    /// @notice Registers a new SBT collection in the registry.
    /// @param name A unique human-readable name for the collection.
    /// @param collection The address of the deployed SBT collection contract.
    function registerCollection(string calldata name, address collection) external;

    // ========================================================================
    //                              MINTING
    // ========================================================================

    /// @notice Mints a token from a registered collection to a specified recipient.
    /// @param collection The collection contract address to mint from.
    /// @param to The address that will receive the minted token.
    /// @param tokenId The identifier to assign to the minted token.
    /// @return The token ID of the minted token.
    function mintByAddress(address collection, address to, uint256 tokenId) external returns (uint256);

    // ========================================================================
    //                               VIEWS
    // ========================================================================

    /// @notice Returns all registered collection addresses.
    /// @return Array of collection contract addresses.
    function getAllCollections() external view returns (address[] memory);
}
