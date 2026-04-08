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

/// @notice Thrown when a component's calculated weight is below the minimum threshold
error MarketCapWeightedBlokc5Hardcoded_ComponentWeightBelowMinimum();

/// @notice Thrown when an unsupported symbol is provided
error MarketCapWeightedBlokc5Hardcoded_UnsupportedSymbol(string symbol);

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

    bytes32 private constant BTC_HASH = keccak256("BTC");
    bytes32 private constant ETH_HASH = keccak256("ETH");
    bytes32 private constant LINK_HASH = keccak256("LINK");
    bytes32 private constant UNI_HASH = keccak256("UNI");
    bytes32 private constant ARB_HASH = keccak256("ARB");

    constructor(address _indexComponentRegistryAddress) {
        if (_indexComponentRegistryAddress == address(0)) {
            revert MarketCapWeightedBlokc5Hardcoded_InvalidIndexComponentRegistryAddress();
        }
        INDEX_COMPONENT_REGISTRY = IndexComponentRegistry(_indexComponentRegistryAddress);
    }

    /// @inheritdoc IIndexCalculation
    function getWeights(string[] memory symbols) external override returns (uint256[] memory weights) {
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

        for (uint256 i = 0; i < len; i++) {
            weights[i] = IndexMath.calculateWeight(marketCaps[i], totalMarketCap);
            if (weights[i] < IndexMath.MIN_WEIGHT) {
                revert MarketCapWeightedBlokc5Hardcoded_ComponentWeightBelowMinimum();
            }
        }
    }

    /// @notice Returns the hardcoded circulating supply for a supported symbol
    /// @param symbol Component symbol ("BTC", "WBTC", "ETH", "WETH", "LINK", "UNI", or "ARB")
    function _getCirculatingSupply(string memory symbol) internal pure returns (uint256) {
        bytes32 symbolHash = keccak256(bytes(symbol));
        if (symbolHash == BTC_HASH) return BTC_CIRCULATING_SUPPLY;
        if (symbolHash == ETH_HASH) return ETH_CIRCULATING_SUPPLY;
        if (symbolHash == LINK_HASH) return LINK_CIRCULATING_SUPPLY;
        if (symbolHash == UNI_HASH) return UNI_CIRCULATING_SUPPLY;
        if (symbolHash == ARB_HASH) return ARB_CIRCULATING_SUPPLY;
        revert MarketCapWeightedBlokc5Hardcoded_UnsupportedSymbol(symbol);
    }

    /// @notice Calculates market cap for a single component using hardcoded supply
    function _getComponentMarketCap(string memory symbol) internal returns (uint256 componentMarketCap) {
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
    function _getComponentPrice(string memory symbol)
        internal
        returns (uint256 componentPrice, uint8 componentPriceDecimals)
    {
        address tokenAddress = INDEX_COMPONENT_REGISTRY.getComponentAddress(symbol);
        componentPrice = INDEX_COMPONENT_REGISTRY.fetchPrice(tokenAddress, symbol);
        componentPriceDecimals = INDEX_COMPONENT_REGISTRY.getOracleRecord(symbol).decimals;
    }
}
