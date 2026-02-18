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
    /// @param collection The SBT collection address to mint from
    /// @param tokenId The token ID of the SBT to mint
    /// @param gardenType The type of garden to create (determines which modules/facets are included)
    /// @return gardenAddress The address of the newly deployed garden contract
    function createGarden(
        uint256 index,
        address collection,
        uint256 tokenId,
        bytes32 gardenType
    )
        external
        returns (address gardenAddress);

    /// @notice Returns all gardens created by this factory
    /// @return gardens Array of all registered garden addresses
    function getAllGardens() external view returns (address[] memory gardens);

    /// @notice Returns all gardens created by a specific user
    /// @param user The address of the user
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
}
