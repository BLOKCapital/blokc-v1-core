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
error MarketCapWeightedBlokc5Hardcoded_InvalidIndexComponentRegistryAddress();

/// @notice Thrown when total market cap is zero (cannot calculate weights)
error MarketCapWeightedBlokc5Hardcoded_InvalidTotalMarketCap();

/// @notice Thrown when market cap calculation causes overflow
error MarketCapWeightedBlokc5Hardcoded_MarketCapOverflow();

/// @notice Thrown when a component's market cap exceeds the sanity bound (likely supply unit error)
error MarketCapWeightedBlokc5Hardcoded_MarketCapExceedsSanityBound();

/// @notice Thrown when an unsupported symbol is provided
error MarketCapWeightedBlokc5Hardcoded_UnsupportedSymbol(bytes32 symbol);

/**
 * @title MarketCapWeightedBlokc5Hardcoded
 * @notice Market-cap weighted calculation strategy with hardcoded circulating supplies for BTC, ETH, LINK, UNI, ARB.
 * @dev Intended for the BLOKC-5 index without requiring a CirculatingSupply oracle.
 *      Supplies (whole token units):
 *        BTC  =  20,012,568
 *        ETH  = 120,691,190
 *        LINK = 626,849,970
 *        UNI  = 600,483,073
 *        ARB  = 3,478,000,000
 */
contract MarketCapWeightedBlokc5Hardcoded is IIndexCalculation {
    /// @notice Reference to the IndexComponentRegistry for price feed lookups
    IndexComponentRegistry private immutable INDEX_COMPONENT_REGISTRY;

    /// @notice Sanity bound for individual component market cap to catch supply unit errors
    /// @dev Set to 1e30 (~$1 quadrillion) — any market cap above this indicates wrong supply units
    uint256 private constant MAX_COMPONENT_MARKET_CAP = 1e30;

    /// @notice Hardcoded circulating supplies in whole token units
    uint256 private constant BTC_CIRCULATING_SUPPLY = 20_012_568;
    uint256 private constant ETH_CIRCULATING_SUPPLY = 120_691_190;
    uint256 private constant LINK_CIRCULATING_SUPPLY = 727_099_970;
    uint256 private constant UNI_CIRCULATING_SUPPLY = 632_591_562;
    uint256 private constant ARB_CIRCULATING_SUPPLY = 6_040_824_145;

    bytes32 private constant BTC_SYMBOL = bytes32("BTC");
    bytes32 private constant ETH_SYMBOL = bytes32("ETH");
    bytes32 private constant LINK_SYMBOL = bytes32("LINK");
    bytes32 private constant UNI_SYMBOL = bytes32("UNI");
    bytes32 private constant ARB_SYMBOL = bytes32("ARB");

    constructor(address _indexComponentRegistryAddress) {
        if (_indexComponentRegistryAddress == address(0)) {
            revert MarketCapWeightedBlokc5Hardcoded_InvalidIndexComponentRegistryAddress();
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
            if (!success) revert MarketCapWeightedBlokc5Hardcoded_MarketCapOverflow();
            totalMarketCap = result;
        }

        if (totalMarketCap == 0) revert MarketCapWeightedBlokc5Hardcoded_InvalidTotalMarketCap();

        // Second pass: calculate weights from cached market caps.
        // Components below MIN_WEIGHT are floored up to the minimum instead of reverting —
        // a declining component would otherwise permanently brick every garden connected
        // to the index, since index components are immutable once deployed.
        uint256 totalWeight;
        for (uint256 i = 0; i < len; i++) {
            weights[i] = IndexMath.calculateWeight(marketCaps[i], totalMarketCap);
            if (weights[i] < IndexMath.MIN_WEIGHT) {
                weights[i] = IndexMath.MIN_WEIGHT;
            }
            totalWeight += weights[i];
        }

        // Floored weights can push the sum above 100%; scale proportionally so the sum stays
        // within the Index contract's accepted tolerance (1e18 ± 1e14). Note: the Floor
        // rounding of the rescale shaves the just-floored component back below MIN_WEIGHT —
        // the floor guarantees survival of the component, not a per-weight minimum.
        if (totalWeight > IndexMath.PRECISION) {
            for (uint256 i = 0; i < len; i++) {
                weights[i] = Math.mulDiv(weights[i], IndexMath.PRECISION, totalWeight, Math.Rounding.Floor);
            }
        }
    }

    /// @notice Returns the hardcoded circulating supply for a supported symbol
    /// @param symbol Component symbol as bytes32
    function _getCirculatingSupply(bytes32 symbol) internal pure returns (uint256) {
        if (symbol == BTC_SYMBOL) return BTC_CIRCULATING_SUPPLY;
        if (symbol == ETH_SYMBOL) return ETH_CIRCULATING_SUPPLY;
        if (symbol == LINK_SYMBOL) return LINK_CIRCULATING_SUPPLY;
        if (symbol == UNI_SYMBOL) return UNI_CIRCULATING_SUPPLY;
        if (symbol == ARB_SYMBOL) return ARB_CIRCULATING_SUPPLY;
        revert MarketCapWeightedBlokc5Hardcoded_UnsupportedSymbol(symbol);
    }

    /// @notice Calculates market cap for a single component using hardcoded supply
    function _getComponentMarketCap(bytes32 symbol) internal returns (uint256 componentMarketCap) {
        (uint256 componentPrice, uint8 componentPriceDecimals) = _getComponentPrice(symbol);
        uint256 circulatingSupply = _getCirculatingSupply(symbol);
        componentMarketCap = Math.mulDiv(
            circulatingSupply, componentPrice, 10 ** uint256(componentPriceDecimals), Math.Rounding.Floor
        );
        if (componentMarketCap > MAX_COMPONENT_MARKET_CAP) {
            revert MarketCapWeightedBlokc5Hardcoded_MarketCapExceedsSanityBound();
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
