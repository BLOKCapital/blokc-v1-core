// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/*###############################################################################

    @title IGardenFactory
    @author BLOK Capital DAO
    @notice Interface for Garden Factory

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

interface IGardenFactory {
    /// @notice Deploys a new garden proxy for the given owner and applies the initial diamond cut.
    /// @param  index The per-user garden index (1..10) selected by the user.
    /// @param  collection The address of the collection to mint from.
    /// @param  tokenId The token id to mint.
    /// @return garden The address of the newly deployed garden proxy.
    function createGarden(uint256 index, address collection, uint256 tokenId) external returns (address garden);

    /// @notice Returns all registered gardens.
    /// @return gardens Array of all registered garden addresses.
    function getAllGardens() external view returns (address[] memory gardens);

    /// @notice Returns all gardens deployed by a specific address.
    /// @param user The address of the user.
    /// @return gardens Array of garden addresses deployed by the specified address.
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
