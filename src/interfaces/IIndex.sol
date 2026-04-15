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

    /// @notice Returns all gardens currently connected to this index
    /// @return Array of connected garden addresses
    function getConnectedGardens() external view returns (address[] memory);

    /// @notice Triggers a rebalance of the index weights
    function rebalance() external;

    /// @notice Connects a garden (msg.sender) to this index
    function connectGardenToIndex() external;

    /// @notice Disconnects a garden (msg.sender) from this index
    function disconnectGardenFromIndex() external;
}
