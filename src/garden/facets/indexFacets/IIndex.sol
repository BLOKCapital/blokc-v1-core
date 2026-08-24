// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { SwapInstruction } from "src/interfaces/ISwapInstruction.sol";

/// @notice A single swap step used to rebalance the garden.
///         The dexId is used to resolve the swap selector from the PoolRegistry at execution time.
/// @param dexId DEX identifier (e.g. keccak256("UNISWAP_V3")) — resolved to a selector on-chain
/// @param instruction The universal SwapInstruction containing tokens, pools, amounts
struct SwapStep {
    bytes32 dexId;
    SwapInstruction instruction;
}

/// @notice Pending rebalance intent data (slimmed for gas efficiency)
/// @param active Whether there's an active pending intent
/// @param totalValueUsd Total value of the garden in USD at the time of intent creation
/// @param symbols Array of token symbols in the garden (bytes32 encoded)
/// @param targetValues Array of target token values based on the index (same order as symbols)
struct PendingIntent {
    bool active;
    uint256 totalValueUsd;
    bytes32[] symbols;
    uint256[] targetValues;
}

/// @title IIndex
/// @author BLOK Capital DAO
/// @notice Interface for Index Facet operations, enabling gardens to connect to indices for automated rebalancing
/// @dev Defines events and functions for managing index connections, creating rebalance intents, and executing
///      rebalances with caller-provided swap calls
interface IIndex {
    // ========================================================================
    // Events
    // ========================================================================

    /// @notice Emitted when a garden connects to an index
    /// @param indexAddress The address of the index contract that was connected
    event IndexConnected(address indexed indexAddress);

    /// @notice Emitted when a garden disconnects from an index
    /// @param indexAddress The address of the index contract that was disconnected
    event IndexDisconnected(address indexed indexAddress);

    /// @notice Emitted when a rebalance intent is created
    /// @param garden The address of the garden creating the intent
    /// @param indexAddress The address of the connected index contract
    /// @param symbols Array of token symbols included in the rebalance (bytes32 encoded)
    /// @param currentValues Array of current token values in USD (8 decimals)
    /// @param targetValues Array of target token values in USD (8 decimals)
    /// @param totalValueUsd Total portfolio value in USD (8 decimals)
    event RebalanceIntentCreated(
        address indexed garden,
        address indexed indexAddress,
        bytes32[] symbols,
        uint256[] currentValues,
        uint256[] targetValues,
        uint256 totalValueUsd
    );

    /// @notice Emitted when a rebalance is completed
    /// @param garden The address of the garden that was rebalanced
    /// @param indexAddress The address of the connected index contract
    /// @param timestamp The block timestamp when the rebalance was executed
    /// @param nextRebalanceTimestamp The earliest timestamp at which the next rebalance can occur
    event RebalanceCompleted(
        address indexed garden, address indexed indexAddress, uint256 timestamp, uint256 nextRebalanceTimestamp
    );

    // ========================================================================
    // Functions
    // ========================================================================

    /// @notice Connect the garden to an index for automated rebalancing
    /// @param indexAddress Address of the index contract to connect to
    function connectToIndex(address indexAddress) external;

    /// @notice Disconnect the garden from its connected index
    function disconnectFromIndex() external;

    /// @notice Create a rebalance intent - calculates target allocations
    /// @dev Can be called by anyone (permissionless)
    function rebalanceIntent() external;

    /// @notice Execute rebalance with caller-provided swap steps
    /// @dev Can be called by anyone (permissionless).
    ///      Each SwapStep contains a dexId (resolved to a selector on-chain via PoolRegistry)
    ///      and a universal SwapInstruction with tokens, pools, and amounts.
    /// @param steps Array of swap steps from the caller
    function rebalance(SwapStep[] calldata steps) external;

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
        returns (bool active, uint256 totalValueUsd, bytes32[] memory symbols, uint256[] memory targetValues);
}
