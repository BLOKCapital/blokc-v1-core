//SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/*###############################################################################

    @title Index
    @author BLOK Capital DAO
    @notice Core index contract that manages component weights and connected gardens
    @dev Implements a rebalanceable index with configurable calculation methods.
         Gardens (investment vehicles) connect to indices to track their composition.
         Weights are automatically recalculated during rebalancing using the specified
         calculation strategy (e.g., market cap weighted).

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IIndexCalculation } from "src/interfaces/IIndexCalculation.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IndexComponentRegistry } from "src/BlokcIndices/IndexComponentRegistry.sol";

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
/// @param componentAddress Address of the unregistered component
error Index_ComponentNotRegistered(address componentAddress);

contract Index is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Minimum time interval between rebalances
    /// @dev Set to 1 hour to prevent excessive rebalancing and associated gas costs
    uint256 public constant REBALANCE_INTERVAL = 1 hours;

    /// @notice Reference to the calculation strategy contract (e.g., market cap weighted)
    /// @dev Immutable to ensure index methodology remains consistent
    IIndexCalculation public immutable indexCalculation;

    /// @notice Reference to the component registry for validation
    /// @dev Immutable to ensure consistent component validation
    IndexComponentRegistry public immutable indexComponentRegistry;

    /// @notice Mapping of component addresses to their current weights
    /// @dev Weights are scaled to 1e18 (100% = 1e18)
    mapping(address => uint256) private _componentWeights;

    /// @notice Timestamp of the last rebalance
    /// @dev Used to enforce REBALANCE_INTERVAL
    uint256 private _lastRebalanceTimestamp;

    /// @notice Set of component token addresses in this index
    /// @dev EnumerableSet provides efficient iteration and membership checks
    EnumerableSet.AddressSet private _componentAddresses;

    /// @notice Set of garden addresses connected to this index
    /// @dev Gardens track this index's composition for their portfolios
    EnumerableSet.AddressSet private _connectedGardens;

    /// @notice Constructs a new Index with specified components and calculation method
    /// @param initialOwner Address of the contract owner
    /// @param indexCalculationAddress Address of the calculation strategy contract
    /// @param indexComponentRegistryAddress Address of the component registry
    /// @param componentAddresses Array of component token addresses to include in index
    /// @dev Validates all addresses, ensures components are registered, and performs initial rebalance
    constructor(
        address initialOwner,
        address indexCalculationAddress,
        address indexComponentRegistryAddress,
        address[] memory componentAddresses
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

        indexCalculation = IIndexCalculation(indexCalculationAddress);
        indexComponentRegistry = IndexComponentRegistry(indexComponentRegistryAddress);

        for (uint256 i = 0; i < componentAddresses.length; i++) {
            if (!indexComponentRegistry.isComponentRegistered(componentAddresses[i])) {
                revert Index_ComponentNotRegistered(componentAddresses[i]);
            }
            _componentAddresses.add(componentAddresses[i]);
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
        if (_connectedGardens.contains(msg.sender)) {
            revert Index_GardenAlreadyConnected(msg.sender);
        }

        _connectedGardens.add(msg.sender);
    }

    /// @notice Disconnects a garden (msg.sender) from this index
    /// @dev Gardens call this when they no longer want to track this index
    function disconnectGardenFromIndex() external {
        if (!_connectedGardens.contains(msg.sender)) {
            revert Index_GardenNotConnected(msg.sender);
        }
        _connectedGardens.remove(msg.sender);
    }

    //=======================================================================
    // View Functions
    //=======================================================================

    /// @notice Returns the current weights for all components in the index
    /// @return componentAddresses Array of component token addresses
    /// @return weights Array of weights (scaled to 1e18, where 1e18 = 100%)
    /// @dev Arrays are parallel - weights[i] corresponds to componentAddresses[i]
    function getWeights() external view returns (address[] memory componentAddresses, uint256[] memory weights) {
        componentAddresses = new address[](_componentAddresses.length());
        weights = new uint256[](_componentAddresses.length());
        for (uint256 i = 0; i < _componentAddresses.length(); i++) {
            componentAddresses[i] = _componentAddresses.at(i);
            weights[i] = _componentWeights[componentAddresses[i]];
        }
    }

    /// @notice Returns the timestamp of the last rebalance
    /// @return The block timestamp when the last rebalance occurred
    function getLastUpdatedTimestamp() external view returns (uint256) {
        return _lastRebalanceTimestamp;
    }

    /// @notice Returns all gardens currently connected to this index
    /// @return Array of connected garden addresses
    function getConnectedGardens() external view returns (address[] memory) {
        return _connectedGardens.values();
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
        address[] memory componentAddresses = new address[](_componentAddresses.length());
        for (uint256 i = 0; i < _componentAddresses.length(); i++) {
            componentAddresses[i] = _componentAddresses.at(i);
        }

        uint256[] memory weights = indexCalculation.getWeights(componentAddresses);

        if (weights.length != componentAddresses.length) {
            revert Index_WeightsMismatch(weights.length, componentAddresses.length);
        }

        for (uint256 i = 0; i < componentAddresses.length; i++) {
            _componentWeights[componentAddresses[i]] = weights[i];
        }

        _lastRebalanceTimestamp = block.timestamp;
    }
}
