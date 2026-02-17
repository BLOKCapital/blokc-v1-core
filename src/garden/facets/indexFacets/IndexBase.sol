// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { IndexFactory } from "src/indices/IndexFactory.sol";
import { Index } from "src/indices/Index.sol";
import { IndexStorage } from "src/garden/facets/indexFacets/IndexStorage.sol";
import { IndexComponentRegistry } from "src/indices/IndexComponentRegistry.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";
import { LibDiamond } from "src/garden/libraries/LibDiamond.sol";
import { IIndex, SwapCall, PendingIntent } from "src/garden/facets/indexFacets/IIndex.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when garden is not connected to an index
error IndexFacet_NotConnectedToIndex();

/// @notice Thrown when garden is already connected to an index
error IndexFacet_AlreadyConnectedToIndex();

/// @notice Thrown when index is not registered
error IndexFacet_IndexNotRegistered(address indexAddress);

/// @notice Thrown when pending intent interval hasn't passed
error IndexFacet_IntentIntervalNotPassed();

/// @notice Thrown when rebalance interval hasn't passed
error IndexFacet_RebalanceIntervalNotPassed();

/// @notice Thrown when no pending intent exists
error IndexFacet_NoPendingIntent();

/// @notice Thrown when balance is outside threshold after rebalance
error IndexFacet_BalanceOutsideThreshold(string symbol, uint256 current, uint256 target);

/// @notice Thrown when oracle data is stale or invalid
error IndexFacet_InvalidOracleData();

/// @notice Thrown when a swap call fails
error IndexFacet_SwapCallFailed(uint256 index, bytes reason);

/// @notice Thrown when swap selector is not whitelisted
error IndexFacet_SelectorNotWhitelisted(bytes4 selector);

/// @notice Thrown when swap call returns no data (selector not found)
error IndexFacet_SelectorNotFound(bytes4 selector);

/**
 * @title IndexBase
 * @author BLOK Capital DAO
 * @notice Base contract for Index Facet, containing shared logic and internal functions for managing index connections
 * and rebalancing.
 * Handles interactions with the Index contract, retrieves target weights, and calculates rebalance actions.
 * The external functions are defined in the IndexFacet contract, which calls these internal functions to perform the
 * operations.
 */
abstract contract IndexBase {
    /// @notice Connects the garden to an index for automated rebalancing.
    /// @param indexAddress The address of the index contract to connect to.
    function _connectToIndex(address indexAddress) internal {
        if (!IndexFactory(IndexStorage.INDEX_FACTORY_ADDRESS).isIndexRegistered(indexAddress)) {
            revert IndexFacet_IndexNotRegistered(indexAddress);
        }
        Index(indexAddress).connectGardenToIndex();

        // Store the connected index address
        IndexStorage.layout().indexAddress = indexAddress;
        LibDiamond.layout().isConnectedToIndex = true;
        emit IIndex.IndexConnected(indexAddress);
    }

    /// @notice Disconnects the garden from its currently connected index.
    function _disconnectFromIndex() internal {
        address indexAddress = IndexStorage.layout().indexAddress;
        Index(indexAddress).disconnectGardenFromIndex();

        // Clear the connected index address
        IndexStorage.layout().indexAddress = address(0);
        LibDiamond.layout().isConnectedToIndex = false;
        emit IIndex.IndexDisconnected(indexAddress);
    }

    /// @notice Creates a rebalance intent by computing current vs target allocations.
    /// @dev Enforces both intent and rebalance interval cooldowns before allowing a new intent.
    function _rebalanceIntent() internal {
        IndexStorage.Layout storage s = IndexStorage.layout();

        // Check connected
        if (s.indexAddress == address(0)) {
            revert IndexFacet_NotConnectedToIndex();
        }

        // Check intent interval
        if (block.timestamp < s.lastIntentTimestamp + IndexStorage.PENDING_INTENT_INTERVAL) {
            revert IndexFacet_IntentIntervalNotPassed();
        }

        // Check rebalance interval
        if (block.timestamp < s.lastRebalanceTimestamp + IndexStorage.REBALANCE_INTERVAL) {
            revert IndexFacet_RebalanceIntervalNotPassed();
        }

        // Get target weights from index
        (string[] memory symbols, uint256[] memory weights) = Index(s.indexAddress).getWeights();

        (
            uint256[] memory currentValues,
            uint256[] memory targetValues,
            address[] memory tokenAddresses,
            uint256 totalValueUsd
        ) = _calculateRebalanceValues(symbols, weights);

        // Store pending intent
        s.pendingIntent.active = true;
        s.pendingIntent.totalValueUsd = totalValueUsd;
        s.pendingIntent.symbols = symbols;
        s.pendingIntent.currentValues = currentValues;
        s.pendingIntent.targetValues = targetValues;
        s.pendingIntent.tokenAddresses = tokenAddresses;
        s.lastIntentTimestamp = block.timestamp;

        emit IIndex.RebalanceIntentCreated(
            address(this), s.indexAddress, symbols, currentValues, targetValues, totalValueUsd
        );
    }

    /// @notice Execute rebalance by calling DEX facets directly
    /// @dev CRE provides swap calls that target DEX facet functions on this Diamond.
    ///      Each SwapCall contains:
    ///      selector: The 4-byte function selector
    ///      data: ABI-encoded function arguments
    /// @param swapCalls Array of swap calls to execute
    function _rebalance(SwapCall[] calldata swapCalls) internal {
        IndexStorage.Layout storage s = IndexStorage.layout();

        // Check connected
        if (s.indexAddress == address(0)) {
            revert IndexFacet_NotConnectedToIndex();
        }

        // Check pending intent
        if (!s.pendingIntent.active) {
            revert IndexFacet_NoPendingIntent();
        }

        // Check rebalance interval
        if (block.timestamp < s.lastRebalanceTimestamp + IndexStorage.REBALANCE_INTERVAL) {
            revert IndexFacet_RebalanceIntervalNotPassed();
        }

        // Execute each swap call on the Diamond's DEX facets
        _executeSwapCalls(swapCalls);

        // Verify final balances match targets within threshold
        _verifyBalancesMatchTargets();

        // Clear pending state and update timestamp
        s.pendingIntent.active = false;
        s.lastRebalanceTimestamp = block.timestamp;

        uint256 nextRebalanceTimestamp = block.timestamp + IndexStorage.REBALANCE_INTERVAL;

        emit IIndex.RebalanceCompleted(address(this), s.indexAddress, block.timestamp, nextRebalanceTimestamp);
    }

    /// @notice Execute swap calls by delegating to DEX facets
    /// @dev Uses address(this).call() to invoke facet functions on the same Diamond.
    ///      Only selectors belonging to the DEX module (ModuleIds.DEX) are allowed.
    ///      The registry stores which module owns each selector; we allow only the DEX module.
    /// @param swapCalls Array of swap calls to execute
    function _executeSwapCalls(SwapCall[] calldata swapCalls) internal {
        for (uint256 i = 0; i < swapCalls.length; i++) {
            bytes4 selector = swapCalls[i].selector;

            if (!_isDexFunction(selector)) revert IndexFacet_SelectorNotWhitelisted(selector);

            bytes memory callData = abi.encodePacked(selector, swapCalls[i].data);

            (bool success, bytes memory returnData) = address(this).call(callData);

            if (!success) {
                if (returnData.length == 0) {
                    revert IndexFacet_SelectorNotFound(selector);
                }
                revert IndexFacet_SwapCallFailed(i, returnData);
            }
        }
    }

    /// @dev Checks whether a selector belongs to the DEX module by querying the FacetRegistry.
    /// @param selector The four-byte function selector to check.
    /// @return `true` if the selector belongs to the DEX module.
    function _isDexFunction(bytes4 selector) internal view returns (bool) {
        IFacetRegistry registry = IFacetRegistry(LibDiamond.layout().facetRegistry);
        bytes32 moduleId = registry.getModuleIdBySelector(selector);
        return moduleId == IndexStorage.DEX_MODULE_ID;
    }

    // ========================================================================
    // Internal Functions - Calculations
    // ========================================================================

    /// @dev Calculates current token values and target values for each component in the index.
    /// @param symbols Array of component symbols to evaluate.
    /// @param weights Array of target weights (normalized to 1e18) corresponding to each symbol.
    /// @return currentValues Current USD values per component (8 decimals).
    /// @return targetValues Target USD values per component (8 decimals).
    /// @return tokenAddresses Token contract addresses corresponding to each symbol.
    /// @return totalValueUsd Total portfolio value in USD (8 decimals).
    function _calculateRebalanceValues(
        string[] memory symbols,
        uint256[] memory weights
    )
        internal
        view
        returns (
            uint256[] memory currentValues,
            uint256[] memory targetValues,
            address[] memory tokenAddresses,
            uint256 totalValueUsd
        )
    {
        IndexComponentRegistry componentRegistry = IndexComponentRegistry(IndexStorage.INDEX_COMPONENT_REGISTRY_ADDRESS);

        currentValues = new uint256[](symbols.length);
        targetValues = new uint256[](symbols.length);
        tokenAddresses = new address[](symbols.length);
        totalValueUsd = 0;

        // Calculate current values
        for (uint256 i = 0; i < symbols.length; i++) {
            address token = componentRegistry.getComponentAddress(symbols[i]);
            address priceFeed = componentRegistry.getComponentSymbolToPriceFeedAddress(symbols[i]);

            tokenAddresses[i] = token;

            uint256 balance = IERC20(token).balanceOf(address(this));
            uint256 price = _getPrice(priceFeed);
            uint8 decimals = IERC20Metadata(token).decimals();

            // Value in USD with 8 decimals (Chainlink standard)
            currentValues[i] = (balance * price) / (10 ** decimals);
            totalValueUsd += currentValues[i];
        }

        // Calculate target values based on weights
        for (uint256 i = 0; i < symbols.length; i++) {
            targetValues[i] = (totalValueUsd * weights[i]) / IndexStorage.PRECISION;
        }
    }

    /// @dev Verifies that post-rebalance balances match target values within the allowed threshold.
    /// @dev Reverts with `IndexFacet_BalanceOutsideThreshold` if any component exceeds the threshold.
    function _verifyBalancesMatchTargets() internal view {
        IndexStorage.Layout storage s = IndexStorage.layout();
        IndexComponentRegistry componentRegistry = IndexComponentRegistry(IndexStorage.INDEX_COMPONENT_REGISTRY_ADDRESS);

        for (uint256 i = 0; i < s.pendingIntent.symbols.length; i++) {
            string memory symbol = s.pendingIntent.symbols[i];
            address token = componentRegistry.getComponentAddress(symbol);
            address priceFeed = componentRegistry.getComponentSymbolToPriceFeedAddress(symbol);

            uint256 balance = IERC20(token).balanceOf(address(this));
            uint256 price = _getPrice(priceFeed);
            uint8 decimals = IERC20Metadata(token).decimals();

            uint256 currentValue = (balance * price) / (10 ** decimals);
            uint256 targetValue = s.pendingIntent.targetValues[i];

            // Calculate threshold
            uint256 threshold = (targetValue * IndexStorage.BALANCE_THRESHOLD_BPS) / 10_000;

            // Verify within threshold (use abs diff to avoid underflow)
            uint256 diff = currentValue > targetValue ? currentValue - targetValue : targetValue - currentValue;
            if (diff > threshold) {
                revert IndexFacet_BalanceOutsideThreshold(symbol, currentValue, targetValue);
            }
        }
    }

    /// @dev Fetches and validates the latest price from a Chainlink price feed.
    /// @param priceFeed The address of the Chainlink AggregatorV3 price feed.
    /// @return The latest price as a `uint256`.
    function _getPrice(address priceFeed) internal view returns (uint256) {
        (uint80 roundId, int256 price,, uint256 updatedAt, uint80 answeredInRound) =
            AggregatorV3Interface(priceFeed).latestRoundData();

        // Validate oracle data
        if (price <= 0) revert IndexFacet_InvalidOracleData();
        if (updatedAt == 0) revert IndexFacet_InvalidOracleData();
        if (answeredInRound < roundId) revert IndexFacet_InvalidOracleData();
        if (block.timestamp - updatedAt > 1 hours) revert IndexFacet_InvalidOracleData();

        return uint256(price);
    }

    // ========================================================================
    // Internal Functions - View
    // ========================================================================

    /// @dev Returns whether the garden is currently connected to an index.
    /// @return `true` if connected.
    function _isConnectedToIndex() internal view returns (bool) {
        return LibDiamond.layout().isConnectedToIndex;
    }

    /// @dev Returns the address of the connected index contract.
    /// @return The connected index address, or `address(0)` if not connected.
    function _getConnectedIndex() internal view returns (address) {
        return IndexStorage.layout().indexAddress;
    }

    /// @dev Returns whether there is an active pending rebalance intent.
    /// @return `true` if a pending intent exists.
    function _hasPendingIntent() internal view returns (bool) {
        return IndexStorage.layout().pendingIntent.active;
    }

    /// @dev Returns the current pending rebalance intent details.
    /// @return active Whether a pending intent is active.
    /// @return totalValueUsd Total portfolio value in USD at intent creation.
    /// @return symbols Array of component symbols.
    /// @return currentValues Array of current USD values per component.
    /// @return targetValues Array of target USD values per component.
    function _getPendingIntent()
        internal
        view
        returns (
            bool active,
            uint256 totalValueUsd,
            string[] memory symbols,
            uint256[] memory currentValues,
            uint256[] memory targetValues
        )
    {
        IndexStorage.Layout storage s = IndexStorage.layout();
        return (
            s.pendingIntent.active,
            s.pendingIntent.totalValueUsd,
            s.pendingIntent.symbols,
            s.pendingIntent.currentValues,
            s.pendingIntent.targetValues
        );
    }
}
