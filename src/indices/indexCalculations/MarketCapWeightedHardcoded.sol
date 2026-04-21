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

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when IndexComponentRegistry address is zero during construction
error MarketCapWeightedHardcoded_InvalidIndexComponentRegistryAddress();

/// @notice Thrown when total market cap is zero (cannot calculate weights)
error MarketCapWeightedHardcoded_InvalidTotalMarketCap();

/// @notice Thrown when market cap calculation causes overflow
error MarketCapWeightedHardcoded_MarketCapOverflow();

/// @notice Thrown when a component's market cap exceeds the sanity bound (likely supply unit error)
error MarketCapWeightedHardcoded_MarketCapExceedsSanityBound();

/// @notice Thrown when a component's calculated weight is below the minimum threshold
error MarketCapWeightedHardcoded_ComponentWeightBelowMinimum();

/// @notice Thrown when an unsupported symbol is provided
error MarketCapWeightedHardcoded_UnsupportedSymbol(bytes32 symbol);

/**
 * @title MarketCapWeightedHardcoded
 * @notice Market-cap weighted calculation strategy with hardcoded circulating supplies for BTC and ETH.
 * @dev Intended for testing a BTC/ETH index without requiring a CirculatingSupply oracle.
 *      Supplies: ETH = 120,692,290 | BTC = 19,995,028 (whole token units).
 */
contract MarketCapWeightedHardcoded is IIndexCalculation {
    /// @notice Reference to the IndexComponentRegistry for price feed lookups
    IndexComponentRegistry private immutable INDEX_COMPONENT_REGISTRY;

    /// @notice Sanity bound for individual component market cap to catch supply unit errors
    /// @dev Set to 1e30 (~$1 quadrillion) — any market cap above this indicates wrong supply units
    uint256 private constant MAX_COMPONENT_MARKET_CAP = 1e30;

    /// @notice Hardcoded circulating supply of ETH in whole token units
    uint256 private constant ETH_CIRCULATING_SUPPLY = 120_691_190;

    /// @notice Hardcoded circulating supply of BTC in whole token units
    uint256 private constant BTC_CIRCULATING_SUPPLY = 20_012_568;

    bytes32 private constant ETH_SYMBOL = bytes32("ETH");
    bytes32 private constant WETH_SYMBOL = bytes32("WETH");
    bytes32 private constant BTC_SYMBOL = bytes32("BTC");
    bytes32 private constant WBTC_SYMBOL = bytes32("WBTC");

    constructor(address _indexComponentRegistryAddress) {
        if (_indexComponentRegistryAddress == address(0)) {
            revert MarketCapWeightedHardcoded_InvalidIndexComponentRegistryAddress();
        }
        INDEX_COMPONENT_REGISTRY = IndexComponentRegistry(_indexComponentRegistryAddress);
    }

    /// @inheritdoc IIndexCalculation
    function getWeights(bytes32[] memory symbols) external override returns (uint256[] memory weights) {
        uint256 len = symbols.length;
        weights = new uint256[](len);
        uint256[] memory marketCaps = new uint256[](len);
        uint256 totalMarketCap = 0;

        for (uint256 i = 0; i < len; i++) {
            marketCaps[i] = _getComponentMarketCap(symbols[i]);
            (bool success, uint256 result) = Math.tryAdd(totalMarketCap, marketCaps[i]);
            if (!success) revert MarketCapWeightedHardcoded_MarketCapOverflow();
            totalMarketCap = result;
        }

        if (totalMarketCap == 0) revert MarketCapWeightedHardcoded_InvalidTotalMarketCap();

        for (uint256 i = 0; i < len; i++) {
            weights[i] = IndexMath.calculateWeight(marketCaps[i], totalMarketCap);
            if (weights[i] < IndexMath.MIN_WEIGHT) revert MarketCapWeightedHardcoded_ComponentWeightBelowMinimum();
        }
    }

    /// @notice Returns the hardcoded circulating supply for a supported symbol
    /// @param symbol Component symbol (bytes32("ETH"), bytes32("WETH"), bytes32("BTC"), or bytes32("WBTC"))
    function _getCirculatingSupply(bytes32 symbol) internal pure returns (uint256) {
        if (symbol == ETH_SYMBOL || symbol == WETH_SYMBOL) return ETH_CIRCULATING_SUPPLY;
        if (symbol == BTC_SYMBOL || symbol == WBTC_SYMBOL) return BTC_CIRCULATING_SUPPLY;
        revert MarketCapWeightedHardcoded_UnsupportedSymbol(symbol);
    }

    /// @notice Calculates market cap for a single component using hardcoded supply
    function _getComponentMarketCap(bytes32 symbol) internal returns (uint256 componentMarketCap) {
        (uint256 componentPrice, uint8 componentPriceDecimals) = _getComponentPrice(symbol);
        uint256 circulatingSupply = _getCirculatingSupply(symbol);
        componentMarketCap = Math.mulDiv(
            circulatingSupply, componentPrice, 10 ** uint256(componentPriceDecimals), Math.Rounding.Floor
        );
        if (componentMarketCap > MAX_COMPONENT_MARKET_CAP) {
            revert MarketCapWeightedHardcoded_MarketCapExceedsSanityBound();
        }
    }

    /// @notice Retrieves current price for a component from the IndexComponentRegistry oracle
    function _getComponentPrice(bytes32 symbol)
        internal
        returns (uint256 componentPrice, uint8 componentPriceDecimals)
    {
        componentPrice = INDEX_COMPONENT_REGISTRY.fetchPrice(symbol);
        componentPriceDecimals = INDEX_COMPONENT_REGISTRY.getOracleRecord(symbol).decimals;
    }
}
