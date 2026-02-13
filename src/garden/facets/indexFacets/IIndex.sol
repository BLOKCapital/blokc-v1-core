//SPDX-License-Identifier: MIT License
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

/// @dev CRE provides an array of these to rebalance the garden
/// @param selector The function selector of the DEX facet function to call
/// @param data The ABI-encoded arguments for the function (excluding selector)
struct SwapCall {
    bytes4 selector;
    bytes data;
}

/// @notice Pending rebalance intent data
/// @param active Whether there's an active pending intent
/// @param totalValueUsd Total value of the garden in USD at the time of intent creation
/// @param symbols Array of token symbols in the garden
/// @param currentValues Array of current token values in the garden (same order as symbols)
/// @param targetValues Array of target token values based on the index (same order as symbols)
/// @param tokenAddresses Array of token contract addresses (same order as symbols)
struct PendingIntent {
    bool active;
    uint256 totalValueUsd;
    string[] symbols;
    uint256[] currentValues;
    uint256[] targetValues;
    address[] tokenAddresses;
}

/**
 * @title IIndex
 * @author BLOK Capital DAO
 * @notice Interface for Index Facet operations, enabling gardens to connect to indices for automated rebalancing.
 * Defines events and functions for managing index connections, creating rebalance intents, and executing rebalances
 * with CRE-provided swap calls.
 */
interface IIndex {
    // ========================================================================
    // Events
    // ========================================================================

    /// @notice Emitted when garden connects to an index
    event IndexConnected(address indexed indexAddress);

    /// @notice Emitted when garden disconnects from an index
    event IndexDisconnected(address indexed indexAddress);

    /// @notice Emitted when rebalance intent is created
    event RebalanceIntentCreated(
        address indexed garden,
        address indexed indexAddress,
        string[] symbols,
        uint256[] currentValues,
        uint256[] targetValues,
        uint256 totalValueUsd
    );

    /// @notice Emitted when rebalance is completed
    event RebalanceCompleted(address indexed garden, address indexed indexAddress, uint256 timestamp);

    // ========================================================================
    // Functions
    // ========================================================================

    /// @notice Connect the garden to an index for automated rebalancing
    /// @param indexAddress Address of the index contract to connect to
    function connectToIndex(address indexAddress) external;

    /// @notice Disconnect the garden from its connected index
    function disconnectFromIndex() external;

    /// @notice Create a rebalance intent - calculates target allocations
    /// @dev Can be called by anyone (primarily CRE automation)
    function rebalanceIntent() external;

    /// @notice Execute rebalance with CRE-provided swap calls
    /// @dev Can be called by anyone (primarily CRE automation).
    ///      Each SwapCall contains:
    ///      - selector: The 4-byte function selector of a DEX facet function
    ///      - data: ABI-encoded function arguments (excluding selector)
    /// @param swapCalls Array of swap calls from CRE
    function rebalance(SwapCall[] calldata swapCalls) external;

    /// @notice Check if the garden is connected to an index
    /// @return True if connected to an index
    function isConnectedToIndex() external view returns (bool);

    /// @notice Get the connected index address
    /// @return The connected index address (address(0) if not connected)
    function getConnectedIndex() external view returns (address);

    /// @notice Check if there's a pending rebalance intent
    /// @return True if there's an active pending intent
    function hasPendingIntent() external view returns (bool);

    /// @notice Get pending intent details
    function getPendingIntent()
        external
        view
        returns (
            bool active,
            uint256 totalValueUsd,
            string[] memory symbols,
            uint256[] memory currentValues,
            uint256[] memory targetValues
        );
}
