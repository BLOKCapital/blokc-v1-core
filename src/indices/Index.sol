//SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IIndexCalculation } from "src/interfaces/IIndexCalculation.sol";
import { IIndex } from "src/interfaces/IIndex.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IndexComponentRegistry } from "src/indices/IndexComponentRegistry.sol";

import { IGardenFactory } from "src/interfaces/IGardenFactory.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when initial owner address is zero
/// @param initialOwner The invalid owner address
error Index_InvalidInitialOwner(address initialOwner);

/// @notice Thrown when index calculation contract address is zero
/// @param indexCalculationAddress The invalid calculation address
error Index_InvalidIndexCalculationAddress(address indexCalculationAddress);

/// @notice Thrown when index component registry address is zero
/// @param indexComponentRegistryAddress The invalid registry address
error Index_InvalidIndexComponentRegistryAddress(address indexComponentRegistryAddress);

/// @notice Thrown when garden factory address is zero
/// @param gardenFactoryAddress The invalid garden factory address
error Index_InvalidGardenFactoryAddress(address gardenFactoryAddress);

/// @notice Thrown when calculated weights length doesn't match components length
/// @param weightsLength Length of returned weights array
/// @param componentAddressesLength Length of components array
error Index_WeightsMismatch(uint256 weightsLength, uint256 componentAddressesLength);

/// @notice Thrown when attempting to rebalance before REBALANCE_INTERVAL has passed
error Index_RebalanceTooSoon();

/// @notice Thrown when garden attempts to connect but is already connected
/// @param garden Address of the already connected garden
error Index_GardenAlreadyConnected(address garden);

/// @notice Thrown when garden attempts to disconnect but is not connected
/// @param garden Address of the not connected garden
error Index_GardenNotConnected(address garden);

/// @notice Thrown when attempting to add unregistered component to index
/// @param symbol Symbol of the unregistered component
error Index_ComponentNotRegistered(bytes32 symbol);

/// @notice Thrown when a duplicate symbol is provided during index creation
/// @param symbol The duplicate symbol
error Index_DuplicateSymbol(bytes32 symbol);

/// @notice Thrown when maximum connected gardens limit is reached
error Index_MaxConnectedGardensReached();

/// @notice Thrown when calculated weights do not sum to approximately 1e18
error Index_InvalidWeightSum(uint256 weightSum);

/// @notice Thrown when caller has no contract code (EOA)
error Index_CallerNotContract();

/// @notice Thrown when caller is not a registered garden
/// @param caller Address of the caller that is not a registered garden
error Index_CallerNotGarden(address caller);

/**
 * @title Index
 * @notice The Index contract manages the composition and weights of components in a decentralized index. It allows for
 * rebalancing based on a specified calculation strategy (e.g., market cap weighted) and tracks connected gardens that
 * use this index for their portfolios. The contract includes access control for the owner, enforces a minimum rebalance
 * interval, and provides functions for gardens to connect and disconnect from the index. It also includes comprehensive
 * error handling for various edge cases related to index management and garden connections.
 */
contract Index is IIndex, Ownable {
    /// @notice Minimum time interval between rebalances
    /// @dev Set to 1 hour to prevent excessive rebalancing and associated gas costs
    uint256 public constant REBALANCE_INTERVAL = 1 hours;

    /// @notice Maximum number of gardens that can connect to this index
    /// @dev Prevents unbounded set growth and gas DoS on getConnectedGardens()
    uint256 public constant MAX_CONNECTED_GARDENS = 1000;

    /// @notice Unique identifier for Index type in the garden factory
    bytes32 public constant INDEX_TYPE = keccak256("INDEX");

    /// @notice Emitted when index weights are recalculated
    event WeightsUpdated(bytes32[] symbols, uint256[] weights, uint256 timestamp);

    /// @notice Reference to the calculation strategy contract (e.g., market cap weighted)
    /// @dev Immutable to ensure index methodology remains consistent
    IIndexCalculation public immutable INDEX_CALCULATION;

    /// @notice Reference to the component registry for validation
    /// @dev Immutable to ensure consistent component validation
    IndexComponentRegistry public immutable INDEX_COMPONENT_REGISTRY;

    /// @notice Reference to the garden factory for registering this index
    /// @dev Immutable to ensure consistent interaction with garden factory
    IGardenFactory public immutable GARDEN_FACTORY;

    /// @notice Mapping of component symbols to their current weights
    /// @dev Weights are scaled to 1e18 (100% = 1e18)
    mapping(bytes32 => uint256) private _componentWeights;

    /// @notice Timestamp of the last rebalance
    /// @dev Used to enforce REBALANCE_INTERVAL
    uint256 private _lastRebalanceTimestamp;

    /// @notice Set of component symbols in this index
    /// @dev EnumerableSet provides efficient iteration and membership checks
    EnumerableSet.Bytes32Set private _componentSymbols;

    /// @notice Set of garden addresses connected to this index
    /// @dev Gardens track this index's composition for their portfolios
    EnumerableSet.AddressSet private _connectedGardens;

    /// @notice Constructs a new Index with specified components and calculation method
    /// @param initialOwner Address of the contract owner
    /// @param indexCalculationAddress Address of the calculation strategy contract
    /// @param indexComponentRegistryAddress Address of the component registry
    /// @param symbols Array of component symbols to include in index
    /// @dev Validates all addresses, ensures components are registered, and performs initial rebalance
    constructor(
        address initialOwner,
        address indexCalculationAddress,
        address indexComponentRegistryAddress,
        address gardenFactoryAddress,
        bytes32[] memory symbols
    )
        Ownable(initialOwner)
    {
        if (initialOwner == address(0)) revert Index_InvalidInitialOwner(initialOwner);
        if (indexCalculationAddress == address(0)) {
            revert Index_InvalidIndexCalculationAddress(indexCalculationAddress);
        }
        if (indexComponentRegistryAddress == address(0)) {
            revert Index_InvalidIndexComponentRegistryAddress(indexComponentRegistryAddress);
        }
        if (gardenFactoryAddress == address(0)) {
            revert Index_InvalidGardenFactoryAddress(gardenFactoryAddress);
        }

        INDEX_CALCULATION = IIndexCalculation(indexCalculationAddress);
        INDEX_COMPONENT_REGISTRY = IndexComponentRegistry(indexComponentRegistryAddress);
        GARDEN_FACTORY = IGardenFactory(gardenFactoryAddress);

        for (uint256 i = 0; i < symbols.length; i++) {
            bytes32 symbol = symbols[i];
            if (!INDEX_COMPONENT_REGISTRY.isComponentRegistered(symbol)) {
                revert Index_ComponentNotRegistered(symbol);
            }
            if (!EnumerableSet.add(_componentSymbols, symbol)) {
                revert Index_DuplicateSymbol(symbol);
            }
        }

        _rebalance();
    }

    /// @notice Triggers a rebalance of the index weights
    /// @dev Can be called by anyone after REBALANCE_INTERVAL has passed
    ///      Calls internal _rebalance() which updates weights using the calculation strategy
    function rebalance() external {
        _rebalance();
    }

    //=======================================================================
    // Garden Management Functions
    //=======================================================================

    /// @notice Connects a garden (msg.sender) to this index
    /// @dev Allows gardens to track this index for portfolio management
    ///      Gardens must call this before using the index's weights
    function connectGardenToIndex() external {
        bytes32 gardenType = GARDEN_FACTORY.getGardenType(msg.sender);

        if (gardenType != INDEX_TYPE) {
            revert Index_CallerNotGarden(msg.sender);
        }
        if (EnumerableSet.length(_connectedGardens) >= MAX_CONNECTED_GARDENS) {
            revert Index_MaxConnectedGardensReached();
        }
        if (EnumerableSet.contains(_connectedGardens, msg.sender)) {
            revert Index_GardenAlreadyConnected(msg.sender);
        }

        EnumerableSet.add(_connectedGardens, msg.sender);
    }

    /// @notice Disconnects a garden (msg.sender) from this index
    /// @dev Gardens call this when they no longer want to track this index
    function disconnectGardenFromIndex() external {
        if (!EnumerableSet.contains(_connectedGardens, msg.sender)) {
            revert Index_GardenNotConnected(msg.sender);
        }
        EnumerableSet.remove(_connectedGardens, msg.sender);
    }

    //=======================================================================
    // View Functions
    //=======================================================================

    /// @notice Returns the current weights for all components in the index
    /// @return symbols Array of component symbols as bytes32
    /// @return weights Array of weights (scaled to 1e18, where 1e18 = 100%)
    /// @dev Arrays are parallel - weights[i] corresponds to symbols[i]
    function getWeights() external view returns (bytes32[] memory symbols, uint256[] memory weights) {
        uint256 len = EnumerableSet.length(_componentSymbols);
        symbols = new bytes32[](len);
        weights = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            symbols[i] = EnumerableSet.at(_componentSymbols, i);
            weights[i] = _componentWeights[symbols[i]];
        }
    }

    /// @notice Returns the timestamp of the last rebalance
    /// @return The block timestamp when the last rebalance occurred
    function getLastUpdatedTimestamp() external view returns (uint256) {
        return _lastRebalanceTimestamp;
    }

    /// @notice Returns a paginated slice of connected gardens.
    /// @param offset Starting index in the garden list
    /// @param limit Maximum number of gardens to return
    /// @return gardens Array of garden addresses for the requested page
    /// @return total Total number of connected gardens
    function getConnectedGardens(uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory gardens, uint256 total)
    {
        total = EnumerableSet.length(_connectedGardens);
        if (offset >= total || limit == 0) return (new address[](0), total);

        uint256 end = offset + limit;
        if (end > total) end = total;
        uint256 count = end - offset;

        gardens = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            gardens[i] = EnumerableSet.at(_connectedGardens, offset + i);
        }
    }

    //=======================================================================
    // Internal Functions
    //=======================================================================

    /// @notice Internal function to recalculate and update component weights
    /// @dev Enforces REBALANCE_INTERVAL, calls calculation strategy, validates results
    ///      Updates _componentWeights and _lastRebalanceTimestamp
    function _rebalance() internal {
        if (block.timestamp - _lastRebalanceTimestamp < REBALANCE_INTERVAL) {
            revert Index_RebalanceTooSoon();
        }

        // Create array from EnumerableSet for calculation strategy
        uint256 len = EnumerableSet.length(_componentSymbols);
        bytes32[] memory symbols = new bytes32[](len);
        for (uint256 i = 0; i < len; i++) {
            symbols[i] = EnumerableSet.at(_componentSymbols, i);
        }

        uint256[] memory weights = INDEX_CALCULATION.getWeights(symbols);

        if (weights.length != symbols.length) {
            revert Index_WeightsMismatch(weights.length, symbols.length);
        }

        uint256 weightSum = 0;
        for (uint256 i = 0; i < symbols.length; i++) {
            _componentWeights[symbols[i]] = weights[i];
            weightSum += weights[i];
        }

        // Validate weights sum to ~100% (allow 0.01% tolerance for rounding, symmetric)
        if (weightSum < 1e18 - 1e14 || weightSum > 1e18 + 1e14) {
            revert Index_InvalidWeightSum(weightSum);
        }

        _lastRebalanceTimestamp = block.timestamp;

        emit WeightsUpdated(symbols, weights, block.timestamp);
    }
}
