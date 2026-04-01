// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

/// @notice A single swap instruction provided by the CRE to rebalance the garden
/// @param selector The function selector of the DEX facet function to call
/// @param data The ABI-encoded arguments for the function (excluding selector)
/// @param outputToken The ERC20 token expected to increase in balance after this swap
/// @param minOutput The minimum amount of outputToken the garden must receive from this swap
struct SwapCall {
    bytes4 selector;
    bytes data;
    address outputToken;
    uint256 minOutput;
}

/// @title IIndex
/// @author BLOK Capital DAO
/// @notice Interface for Index Facet operations, enabling gardens to connect to indices for automated rebalancing.
/// @dev Single-transaction rebalance: CRE submits SwapCall[] directly, contract validates the outcome
///      using fresh Chainlink prices. No intent system needed — on-chain verification is the safety net.
interface IIndex {
    // ========================================================================
    // Events
    // ========================================================================

    /// @notice Emitted when a garden connects to an index
    event IndexConnected(address indexed indexAddress);

    /// @notice Emitted when a garden disconnects from an index
    event IndexDisconnected(address indexed indexAddress);

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

    /// @notice Execute rebalance with CRE-provided swap calls (single transaction)
    /// @dev Can be called by anyone. Each SwapCall targets a DEX facet function on this Diamond.
    ///      The contract validates the outcome: balances must match target weights within threshold,
    ///      total value must be preserved within MAX_VALUE_LOSS_BPS. If validation fails, the entire
    ///      transaction reverts — no funds are at risk from bad swap calls.
    /// @param swapCalls Array of swap calls from CRE
    function rebalance(SwapCall[] calldata swapCalls) external;

    /// @notice Check if the garden is connected to an index
    function isConnectedToIndex() external view returns (bool);

    /// @notice Get the connected index address
    function getConnectedIndex() external view returns (address);

    /// @notice Get the timestamp of the last rebalance execution
    function getLastRebalanceTimestamp() external view returns (uint256);
}
