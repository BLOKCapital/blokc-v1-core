// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { IndexComponentRegistry } from "src/indices/IndexComponentRegistry.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IIndexCalculation } from "src/interfaces/IIndexCalculation.sol";
import { IndexMath } from "src/indices/libraries/IndexMath.sol";
import { CirculatingSupply } from "src/indices/CirculatingSupply.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when IndexComponentRegistry address is zero during construction
error MarketCapWeighted_InvalidIndexComponentRegistryAddress();

/// @notice Thrown when total market cap is zero (cannot calculate weights)
error MarketCapWeighted_InvalidTotalMarketCap();

/// @notice Thrown when market cap calculation causes overflow
error MarketCapWeighted_MarketCapOverflow();

/// @notice Thrown when a component's market cap exceeds the sanity bound (likely supply unit error)
error MarketCapWeighted_MarketCapExceedsSanityBound();

/// @notice Thrown when a component's calculated weight is below the minimum threshold
error MarketCapWeighted_ComponentWeightBelowMinimum();

/**
 * @title MarketCapWeighted
 * @notice Implementation of the IIndexCalculation interface that calculates component weights based on market
 * capitalization. This contract retrieves price data from Chainlink oracles and circulating supply data to compute the
 * market cap for each component and determine their respective weights in the index. The weights are normalized to sum
 * to 1 (scaled to 1e18).
 */
contract MarketCapWeighted is IIndexCalculation {
    /// @notice Reference to the IndexComponentRegistry for price feed lookups
    /// @dev Immutable for consistent pricing sources
    IndexComponentRegistry private immutable INDEX_COMPONENT_REGISTRY;

    /// @notice Reference to the CirculatingSupply contract for supply data
    /// @dev Immutable for consistent supply data sources
    CirculatingSupply private immutable CIRCULATING_SUPPLY;

    /// @notice Sanity bound for individual component market cap to catch supply unit errors
    /// @dev Set to 1e30 (~$1 quadrillion) — any market cap above this indicates wrong supply units
    uint256 private constant MAX_COMPONENT_MARKET_CAP = 1e30;

    /// @notice Constructs the MarketCapWeighted calculation strategy
    /// @param _indexComponentRegistryAddress Address of the IndexComponentRegistry
    /// @param _circulatingSupplyAddress Address of the CirculatingSupply contract
    /// @dev Validates registry address is not zero
    constructor(address _indexComponentRegistryAddress, address _circulatingSupplyAddress) {
        if (_indexComponentRegistryAddress == address(0) || _circulatingSupplyAddress == address(0)) {
            revert MarketCapWeighted_InvalidIndexComponentRegistryAddress();
        }
        INDEX_COMPONENT_REGISTRY = IndexComponentRegistry(_indexComponentRegistryAddress);
        CIRCULATING_SUPPLY = CirculatingSupply(_circulatingSupplyAddress);
    }

    /// @notice Calculates market cap weighted allocations for components
    /// @param symbols Array of component symbols
    /// @return weights Array of weights scaled to 1e18 (100% = 1e18)
    /// @dev For each component: weight = (component market cap) / (total market cap)
    ///      Uses Chainlink price feeds and circulating supply data.
    /// @dev This function is non-view because it triggers price cache updates in the
    ///      IndexComponentRegistry via fetchPrice. Callers should be aware that each
    ///      invocation writes updated oracle data to storage.
    /// @dev CirculatingSupply MUST provide values in whole token units (NOT native token decimals).
    ///      E.g., ETH supply = 120000000, NOT 120000000 * 10^18.
    ///      Mixing conventions across tokens produces incorrect weights.
    ///      A sanity bound (MAX_COMPONENT_MARKET_CAP) catches grossly wrong supply values.
    function getWeights(string[] memory symbols) external override returns (uint256[] memory weights) {
        uint256 len = symbols.length;
        weights = new uint256[](len);
        uint256[] memory marketCaps = new uint256[](len);
        uint256 totalMarketCap = 0;

        // Single pass: compute and cache all market caps (avoids redundant oracle reads)
        for (uint256 i = 0; i < len; i++) {
            marketCaps[i] = _getComponentMarketCap(symbols[i]);
            (bool success, uint256 result) = Math.tryAdd(totalMarketCap, marketCaps[i]);
            if (!success) revert MarketCapWeighted_MarketCapOverflow();
            totalMarketCap = result;
        }

        if (totalMarketCap == 0) revert MarketCapWeighted_InvalidTotalMarketCap();

        // Second pass: calculate weights from cached market caps
        for (uint256 i = 0; i < len; i++) {
            weights[i] = IndexMath.calculateWeight(marketCaps[i], totalMarketCap);
            if (weights[i] < IndexMath.MIN_WEIGHT) revert MarketCapWeighted_ComponentWeightBelowMinimum();
        }
    }

    /// @notice Calculates market cap for a single component
    /// @param symbol Component symbol
    /// @return componentMarketCap Market cap = (circulating supply) * (price)
    /// @dev Uses Chainlink price feed and CirculatingSupply contract.
    ///      Validates result against MAX_COMPONENT_MARKET_CAP to catch supply unit errors.
    function _getComponentMarketCap(string memory symbol) internal returns (uint256 componentMarketCap) {
        (uint256 componentPrice, uint8 componentPriceDecimals) = _getComponentPrice(symbol);
        uint256 componentCirculatingSupply = CIRCULATING_SUPPLY.getSupply(symbol);
        componentMarketCap = Math.mulDiv(
            componentCirculatingSupply, componentPrice, 10 ** uint256(componentPriceDecimals), Math.Rounding.Floor
        );
        if (componentMarketCap > MAX_COMPONENT_MARKET_CAP) revert MarketCapWeighted_MarketCapExceedsSanityBound();
    }

    /// @notice Retrieves current price for a component from the IndexComponentRegistry oracle
    /// @param symbol Component symbol
    /// @return componentPrice Current price from oracle
    /// @return componentPriceDecimals Decimal precision of the price
    function _getComponentPrice(string memory symbol)
        internal
        returns (uint256 componentPrice, uint8 componentPriceDecimals)
    {
        address tokenAddress = INDEX_COMPONENT_REGISTRY.getComponentAddress(symbol);
        componentPrice = INDEX_COMPONENT_REGISTRY.fetchPrice(tokenAddress, symbol);
        componentPriceDecimals = INDEX_COMPONENT_REGISTRY.getOracleRecord(symbol).decimals;
    }
}
