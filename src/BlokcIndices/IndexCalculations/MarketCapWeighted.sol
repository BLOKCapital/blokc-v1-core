//SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/*###############################################################################

    @title MarketCapCalculationType
    @author BLOK Capital DAO
    @notice Enum for the market cap calculation type

################################################################################*/

import { IndexComponentRegistry } from "src/BlokcIndices/IndexComponentRegistry.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IIndexCalculation } from "src/interfaces/IIndexCalculation.sol";
import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";
import { IndexMath } from "src/BlokcIndices/libraries/IndexMath.sol";
import { CirculatingSupply } from "src/BlokcIndices/CirculatingSupply.sol";

error MarketCapWeighted_InvalidIndexComponentRegistryAddress();
error MarketCapWeighted_InvalidTotalMarketCap();
error MarketCapWeighted_MarketCapOverflow();

contract MarketCapWeighted is IIndexCalculation {
    IndexComponentRegistry private immutable _indexComponentRegistry;
    CirculatingSupply private immutable _circulatingSupply;

    constructor(address _indexComponentRegistryAddress) {
        if (_indexComponentRegistryAddress == address(0)) {
            revert MarketCapWeighted_InvalidIndexComponentRegistryAddress();
        }
        _indexComponentRegistry = IndexComponentRegistry(_indexComponentRegistryAddress);
        _circulatingSupply = CirculatingSupply(_indexComponentRegistryAddress);
    }

    function getWeights(address[] memory componentAddresses) public view override returns (uint256[] memory weights) {
        weights = new uint256[](componentAddresses.length);
        uint256 totalMarketCap = _getTotalMarketCap(componentAddresses);
        if (totalMarketCap == 0) revert MarketCapWeighted_InvalidTotalMarketCap();
        for (uint256 i = 0; i < componentAddresses.length; i++) {
            weights[i] = IndexMath.calculateWeight(_getComponentMarketCap(componentAddresses[i]), totalMarketCap);
        }
        return weights;
    }

    function _getTotalMarketCap(address[] memory assetAddresses) internal view returns (uint256 totalMarketCap) {
        for (uint256 i = 0; i < assetAddresses.length; i++) {
            (bool success, uint256 result) = Math.tryAdd(totalMarketCap, _getComponentMarketCap(assetAddresses[i]));
            if (!success) {
                revert MarketCapWeighted_MarketCapOverflow();
            }
            totalMarketCap = result;
        }
    }

    function _getComponentMarketCap(address componentAddress) internal view returns (uint256 componentMarketCap) {
        (uint256 componentPrice, uint256 componentPriceDecimals) = _getComponentPrice(componentAddress);
        componentMarketCap = Math.mulDiv(
            _circulatingSupply.getCirculatingSupply(componentAddress),
            componentPrice,
            10 ** componentPriceDecimals,
            Math.Rounding.Floor
        );
    }

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
