// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

/// @title IIndex
/// @author BLOK Capital DAO
/// @notice Interface for the Index contract that manages component weights and garden connections.
interface IIndex {
    /// @notice Returns the current normalized weights for each component in the index.
    /// @return symbols Array of component symbols
    /// @return weights Array of weights (scaled to 1e18, where 1e18 = 100%)
    function getWeights() external view returns (bytes32[] memory symbols, uint256[] memory weights);

    /// @notice Returns the timestamp of the last rebalance
    /// @return The block timestamp when the last rebalance occurred
    function getLastUpdatedTimestamp() external view returns (uint256);

    /// @notice Returns a paginated slice of connected gardens.
    /// @param offset Starting index in the garden list
    /// @param limit Maximum number of gardens to return (0 returns empty array)
    /// @return gardens Array of garden addresses for the requested page
    /// @return total Total number of connected gardens
    function getConnectedGardens(uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory gardens, uint256 total);

    /// @notice Triggers a rebalance of the index weights
    function rebalance() external;

    /// @notice Connects a garden (msg.sender) to this index
    function connectGardenToIndex() external;

    /// @notice Disconnects a garden (msg.sender) from this index
    function disconnectGardenFromIndex() external;
}
