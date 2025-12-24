//SPDX-License-Identifier: MIT License
pragma solidity >=0.8.31;

interface IIndex {
    /// @notice Connects the garden to a specified index
    /// @param indexAddress The address of the index to connect to
    function connectToIndex(address indexAddress) external;

    /// @notice Disconnects the garden from its currently connected index
    function disconnectFromIndex() external;

    /// @notice Manually triggers a rebalance of the portfolio to match index weights
    function rebalance() external;

    /// @notice Checks if the garden is currently connected to an index
    /// @return True if connected to an index, false otherwise
    function isConnectedToIndex() external view returns (bool);
}
