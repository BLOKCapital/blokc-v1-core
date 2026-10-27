// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

/// @title IGardenFactory
/// @author BLOK Capital DAO
/// @notice Interface for the Garden Factory that deploys deterministic Garden (Diamond) contracts.
/// @dev Gardens are deployed via CREATE2 with per-user indices (1–10) and initialized with
///      facets determined by the specified garden type from the Facet Registry.
interface IGardenFactory {
    /// @notice Creates a new garden (Diamond) contract for the caller
    /// @dev The garden is deployed using CREATE2 with a deterministic address based on the owner, index, and factory.
    ///      Each user can deploy up to 10 gardens (indices 1-10). The garden is initialized with facets
    ///      for the specified garden type (BASE module + allowed modules) from the facet registry.
    /// @param index The per-user garden index (must be between 1 and 10, inclusive)
    /// @param gardenType The type of garden to create (determines which modules/facets are included)
    /// @return gardenAddress The address of the newly deployed garden contract
    function createGarden(uint256 index, bytes32 gardenType) external returns (address gardenAddress);

    /// @notice Returns all gardens created by this factory
    /// @return gardens Array of all registered garden addresses
    function getAllGardens() external view returns (address[] memory gardens);

    /// @notice Returns all gardens created by a specific user
    /// @dev This is a creation-time index: it is keyed by the original creator and does NOT follow
    ///      ERC-173 ownership transfers. For the garden's current owner use `getGardenOwner`; for
    ///      gardens currently owned by a user use `getGardensOwnedBy`.
    /// @param user The address of the creator
    /// @return gardens Array of garden addresses created by the specified user
    function getUserGardens(address user) external view returns (address[] memory gardens);

    /// @notice Returns the garden associated with a specific user and index.
    /// @param user The owner of the garden.
    /// @param index The per-user garden index (1..10).
    /// @return The address of the garden associated with the given user and index.
    function getGarden(address user, uint256 index) external view returns (address);

    /// @notice Checks if a garden is registered in the factory.
    /// @param garden The address of the garden to check.
    /// @return True if the garden is registered, false otherwise.
    function isGardenRegistered(address garden) external view returns (bool);

    /// @notice Returns the total number of gardens created by this factory
    /// @return count The total number of registered gardens
    function getTotalGardens() external view returns (uint256 count);

    /// @notice Returns the number of gardens created by a specific user
    /// @dev Creator-indexed like `getUserGardens`: it does not follow ownership transfers.
    /// @param user The address of the creator
    /// @return count The number of gardens created by the user
    function getUserGardenCount(address user) external view returns (uint256 count);

    /// @notice Returns which indices (1-10) are still available for a user
    /// @param user The address of the user
    /// @return availableIndices Array of available index values
    function getUserAvailableIndices(address user) external view returns (uint256[] memory availableIndices);

    /// @notice Returns which indices (1-10) are already used by a user
    /// @param user The address of the user
    /// @return usedIndices Array of used index values
    function getUserUsedIndices(address user) external view returns (uint256[] memory usedIndices);

    /// @notice Returns a paginated subset of all gardens
    /// @param offset The starting index in the gardens set
    /// @param limit The maximum number of gardens to return
    /// @return gardens Array of garden addresses in the requested range
    function getGardensByRange(uint256 offset, uint256 limit) external view returns (address[] memory gardens);

    /// @notice Returns the facet registry address used by this factory
    /// @return The facet registry contract address
    function getFacetRegistry() external view returns (address);

    /// @notice Returns the protocol status address used by this factory
    /// @return The protocol status contract address
    function getProtocolStatus() external view returns (address);

    /// @notice Checks whether a specific index is available for a user
    /// @param user The address of the user
    /// @param index The index to check (1-10)
    /// @return True if the index is available, false otherwise
    function isIndexAvailable(address user, uint256 index) external view returns (bool);

    // ========================================================================
    //                       GARDEN TYPE VIEW FUNCTIONS
    // ========================================================================

    /// @notice Returns the garden type of a deployed garden
    /// @param garden The address of the garden
    /// @return The garden type identifier (bytes32(0) if not registered)
    function getGardenType(address garden) external view returns (bytes32);

    /// @notice Returns the CURRENT ERC-173 owner of a deployed garden
    /// @dev Reads `IERC173(garden).owner()` live, so it follows ownership transfers. Falls back to
    ///      the creator recorded at registration if the garden no longer exposes `owner()`.
    /// @param garden The address of the garden
    /// @return The current owner address (address(0) if not registered)
    function getGardenOwner(address garden) external view returns (address);

    /// @notice Returns all registered gardens whose CURRENT ERC-173 owner is `user`
    /// @dev Unlike `getUserGardens`, this is a live ownership query, not a creation-time index.
    ///      Gardens whose `owner()` call reverts are skipped.
    /// @param user The address of the current owner
    /// @return gardens Array of garden addresses currently owned by the user
    function getGardensOwnedBy(address user) external view returns (address[] memory gardens);

    /// @notice Returns the number of registered gardens whose CURRENT ERC-173 owner is `user`
    /// @dev Live ownership query equivalent to `getGardensOwnedBy(user).length`; reverting
    ///      `owner()` calls are skipped.
    /// @param user The address of the current owner
    /// @return count The number of gardens currently owned by the user
    function getGardensOwnedByCount(address user) external view returns (uint256 count);

    /// @notice Returns all gardens of a specific type
    /// @param gardenType The garden type identifier
    /// @return gardens Array of garden addresses of the specified type
    function getGardensByType(bytes32 gardenType) external view returns (address[] memory gardens);

    /// @notice Returns the total number of gardens of a specific type
    /// @param gardenType The garden type identifier
    /// @return count The number of gardens of the specified type
    function getGardensByTypeCount(bytes32 gardenType) external view returns (uint256 count);

    /// @notice Returns a paginated subset of gardens of a specific type
    /// @param gardenType The garden type identifier
    /// @param offset The starting index
    /// @param limit The maximum number of gardens to return
    /// @return gardens Array of garden addresses in the requested range
    function getGardensByTypeRange(
        bytes32 gardenType,
        uint256 offset,
        uint256 limit
    )
        external
        view
        returns (address[] memory gardens);

    /// @notice Returns all gardens of a specific type created by a user
    /// @dev Creator-indexed like `getUserGardens`: it does NOT follow ERC-173 ownership transfers.
    ///      Use `getGardenOwner` for current ownership, or filter `getGardensOwnedBy` by garden type.
    /// @param user The address of the creator
    /// @param gardenType The garden type identifier
    /// @return gardens Array of garden addresses of the specified type created by the user
    function getUserGardensByType(address user, bytes32 gardenType) external view returns (address[] memory gardens);

    /// @notice Returns the number of gardens of a specific type created by a user
    /// @dev Creator-indexed like `getUserGardensByType`: it does not follow ownership transfers.
    /// @param user The address of the creator
    /// @param gardenType The garden type identifier
    /// @return count The number of gardens of the specified type created by the user
    function getUserGardensByTypeCount(address user, bytes32 gardenType) external view returns (uint256 count);

    /// @notice Returns full info for a single garden in one call
    /// @dev `owner` is the live ERC-173 owner, matching `getGardenOwner`.
    /// @param garden The address of the garden
    /// @return owner The garden's current owner
    /// @return gardenType The garden type identifier
    /// @return registered Whether the garden is registered in the factory
    function getGardenInfo(address garden) external view returns (address owner, bytes32 gardenType, bool registered);

    /// @notice Returns all gardens and their types for a user in one call
    /// @param user The address of the user
    /// @return gardens Array of the user's garden addresses
    /// @return gardenTypes Array of corresponding garden type identifiers
    function getUserGardenInfos(address user)
        external
        view
        returns (address[] memory gardens, bytes32[] memory gardenTypes);
}
