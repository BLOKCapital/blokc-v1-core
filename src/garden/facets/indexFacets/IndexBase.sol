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
import { LibDiamond } from "src/garden/libraries/LibDiamond.sol";
import { IIndex, SwapCall, PendingIntent } from "src/garden/facets/indexFacets/IIndex.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

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

/// @notice Thrown when a swap call fails
error IndexFacet_SwapCallFailed(uint256 index, bytes reason);

/// @notice Thrown when swap selector is not whitelisted
error IndexFacet_SelectorNotWhitelisted(bytes4 selector);

/// @notice Thrown when swap call returns no data (selector not found)
error IndexFacet_SelectorNotFound(bytes4 selector);

/// @notice Thrown when a swap produces less output than the specified minimum
/// @param index The index of the swap call in the array
/// @param outputToken The expected output token
/// @param received The actual output received
/// @param minRequired The minimum output required
error IndexFacet_InsufficientSwapOutput(uint256 index, address outputToken, uint256 received, uint256 minRequired);

/// @notice Thrown when the pending intent has expired
error IndexFacet_IntentExpired();

/// @notice Thrown when total garden value decreased beyond acceptable threshold
error IndexFacet_ExcessiveValueLoss(uint256 valueBefore, uint256 valueAfter);

/// @notice Thrown on reentrant call to _rebalance
error IndexFacet_RebalanceReentrancy();

/// @notice Thrown when attempting to create a rebalance intent with zero total garden value
error IndexFacet_ZeroTotalValue();

/**
 * @title IndexBase
 * @author BLOK Capital DAO
 * @notice Base contract for Index Facet, containing shared logic and internal functions for managing index connections
 * and rebalancing.
 * Handles interactions with the Index contract, retrieves target weights, and calculates rebalance actions.
 * The external functions are defined in the IndexFacet contract, which calls these internal functions to perform the
 * operations.
 *
 * @dev IMPORTANT: Index-type gardens hold index component tokens AND a deposit token (USDC).
 *      Value calculations (_calculateTotalValue, _calculateRebalanceValues, _verifyBalancesMatchTargets)
 *      account for both index component tokens and the USDC deposit token. USDC is not an index component
 *      (it has no target weight), but its balance is included in total portfolio value so that target
 *      allocations are computed against the full garden value. During rebalancing, USDC is swapped into
 *      index components, driving its balance toward zero. Any other non-index, non-USDC tokens held by the
 *      garden are invisible to these calculations and will NOT be protected by the MAX_VALUE_LOSS_BPS check.
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
        IndexStorage.Layout storage s = IndexStorage.layout();
        address indexAddress = s.indexAddress;
        if (indexAddress == address(0)) revert IndexFacet_NotConnectedToIndex();
        Index(indexAddress).disconnectGardenFromIndex();

        // Clear pending intent so a stale intent cannot be executed after reconnecting to a different index
        s.pendingIntent.active = false;

        // Clear the connected index address
        s.indexAddress = address(0);
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
        if (block.timestamp < s.lastIntentTimestamp + IndexStorage.INTENT_EXPIRY) {
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

        if (totalValueUsd == 0) revert IndexFacet_ZeroTotalValue();

        // Store pending intent
        s.pendingIntent.active = true;
        s.pendingIntent.totalValueUsd = totalValueUsd;
        s.pendingIntent.symbols = symbols;
        s.pendingIntent.currentValues = currentValues;
        s.pendingIntent.targetValues = targetValues;
        s.pendingIntent.tokenAddresses = tokenAddresses;
        s.pendingIntent.weights = weights;
        s.lastIntentTimestamp = block.timestamp;

        emit IIndex.RebalanceIntentCreated(
            address(this), s.indexAddress, symbols, currentValues, targetValues, totalValueUsd
        );
    }

    /// @notice Execute rebalance by calling DEX facets directly
    /// @dev CRE provides swap calls that target DEX facet functions on this Diamond.
    ///      Uses a custom rebalancing flag instead of OZ ReentrancyGuard to avoid
    ///      conflicts with nonReentrant on DEX facets invoked via address(this).call().
    /// @param swapCalls Array of swap calls to execute
    function _rebalance(SwapCall[] calldata swapCalls) internal {
        IndexStorage.Layout storage s = IndexStorage.layout();

        // Custom reentrancy guard (separate from OZ ReentrancyGuard to avoid conflict with DEX facets)
        if (s.rebalancing) revert IndexFacet_RebalanceReentrancy();
        s.rebalancing = true;

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

        if (block.timestamp > s.lastIntentTimestamp + IndexStorage.INTENT_EXPIRY) {
            // Note: no state writes needed here — revert undoes all changes including s.rebalancing = true above
            revert IndexFacet_IntentExpired();
        }

        uint256 valueBefore = _calculateTotalValue();

        // Execute each swap call on the Diamond's DEX facets
        _executeSwapCalls(swapCalls);

        // Verify final balances match targets within threshold (uses fresh prices + stored weights)
        _verifyBalancesMatchTargets();

        uint256 valueAfter = _calculateTotalValue();
        uint256 minAcceptableValue =
            Math.mulDiv(valueBefore, 10_000 - IndexStorage.MAX_VALUE_LOSS_BPS, 10_000, Math.Rounding.Floor);

        if (valueAfter < minAcceptableValue) {
            revert IndexFacet_ExcessiveValueLoss(valueBefore, valueAfter);
        }

        // Clear pending state and update timestamp
        s.pendingIntent.active = false;
        s.lastRebalanceTimestamp = block.timestamp;
        s.rebalancing = false;

        uint256 nextRebalanceTimestamp = block.timestamp + IndexStorage.REBALANCE_INTERVAL;

        emit IIndex.RebalanceCompleted(address(this), s.indexAddress, block.timestamp, nextRebalanceTimestamp);
    }

    /// @notice Execute swap calls by delegating to DEX facets
    /// @dev Uses address(this).call() to invoke facet functions on the same Diamond.
    ///      Only selectors belonging to the DEX module (ModuleIds.DEX) are allowed.
    ///      Each swap is validated against its minOutput to prevent unfavorable trades.
    /// @param swapCalls Array of swap calls to execute
    function _executeSwapCalls(SwapCall[] calldata swapCalls) internal {
        for (uint256 i = 0; i < swapCalls.length; i++) {
            bytes4 selector = swapCalls[i].selector;

            if (!_isDexFunction(selector)) revert IndexFacet_SelectorNotWhitelisted(selector);

            uint256 balanceBefore = IERC20(swapCalls[i].outputToken).balanceOf(address(this));

            bytes memory callData = abi.encodePacked(selector, swapCalls[i].data);

            (bool success, bytes memory returnData) = address(this).call(callData);

            if (!success) {
                if (returnData.length == 0) {
                    revert IndexFacet_SelectorNotFound(selector);
                }
                revert IndexFacet_SwapCallFailed(i, returnData);
            }

            uint256 balanceAfter = IERC20(swapCalls[i].outputToken).balanceOf(address(this));
            uint256 received = balanceAfter - balanceBefore;
            if (received < swapCalls[i].minOutput) {
                revert IndexFacet_InsufficientSwapOutput(i, swapCalls[i].outputToken, received, swapCalls[i].minOutput);
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
            tokenAddresses[i] = token;

            uint256 balance = IERC20(token).balanceOf(address(this));
            uint256 price = componentRegistry.fetchPrice(token, symbols[i]);
            uint8 decimals = IERC20Metadata(token).decimals();

            // Value in USD with 8 decimals (Chainlink standard)
            currentValues[i] = Math.mulDiv(balance, price, 10 ** decimals, Math.Rounding.Floor);
            totalValueUsd += currentValues[i];
        }

        // Add USDC deposit token value to total (USDC is not an index component but contributes to portfolio value)
        totalValueUsd += _getUsdcValueUsd(componentRegistry, symbols);

        // Calculate target values based on weights
        for (uint256 i = 0; i < symbols.length; i++) {
            targetValues[i] = Math.mulDiv(totalValueUsd, weights[i], IndexStorage.PRECISION, Math.Rounding.Floor);
        }
    }

    /// @dev Verifies that post-rebalance balances match target values within the allowed threshold.
    /// @dev Uses fresh prices and stored weights to recalculate targets, avoiding price mismatch
    ///      between intent creation and verification.
    /// @dev Reverts with `IndexFacet_BalanceOutsideThreshold` if any component exceeds the threshold.
    function _verifyBalancesMatchTargets() internal {
        IndexStorage.Layout storage s = IndexStorage.layout();
        IndexComponentRegistry componentRegistry = IndexComponentRegistry(IndexStorage.INDEX_COMPONENT_REGISTRY_ADDRESS);

        uint256 len = s.pendingIntent.symbols.length;

        // First pass: calculate fresh total value with current prices
        uint256 freshTotalValueUsd = 0;
        uint256[] memory currentValues = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            string memory symbol = s.pendingIntent.symbols[i];
            address token = componentRegistry.getComponentAddress(symbol);

            uint256 balance = IERC20(token).balanceOf(address(this));
            uint256 price = componentRegistry.fetchPrice(token, symbol);
            uint8 decimals = IERC20Metadata(token).decimals();

            currentValues[i] = Math.mulDiv(balance, price, 10 ** decimals, Math.Rounding.Floor);
            freshTotalValueUsd += currentValues[i];
        }

        // Add USDC deposit token value to fresh total
        freshTotalValueUsd += _getUsdcValueUsd(componentRegistry, s.pendingIntent.symbols);

        // Second pass: recalculate targets from stored weights and fresh total value, then verify
        for (uint256 i = 0; i < len; i++) {
            uint256 freshTargetValue = Math.mulDiv(
                freshTotalValueUsd, s.pendingIntent.weights[i], IndexStorage.PRECISION, Math.Rounding.Floor
            );

            // Calculate threshold
            uint256 threshold =
                Math.mulDiv(freshTargetValue, IndexStorage.BALANCE_THRESHOLD_BPS, 10_000, Math.Rounding.Ceil);

            // Verify within threshold (use abs diff to avoid underflow)
            uint256 diff = currentValues[i] > freshTargetValue
                ? currentValues[i] - freshTargetValue
                : freshTargetValue - currentValues[i];
            if (diff > threshold) {
                revert IndexFacet_BalanceOutsideThreshold(
                    s.pendingIntent.symbols[i], currentValues[i], freshTargetValue
                );
            }
        }
    }

    /// @notice Calculate total garden value in USD using the IndexComponentRegistry oracle
    function _calculateTotalValue() internal returns (uint256 totalValueUsd) {
        IndexStorage.Layout storage s = IndexStorage.layout();
        IndexComponentRegistry componentRegistry = IndexComponentRegistry(IndexStorage.INDEX_COMPONENT_REGISTRY_ADDRESS);

        for (uint256 i = 0; i < s.pendingIntent.symbols.length; i++) {
            string memory symbol = s.pendingIntent.symbols[i];
            address token = componentRegistry.getComponentAddress(symbol);

            uint256 balance = IERC20(token).balanceOf(address(this));
            uint256 price = componentRegistry.fetchPrice(token, symbol);
            uint8 decimals = IERC20Metadata(token).decimals();

            totalValueUsd += Math.mulDiv(balance, price, 10 ** decimals, Math.Rounding.Floor);
        }

        // Add USDC deposit token value to total
        totalValueUsd += _getUsdcValueUsd(componentRegistry, s.pendingIntent.symbols);
    }

    /// @dev Cached keccak256 hash of "USDC" symbol for gas-efficient comparison.
    bytes32 private constant _USDC_SYMBOL_HASH = keccak256("USDC");

    /// @dev Returns the USD value of USDC held by the garden (8 decimals).
    ///      Uses the Chainlink oracle via IndexComponentRegistry for accurate pricing.
    ///      Returns 0 if the garden holds no USDC, if USDC is already an index component
    ///      (to avoid double-counting), or if USDC is not registered in the ComponentRegistry.
    function _getUsdcValueUsd(
        IndexComponentRegistry componentRegistry,
        string[] memory symbols
    ) internal returns (uint256) {
        // Skip if USDC is already counted as an index component
        for (uint256 i = 0; i < symbols.length; i++) {
            if (keccak256(abi.encodePacked(symbols[i])) == _USDC_SYMBOL_HASH) {
                return 0;
            }
        }

        uint256 usdcBalance = IERC20(IndexStorage.USDC_ADDRESS).balanceOf(address(this));
        if (usdcBalance == 0) return 0;

        // Gracefully return 0 if USDC is not registered in the ComponentRegistry,
        // so an unregistered USDC doesn't brick the entire rebalance flow.
        if (!componentRegistry.isComponentRegistered("USDC")) return 0;

        uint256 usdcPrice = componentRegistry.fetchPrice(IndexStorage.USDC_ADDRESS, "USDC");
        uint8 usdcDecimals = IERC20Metadata(IndexStorage.USDC_ADDRESS).decimals();

        return Math.mulDiv(usdcBalance, usdcPrice, 10 ** usdcDecimals, Math.Rounding.Floor);
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
