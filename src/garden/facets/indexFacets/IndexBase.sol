//SPDX-License-Identifier: MIT License
pragma solidity ^0.8.31;

import { IndexFactory } from "src/indices/IndexFactory.sol";
import { Index } from "src/indices/Index.sol";
import { UniswapV3Base } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3Base.sol";
import { IndexStorage } from "src/garden/facets/indexFacets/IndexStorage.sol";
import { IndexComponentRegistry } from "src/indices/IndexComponentRegistry.sol";
import { IUniswapV3 } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/IUniswapV3.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IndexMath } from "src/indices/libraries/IndexMath.sol";
import { LibDiamond } from "src/garden/libraries/LibDiamond.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when asset address is invalid or zero
/// @param assetAddress The invalid asset address
error IndexFacet_InvalidAssetAddress(address assetAddress);

/// @notice Thrown when a mathematical addition causes overflow
/// @param value1 The first value that caused the overflow
/// @param value2 The second value that caused the overflow
error IndexFacet_MathOverflowedAdd(uint256 value1, uint256 value2);

/// @notice Thrown when attempting to rebalance without a connected index
error IndexFacet_NoIndexConnected();

/// @notice Thrown when asset information is invalid or incomplete
error IndexFacet_InvalidAssetInfo();

/// @notice Thrown when attempting to connect to an unregistered index
/// @param indexAddress The unregistered index address
error IndexFacet_IndexNotRegistered(address indexAddress);

/// @notice Thrown when insufficient balance for operation
error IndexFacet_InsufficientBalance();

abstract contract IndexBase is UniswapV3Base {
    // ========================================================================
    // Events
    // ========================================================================

    /// @notice Emitted when garden successfully connects to an index
    /// @param indexAddress Address of the connected index
    event IndexConnected(address indexed indexAddress);

    /// @notice Emitted when garden disconnects from its index
    /// @param indexAddress Address of the disconnected index
    event IndexDisconnected(address indexed indexAddress);

    /// @notice Emitted when rebalance operation begins
    /// @param timestamp Block timestamp when rebalance started
    /// @param garden Address of the garden initiating the rebalance
    /// @param indexAddress Address of the index being tracked
    event RebalanceStarted(uint256 timestamp, address garden, address indexed indexAddress);

    /// @notice Emitted when rebalance operation completes
    /// @param timestamp Block timestamp when rebalance completed
    /// @param totalValue Total portfolio value in USD
    event RebalanceCompleted(uint256 timestamp, uint256 totalValue);

    /// @notice Emitted when tokens are swapped during rebalance
    /// @param tokenIn Address of token being sold
    /// @param tokenOut Address of token being bought
    /// @param amountIn Amount of tokenIn sold
    /// @param amountOut Amount of tokenOut received
    event AssetSwapped(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    function _connectToIndex(address indexAddress) internal {
        if (!IndexFactory(IndexStorage.INDEX_FACTORY_ADDRESS).isIndexRegistered(indexAddress)) {
            revert IndexFacet_IndexNotRegistered(indexAddress);
        }
        Index(indexAddress).connectGardenToIndex();

        // Store the connected index address
        IndexStorage.layout().indexAddress = indexAddress;
        LibDiamond.layout().isConnectedToIndex = true;
        _rebalance();
        emit IndexConnected(indexAddress);
    }

    function _disconnectFromIndex() internal {
        address indexAddress = IndexStorage.layout().indexAddress;
        Index(indexAddress).disconnectGardenFromIndex();

        // Clear the connected index address
        IndexStorage.layout().indexAddress = address(0);
        LibDiamond.layout().isConnectedToIndex = false;
        emit IndexDisconnected(indexAddress);
    }

    /// @notice Internal function implementing the rebalance algorithm
    /// @dev Rebalancing process:
    ///      1. Converts any USDC holdings to WETH (base currency)
    ///      2. Gets current component balances and prices from Chainlink oracles
    ///      3. Calculates total portfolio value in USD
    ///      4. Determines target holdings based on index weights
    ///      5. Sells excess holdings (converts to WETH)
    ///      6. Buys deficient holdings (using WETH)
    ///
    ///      Uses slippage protection and minimum swap thresholds to avoid failed transactions.
    ///      All prices are validated for freshness via IndexMath.validateOracleData.
    function _rebalance() internal {
        address indexAddress = IndexStorage.layout().indexAddress;
        if (indexAddress == address(0)) revert IndexFacet_NoIndexConnected();

        // Get assets and weights from the index
        (string[] memory symbols, uint256[] memory weights) = Index(indexAddress).getWeights();

        address wethAddress = IndexStorage.WETH_ADDRESS;
        address usdcAddress = IndexStorage.USDC_ADDRESS;

        // Step 1: Convert any USDC balance to WETH first (minimum threshold to avoid dust)
        uint256 usdcBalance = IERC20(usdcAddress).balanceOf(address(this));
        if (usdcBalance > IndexStorage.MIN_SWAP_AMOUNT) {
            // Get current WETH price from Chainlink oracle with validation
            (uint80 roundId, int256 wethPriceUsd,, uint256 updatedAt, uint80 answeredInRound) =
                AggregatorV3Interface(IndexStorage.WETH_PRICE_FEED_ADDRESS).latestRoundData();

            IndexMath.validateOracleData(roundId, wethPriceUsd, updatedAt, answeredInRound);

            IUniswapV3.UniswapV3ExactInputSingleParams memory swapParams = IUniswapV3.UniswapV3ExactInputSingleParams({
                amountIn: usdcBalance,
                amountOutMinimum: 0,
                deadline: block.timestamp + IndexStorage.SWAP_DEADLINE_SECONDS,
                tokenIn: usdcAddress,
                tokenOut: wethAddress
            });
            uint256 amountOut = _uniswapV3ExactInputSingle(swapParams);
            emit AssetSwapped(usdcAddress, wethAddress, usdcBalance, amountOut);
        }

        // Step 2: Get current balances and decimals for all assets
        uint256[] memory balances = new uint256[](symbols.length);
        uint8[] memory decimals = new uint8[](symbols.length);
        uint256[] memory prices = new uint256[](symbols.length);
        uint8[] memory priceDecimals = new uint8[](symbols.length);
        uint256[] memory currentValuesInUsd = new uint256[](symbols.length);

        uint256 totalPortfolioValueInUsd = 0;

        for (uint256 i = 0; i < symbols.length; i++) {
            IndexComponentRegistry componentRegistry =
                IndexComponentRegistry(IndexStorage.INDEX_COMPONENT_REGISTRY_ADDRESS);

            address componentAddress = componentRegistry.getComponentAddress(symbols[i]);

            balances[i] = IERC20(componentAddress).balanceOf(address(this));
            decimals[i] = IERC20Metadata(componentAddress).decimals();

            address priceFeedAddress = componentRegistry.getComponentSymbolToPriceFeedAddress(symbols[i]);

            AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress);

            (uint80 roundId, int256 price,, uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData();

            IndexMath.validateOracleData(roundId, price, updatedAt, answeredInRound);

            prices[i] = uint256(price);

            priceDecimals[i] = uint8(priceFeed.decimals());

            // Step 3: Calculate total portfolio value in USD
            uint256 tokenValueInUsd = IndexMath.tokenToUsd(balances[i], prices[i], decimals[i], priceDecimals[i]);
            currentValuesInUsd[i] = tokenValueInUsd;
            totalPortfolioValueInUsd += tokenValueInUsd;
        }

        uint256[] memory targetValuesInUsd = new uint256[](symbols.length);

        for (uint256 i = 0; i < symbols.length; i++) {
            address componentAddress =
                IndexComponentRegistry(IndexStorage.INDEX_COMPONENT_REGISTRY_ADDRESS).getComponentAddress(symbols[i]);

            // Step 4: Calculate the target values for each asset
            targetValuesInUsd[i] =
                Math.mulDiv(totalPortfolioValueInUsd, weights[i], IndexStorage.PRECISION, Math.Rounding.Floor);

            if (componentAddress == wethAddress) continue; // Don't swap WETH for WETH

            // Step 5: Sell excess holdings first
            if (currentValuesInUsd[i] > targetValuesInUsd[i]) {
                uint256 excessValueInUsd = currentValuesInUsd[i] - targetValuesInUsd[i];

                // Skip dust amounts to avoid DEX reverts
                if (excessValueInUsd < IndexStorage.MIN_REBALANCE_VALUE_USD) {
                    continue;
                }
                // Convert excess USD value to token amount to sell
                uint256 amountToSell = IndexMath.usdToToken(excessValueInUsd, prices[i], decimals[i], priceDecimals[i]);

                IUniswapV3.UniswapV3ExactInputSingleParams memory swapParams = IUniswapV3.UniswapV3ExactInputSingleParams({
                    amountIn: amountToSell,
                    amountOutMinimum: 0,
                    deadline: block.timestamp + IndexStorage.SWAP_DEADLINE_SECONDS,
                    tokenIn: componentAddress,
                    tokenOut: wethAddress
                });
                _uniswapV3ExactInputSingle(swapParams);
            }
        }

        // Step 6: Buy deficient holdings (skip WETH)
        for (uint256 i = 0; i < symbols.length; i++) {
            address componentAddress =
                IndexComponentRegistry(IndexStorage.INDEX_COMPONENT_REGISTRY_ADDRESS).getComponentAddress(symbols[i]);
            if (componentAddress == wethAddress) continue; // Don't swap WETH for WETH

            if (currentValuesInUsd[i] < targetValuesInUsd[i]) {
                uint256 deficitValueInUsd = targetValuesInUsd[i] - currentValuesInUsd[i];

                // Skip dust amounts to avoid DEX reverts
                if (deficitValueInUsd < IndexStorage.MIN_REBALANCE_VALUE_USD) {
                    continue;
                }

                // Convert deficit value to token amount to buy
                uint256 amountToBuy = IndexMath.usdToToken(deficitValueInUsd, prices[i], decimals[i], priceDecimals[i]);

                IUniswapV3.UniswapV3ExactOutputSingleParams memory swapParams =
                    IUniswapV3.UniswapV3ExactOutputSingleParams({
                        amountOut: amountToBuy,
                        amountInMaximum: 0,
                        deadline: block.timestamp + IndexStorage.SWAP_DEADLINE_SECONDS,
                        tokenIn: wethAddress,
                        tokenOut: componentAddress
                    });
                _uniswapV3ExactOutputSingle(swapParams);
            }
        }

        IndexStorage.layout().lastRebalanceTimestamp = block.timestamp;

        emit RebalanceCompleted(block.timestamp, totalPortfolioValueInUsd);
    }

    /// @notice Internal function to check if garden is connected to an index
    /// @return True if connected to an index, false otherwise
    function _isConnectedToIndex() internal view returns (bool) {
        return LibDiamond.layout().isConnectedToIndex;
    }
}
