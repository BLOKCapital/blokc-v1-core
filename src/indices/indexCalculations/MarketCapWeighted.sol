//SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    @title MarketCapWeighted
    @author BLOK Capital DAO
    @notice Market capitalization weighted index calculation strategy
    @dev Implements IIndexCalculation to calculate component weights based on
         market cap. Each component's weight = (component market cap) / (total market cap).
         Uses Chainlink price feeds and circulating supply data for calculations.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import { IndexComponentRegistry } from "src/indices/IndexComponentRegistry.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IIndexCalculation } from "src/interfaces/IIndexCalculation.sol";
import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";
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

contract MarketCapWeighted is IIndexCalculation {
    /// @notice Reference to the IndexComponentRegistry for price feed lookups
    /// @dev Immutable for consistent pricing sources
    IndexComponentRegistry private immutable INDEX_COMPONENT_REGISTRY;

    /// @notice Reference to the CirculatingSupply contract for supply data
    /// @dev Immutable for consistent supply data sources
    CirculatingSupply private immutable CIRCULATING_SUPPLY;

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
    ///      Uses Chainlink price feeds and circulating supply data
    /// @dev CirculatingSupply MUST provide values in whole token units (NOT native token decimals).
    ///      E.g., ETH supply = 120000000, NOT 120000000 * 10^18.
    ///      Mixing conventions across tokens produces incorrect weights.
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
        }
    }

    /// @notice Calculates market cap for a single component
    /// @param symbol Component symbol
    /// @return componentMarketCap Market cap = (circulating supply) * (price)
    /// @dev Uses Chainlink price feed and CirculatingSupply contract
    function _getComponentMarketCap(string memory symbol) internal returns (uint256 componentMarketCap) {
        (uint256 componentPrice, uint256 componentPriceDecimals) = _getComponentPrice(symbol);
        uint256 componentCirculatingSupply = CIRCULATING_SUPPLY.getSupply(symbol);
        componentMarketCap =
            Math.mulDiv(componentCirculatingSupply, componentPrice, 10 ** componentPriceDecimals, Math.Rounding.Floor);
    }

    /// @notice Retrieves current price for a component from Chainlink oracle
    /// @param symbol Component symbol
    /// @return componentPrice Current price from oracle
    /// @return componentPriceDecimals Decimal precision of the price
    /// @dev Validates oracle data for freshness and completeness
    function _getComponentPrice(string memory symbol)
        internal
        returns (uint256 componentPrice, uint8 componentPriceDecimals)
    {
        AggregatorV3Interface priceFeed =
            AggregatorV3Interface(INDEX_COMPONENT_REGISTRY.getComponentSymbolToPriceFeedAddress(symbol));
        componentPrice = INDEX_COMPONENT_REGISTRY.fetchPrice(address(priceFeed), symbol);
        componentPriceDecimals = priceFeed.decimals();
    }
}
