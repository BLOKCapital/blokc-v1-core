//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IndexFactory } from "src/BlokcIndices/IndexFactory.sol";
import { Index } from "src/BlokcIndices/Index.sol";
import { UniswapV3Base } from "src/diamond/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3Base.sol";
import { IndexStorage } from "src/diamond/facets/indexFacets/IndexStorage.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";
import { IUniswapV3 } from "src/diamond/facets/utilityFacets/arbitrumOne/uniswapV3/IUniswapV3.sol";
import { IIndexCalculation } from "src/interfaces/IIndexCalculation.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IndexMath } from "src/BlokcIndices/libraries/IndexMath.sol";
import { Facet } from "src/diamond/facets/Facet.sol";
import { IndexComponentRegistry } from "src/BlokcIndices/IndexComponentRegistry.sol";

error IndexFacet_InvalidAssetAddress();
error IndexFacet_MathOverflowedAdd();
error IndexFacet_NoIndexConnected();
error IndexFacet_InvalidAssetInfo();
error IndexFacet_IndexNotRegistered(address indexAddress);
error IndexFacet_InsufficientBalance();

contract IndexFacet is UniswapV3Base, Facet {
    // ========================================================================
    // Events
    // ========================================================================

    event IndexConnected(address indexed indexAddress);
    event IndexDisconnected(address indexed indexAddress);
    event RebalanceStarted(uint256 timestamp, address indexed indexAddress);
    event RebalanceCompleted(uint256 timestamp, uint256 totalValue);
    event AssetSwapped(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    // ========================================================================
    // External Functions
    // ========================================================================

    /// @notice Connect the garden to an index for automated rebalancing
    /// @param indexAddress Address of the index to connect to
    function connectToIndex(address indexAddress) external nonReentrant onlyDiamondOwner {
        if (!IndexFactory(IndexStorage.INDEX_FACTORY_ADDRESS).isIndexRegistered(indexAddress)) {
            revert IndexFacet_IndexNotRegistered(indexAddress);
        }
        Index(indexAddress).connectGardenToIndex();

        // Store the connected index address
        IndexStorage.layout().indexAddress = indexAddress;

        emit IndexConnected(indexAddress);
    }

    /// @notice Disconnect the garden from the current index
    function disconnectFromIndex() external nonReentrant onlyDiamondOwner {
        address oldIndexAddress = IndexStorage.layout().indexAddress;
        Index(oldIndexAddress).disconnectGardenFromIndex();

        IndexStorage.layout().indexAddress = address(0);

        emit IndexDisconnected(oldIndexAddress);
    }

    /// @notice Manually trigger a rebalance of the portfolio
    function rebalance() external nonReentrant onlyDiamondOwner {
        _rebalance();
    }

    // ========================================================================
    // Internal Functions
    // ========================================================================

    /// @notice Internal function to rebalance portfolio according to index weights
    /// @dev Uses fresh prices fetched from the index calculation contract
    function _rebalance() internal {
        address indexAddress = IndexStorage.layout().indexAddress;
        if (indexAddress == address(0)) revert IndexFacet_NoIndexConnected();

        // Get assets and weights from the index
        (address[] memory componentAddresses, uint256[] memory weights) = Index(indexAddress).getWeights();

        address wethAddress = IndexStorage.WETH_ADDRESS;
        address usdcAddress = IndexStorage.USDC_ADDRESS;

        emit RebalanceStarted(block.timestamp, indexAddress);

        // Step 1: Convert any USDC balance to WETH first (minimum threshold to avoid dust)
        uint256 usdcBalance = IERC20(usdcAddress).balanceOf(address(this));
        if (usdcBalance > IndexStorage.MIN_SWAP_AMOUNT) {
            // Get current WETH price from Chainlink oracle with validation
            (uint80 roundId, int256 wethPriceUsd,, uint256 updatedAt, uint80 answeredInRound) =
                AggregatorV3Interface(IndexStorage.WETH_PRICE_FEED_ADDRESS).latestRoundData();

            IndexMath.validateOracleData(roundId, wethPriceUsd, updatedAt, answeredInRound);

            // Calculate USDC to WETH price ratio (1e18 scale)
            // USDC/WETH = 1 / (WETH/USD) with proper decimal adjustment
            // Price ratio = 1e18 * 1e8 / wethPriceUsd = 1e26 / wethPriceUsd
            uint256 usdcToWethRatio = Math.mulDiv(1e26, 1, uint256(wethPriceUsd), Math.Rounding.Floor);

            // Calculate minimum output with slippage protection
            uint256 minWethOut = IndexMath.calculateMinOutputWithSlippage(
                usdcBalance,
                6, // USDC decimals
                18, // WETH decimals
                usdcToWethRatio,
                IndexStorage.MAX_SLIPPAGE_BPS
            );

            IUniswapV3.ExactInputSingleHopSwapParams memory swapParams = IUniswapV3.ExactInputSingleHopSwapParams({
                swapFee: 100,
                amountIn: usdcBalance,
                amountOutMinimum: minWethOut,
                deadline: block.timestamp + IndexStorage.SWAP_DEADLINE_SECONDS,
                tokenIn: usdcAddress,
                tokenOut: wethAddress
            });
            _swapExactInputSingleHop(swapParams);
            emit AssetSwapped(usdcAddress, wethAddress, usdcBalance, minWethOut);
        }

        // Step 2: Get current balances and decimals for all assets
        uint256[] memory balances = new uint256[](componentAddresses.length);
        uint8[] memory decimals = new uint8[](componentAddresses.length);

        for (uint256 i = 0; i < componentAddresses.length; i++) {
            balances[i] = IERC20(componentAddresses[i]).balanceOf(address(this));
            decimals[i] = IERC20Metadata(componentAddresses[i]).decimals();
        }

        uint256[] memory pricesInWeth = new uint256[](componentAddresses.length);

        for (uint256 i = 0; i < componentAddresses.length; i++) {
            (uint80 roundId, int256 price,, uint256 updatedAt, uint80 answeredInRound) = AggregatorV3Interface(
                IndexComponentRegistry(IndexStorage.INDEX_COMPONENT_REGISTRY_ADDRESS)
                    .getComponentAddressToPriceFeedAddress(componentAddresses[i])
            ).latestRoundData();

            IndexMath.validateOracleData(roundId, price, updatedAt, answeredInRound);
            pricesInWeth[i] = uint256(price);
        }

        // Step 3: Calculate total portfolio value in WETH
        uint256 totalPortfolioValueInWeth =
            IndexMath.calculateTotalPortfolioValueInWeth(balances, pricesInWeth, decimals);

        // Step 4: Calculate current and target values for each asset
        uint256[] memory currentValuesInWeth = new uint256[](componentAddresses.length);
        uint256[] memory targetValuesInWeth = new uint256[](componentAddresses.length);

        for (uint256 i = 0; i < componentAddresses.length; i++) {
            currentValuesInWeth[i] = IndexMath.calculateAssetBalanceInWeth(balances[i], pricesInWeth[i], decimals[i]);
            targetValuesInWeth[i] = IndexMath.calculateExpectedValue(totalPortfolioValueInWeth, weights[i]);
        }

        // Step 5: Sell excess holdings first (skip WETH)
        for (uint256 i = 0; i < componentAddresses.length; i++) {
            if (componentAddresses[i] == wethAddress) continue; // Don't swap WETH for WETH

            if (currentValuesInWeth[i] > targetValuesInWeth[i]) {
                uint256 excessValueInWeth = currentValuesInWeth[i] - targetValuesInWeth[i];

                // Skip dust amounts to avoid DEX reverts
                if (excessValueInWeth < IndexStorage.MIN_REBALANCE_VALUE_WETH) {
                    continue;
                }

                // Convert excess WETH value to token amount to sell
                uint256 amountToSell = IndexMath.wethToToken(excessValueInWeth, pricesInWeth[i], decimals[i]);

                // Calculate minimum WETH output with slippage protection
                uint256 minWethOut = IndexMath.applySlippageDown(excessValueInWeth, IndexStorage.MAX_SLIPPAGE_BPS);

                IUniswapV3.ExactInputSingleHopSwapParams memory swapParams = IUniswapV3.ExactInputSingleHopSwapParams({
                    swapFee: 100,
                    amountIn: amountToSell,
                    amountOutMinimum: minWethOut,
                    deadline: block.timestamp + IndexStorage.SWAP_DEADLINE_SECONDS,
                    tokenIn: componentAddresses[i],
                    tokenOut: wethAddress
                });
                _swapExactInputSingleHop(swapParams);
                emit AssetSwapped(componentAddresses[i], wethAddress, amountToSell, minWethOut);
            }
        }

        // Step 6: Buy deficient holdings (skip WETH)
        for (uint256 i = 0; i < componentAddresses.length; i++) {
            if (componentAddresses[i] == wethAddress) continue; // Don't swap WETH for WETH

            if (currentValuesInWeth[i] < targetValuesInWeth[i]) {
                uint256 deficitValueInWeth = targetValuesInWeth[i] - currentValuesInWeth[i];

                // Skip dust amounts to avoid DEX reverts
                if (deficitValueInWeth < IndexStorage.MIN_REBALANCE_VALUE_WETH) {
                    continue;
                }

                // Convert deficit WETH value to token amount to buy
                uint256 amountToBuy = IndexMath.wethToToken(deficitValueInWeth, pricesInWeth[i], decimals[i]);

                // Calculate maximum WETH input with slippage protection
                uint256 maxWethIn = IndexMath.applySlippageUp(deficitValueInWeth, IndexStorage.MAX_SLIPPAGE_BPS);

                IUniswapV3.ExactOutputSingleHopSwapParams memory swapParams = IUniswapV3.ExactOutputSingleHopSwapParams({
                    swapFee: 100,
                    amountOut: amountToBuy,
                    amountInMaximum: maxWethIn,
                    deadline: block.timestamp + IndexStorage.SWAP_DEADLINE_SECONDS,
                    tokenIn: wethAddress,
                    tokenOut: componentAddresses[i]
                });
                _swapExactOutputSingleHop(swapParams);
                emit AssetSwapped(wethAddress, componentAddresses[i], maxWethIn, amountToBuy);
            }
        }

        emit RebalanceCompleted(block.timestamp, totalPortfolioValueInWeth);

        // Update last rebalance timestamp
        IndexStorage.layout().lastRebalanceTimestamp = block.timestamp;
    }
}
