//SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

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
    IndexComponentRegistry private immutable _indexComponentRegistry;

    /// @notice Reference to the CirculatingSupply contract for supply data
    /// @dev Immutable for consistent supply data sources
    CirculatingSupply private immutable _circulatingSupply;

    /// @notice Constructs the MarketCapWeighted calculation strategy
    /// @param _indexComponentRegistryAddress Address of the IndexComponentRegistry
    /// @dev Validates registry address is not zero
    constructor(address _indexComponentRegistryAddress) {
        if (_indexComponentRegistryAddress == address(0)) {
            revert MarketCapWeighted_InvalidIndexComponentRegistryAddress();
        }
        _indexComponentRegistry = IndexComponentRegistry(_indexComponentRegistryAddress);
        _circulatingSupply = CirculatingSupply(_indexComponentRegistryAddress);
    }

    /// @notice Calculates market cap weighted allocations for components
    /// @param componentAddresses Array of component token addresses
    /// @return weights Array of weights scaled to 1e18 (100% = 1e18)
    /// @dev For each component: weight = (component market cap) / (total market cap)
    ///      Uses Chainlink price feeds and circulating supply data
    function getWeights(address[] memory componentAddresses) public view override returns (uint256[] memory weights) {
        weights = new uint256[](componentAddresses.length);
        uint256 totalMarketCap = _getTotalMarketCap(componentAddresses);
        if (totalMarketCap == 0) revert MarketCapWeighted_InvalidTotalMarketCap();
        for (uint256 i = 0; i < componentAddresses.length; i++) {
            weights[i] = IndexMath.calculateWeight(_getComponentMarketCap(componentAddresses[i]), totalMarketCap);
        }
        return weights;
    }

    /// @notice Calculates total market cap across all components
    /// @param assetAddresses Array of component addresses
    /// @return totalMarketCap Sum of all component market caps
    /// @dev Uses safe math to prevent overflow
    function _getTotalMarketCap(address[] memory assetAddresses) internal view returns (uint256 totalMarketCap) {
        for (uint256 i = 0; i < assetAddresses.length; i++) {
            (bool success, uint256 result) = Math.tryAdd(totalMarketCap, _getComponentMarketCap(assetAddresses[i]));
            if (!success) {
                revert MarketCapWeighted_MarketCapOverflow();
            }
            totalMarketCap = result;
        }
    }

    /// @notice Calculates market cap for a single component
    /// @param componentAddress Address of the component token
    /// @return componentMarketCap Market cap = (circulating supply) * (price)
    /// @dev Uses Chainlink price feed and CirculatingSupply contract
    function _getComponentMarketCap(address componentAddress) internal view returns (uint256 componentMarketCap) {
        (uint256 componentPrice, uint256 componentPriceDecimals) = _getComponentPrice(componentAddress);
        string memory componentSymbol = _indexComponentRegistry.getComponentSymbol(componentAddress);
        uint256 componentCirculatingSupply = _circulatingSupply.getSupply(componentSymbol);
        componentMarketCap =
            Math.mulDiv(componentCirculatingSupply, componentPrice, 10 ** componentPriceDecimals, Math.Rounding.Floor);
    }

    /// @notice Retrieves current price for a component from Chainlink oracle
    /// @param componentAddress Address of the component token
    /// @return componentPrice Current price from oracle
    /// @return componentPriceDecimals Decimal precision of the price
    /// @dev Validates oracle data for freshness and completeness
    function _getComponentPrice(address componentAddress)
        internal
        view
        returns (uint256 componentPrice, uint8 componentPriceDecimals)
    {
        AggregatorV3Interface priceFeed =
            AggregatorV3Interface(_indexComponentRegistry.getComponentAddressToPriceFeedAddress(componentAddress));
        (uint80 roundId, int256 price,, uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData();

        IndexMath.validateOracleData(roundId, price, updatedAt, answeredInRound);

        componentPrice = uint256(price);
        componentPriceDecimals = priceFeed.decimals();
    }
}
