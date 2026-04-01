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
import { IIndex, SwapCall } from "src/garden/facets/indexFacets/IIndex.sol";
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

/// @notice Thrown when rebalance interval hasn't passed
error IndexFacet_RebalanceIntervalNotPassed();

/// @notice Thrown when balance is outside threshold after rebalance
error IndexFacet_BalanceOutsideThreshold(string symbol, uint256 current, uint256 target);

/// @notice Thrown when a swap call fails
error IndexFacet_SwapCallFailed(uint256 index, bytes reason);

/// @notice Thrown when swap selector is not whitelisted
error IndexFacet_SelectorNotWhitelisted(bytes4 selector);

/// @notice Thrown when swap call returns no data (selector not found)
error IndexFacet_SelectorNotFound(bytes4 selector);

/// @notice Thrown when a swap produces less output than the specified minimum
error IndexFacet_InsufficientSwapOutput(uint256 index, address outputToken, uint256 received, uint256 minRequired);

/// @notice Thrown when total garden value decreased beyond acceptable threshold
error IndexFacet_ExcessiveValueLoss(uint256 valueBefore, uint256 valueAfter);

/// @notice Thrown on reentrant call to _rebalance
error IndexFacet_RebalanceReentrancy();

/**
 * @title IndexBase
 * @author BLOK Capital DAO
 * @notice Single-transaction rebalance: CRE submits SwapCall[], contract executes them through
 *         DEX facets and validates the outcome using fresh Chainlink prices + Index weights.
 *         No intent system — the on-chain verification IS the safety net.
 *
 * @dev IMPORTANT: Index-type gardens hold index component tokens AND a deposit token (USDC).
 *      Value calculations account for both. USDC is not an index component (no target weight)
 *      but its balance is included in total portfolio value. Any other non-index, non-USDC tokens
 *      are invisible to these calculations and will NOT be protected by the MAX_VALUE_LOSS_BPS check.
 */
abstract contract IndexBase {
    /// @notice Connects the garden to an index for automated rebalancing.
    function _connectToIndex(address indexAddress) internal {
        if (!IndexFactory(IndexStorage.INDEX_FACTORY_ADDRESS).isIndexRegistered(indexAddress)) {
            revert IndexFacet_IndexNotRegistered(indexAddress);
        }
        Index(indexAddress).connectGardenToIndex();

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

        s.indexAddress = address(0);
        LibDiamond.layout().isConnectedToIndex = false;
        emit IIndex.IndexDisconnected(indexAddress);
    }

    /// @notice Execute rebalance in a single transaction.
    /// @dev CRE provides swap calls that target DEX facet functions on this Diamond.
    ///      Uses a custom rebalancing flag instead of OZ ReentrancyGuard to avoid
    ///      conflicts with nonReentrant on DEX facets invoked via address(this).call().
    function _rebalance(SwapCall[] calldata swapCalls) internal {
        IndexStorage.Layout storage s = IndexStorage.layout();

        // Custom reentrancy guard
        if (s.rebalancing) revert IndexFacet_RebalanceReentrancy();
        s.rebalancing = true;

        // Must be connected to an index
        if (s.indexAddress == address(0)) {
            revert IndexFacet_NotConnectedToIndex();
        }

        // Enforce cooldown between rebalances
        if (block.timestamp < s.lastRebalanceTimestamp + IndexStorage.REBALANCE_INTERVAL) {
            revert IndexFacet_RebalanceIntervalNotPassed();
        }

        // Read weights fresh from the Index contract
        (string[] memory symbols, uint256[] memory weights) = Index(s.indexAddress).getWeights();

        // Snapshot total value BEFORE swaps
        uint256 valueBefore = _calculateTotalValue(symbols);

        // Execute each swap call on the Diamond's DEX facets
        _executeSwapCalls(swapCalls);

        // Verify final balances match targets within threshold (uses fresh prices + Index weights)
        _verifyBalancesMatchTargets(symbols, weights);

        // Verify total value preserved
        uint256 valueAfter = _calculateTotalValue(symbols);
        uint256 minAcceptableValue =
            Math.mulDiv(valueBefore, 10_000 - IndexStorage.MAX_VALUE_LOSS_BPS, 10_000, Math.Rounding.Floor);

        if (valueAfter < minAcceptableValue) {
            revert IndexFacet_ExcessiveValueLoss(valueBefore, valueAfter);
        }

        // Update timestamp and clear reentrancy flag
        s.lastRebalanceTimestamp = block.timestamp;
        s.rebalancing = false;

        uint256 nextRebalanceTimestamp = block.timestamp + IndexStorage.REBALANCE_INTERVAL;
        emit IIndex.RebalanceCompleted(address(this), s.indexAddress, block.timestamp, nextRebalanceTimestamp);
    }

    /// @notice Execute swap calls by delegating to DEX facets
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
    function _isDexFunction(bytes4 selector) internal view returns (bool) {
        IFacetRegistry registry = IFacetRegistry(LibDiamond.layout().facetRegistry);
        bytes32 moduleId = registry.getModuleIdBySelector(selector);
        return moduleId == IndexStorage.DEX_MODULE_ID;
    }

    // ========================================================================
    // Internal Functions - Calculations
    // ========================================================================

    /// @dev Verifies post-rebalance balances match targets within threshold.
    ///      Uses fresh Chainlink prices and Index weights to compute targets from scratch.
    function _verifyBalancesMatchTargets(string[] memory symbols, uint256[] memory weights) internal {
        IndexComponentRegistry componentRegistry = IndexComponentRegistry(IndexStorage.INDEX_COMPONENT_REGISTRY_ADDRESS);

        uint256 len = symbols.length;

        // First pass: calculate fresh total value with current prices
        uint256 freshTotalValueUsd = 0;
        uint256[] memory currentValues = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            address token = componentRegistry.getComponentAddress(symbols[i]);

            uint256 balance = IERC20(token).balanceOf(address(this));
            uint256 price = componentRegistry.fetchPrice(token, symbols[i]);
            uint8 decimals = IERC20Metadata(token).decimals();

            currentValues[i] = Math.mulDiv(balance, price, 10 ** decimals, Math.Rounding.Floor);
            freshTotalValueUsd += currentValues[i];
        }

        // Add USDC deposit token value to fresh total
        freshTotalValueUsd += _getUsdcValueUsd(componentRegistry, symbols);

        // Second pass: recalculate targets and verify
        for (uint256 i = 0; i < len; i++) {
            uint256 freshTargetValue = Math.mulDiv(
                freshTotalValueUsd, weights[i], IndexStorage.PRECISION, Math.Rounding.Floor
            );

            uint256 threshold =
                Math.mulDiv(freshTargetValue, IndexStorage.BALANCE_THRESHOLD_BPS, 10_000, Math.Rounding.Ceil);

            uint256 diff = currentValues[i] > freshTargetValue
                ? currentValues[i] - freshTargetValue
                : freshTargetValue - currentValues[i];
            if (diff > threshold) {
                revert IndexFacet_BalanceOutsideThreshold(symbols[i], currentValues[i], freshTargetValue);
            }
        }
    }

    /// @notice Calculate total garden value in USD using the IndexComponentRegistry oracle
    function _calculateTotalValue(string[] memory symbols) internal returns (uint256 totalValueUsd) {
        IndexComponentRegistry componentRegistry = IndexComponentRegistry(IndexStorage.INDEX_COMPONENT_REGISTRY_ADDRESS);

        for (uint256 i = 0; i < symbols.length; i++) {
            address token = componentRegistry.getComponentAddress(symbols[i]);

            uint256 balance = IERC20(token).balanceOf(address(this));
            uint256 price = componentRegistry.fetchPrice(token, symbols[i]);
            uint8 decimals = IERC20Metadata(token).decimals();

            totalValueUsd += Math.mulDiv(balance, price, 10 ** decimals, Math.Rounding.Floor);
        }

        totalValueUsd += _getUsdcValueUsd(componentRegistry, symbols);
    }

    /// @dev Cached keccak256 hash of "USDC" symbol for gas-efficient comparison.
    bytes32 private constant _USDC_SYMBOL_HASH = keccak256("USDC");

    /// @dev Returns the USD value of USDC held by the garden (8 decimals).
    function _getUsdcValueUsd(
        IndexComponentRegistry componentRegistry,
        string[] memory symbols
    )
        internal
        returns (uint256)
    {
        // Skip if USDC is already counted as an index component
        for (uint256 i = 0; i < symbols.length; i++) {
            if (keccak256(abi.encodePacked(symbols[i])) == _USDC_SYMBOL_HASH) {
                return 0;
            }
        }

        uint256 usdcBalance = IERC20(IndexStorage.USDC_ADDRESS).balanceOf(address(this));
        if (usdcBalance == 0) return 0;

        if (!componentRegistry.isComponentRegistered("USDC")) return 0;

        uint256 usdcPrice = componentRegistry.fetchPrice(IndexStorage.USDC_ADDRESS, "USDC");
        uint8 usdcDecimals = IERC20Metadata(IndexStorage.USDC_ADDRESS).decimals();

        return Math.mulDiv(usdcBalance, usdcPrice, 10 ** usdcDecimals, Math.Rounding.Floor);
    }

    // ========================================================================
    // Internal Functions - View
    // ========================================================================

    function _isConnectedToIndex() internal view returns (bool) {
        return LibDiamond.layout().isConnectedToIndex;
    }

    function _getConnectedIndex() internal view returns (address) {
        return IndexStorage.layout().indexAddress;
    }

    function _getLastRebalanceTimestamp() internal view returns (uint256) {
        return IndexStorage.layout().lastRebalanceTimestamp;
    }
}
