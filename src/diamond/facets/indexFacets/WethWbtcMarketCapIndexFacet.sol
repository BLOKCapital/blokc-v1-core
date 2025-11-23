//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title WethWbtcMarketCapIndexFacet
    @author BLOK Capital DAO
    @notice Facet exposing index functions
    @dev This facet provides integration with WETH/WBTC market cap index functions

################################################################################*/

// import { IndexFactory } from "src/BlokcIndices/IndexFactory.sol";
// import { Index } from "src/BlokcIndices/Index.sol";
// import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import { UniswapV3Base } from "src/diamond/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3Base.sol";
// import { IUniswapV3 } from "src/diamond/facets/utilityFacets/arbitrumOne/uniswapV3/IUniswapV3.sol";

// contract WethWbtcMarketCapIndexFacet is UniswapV3Base {
//     address private constant INDEX_FACTORY_ADDRESS = 0x1234567890123456789012345678901234567890;
//     address private constant WETH_WBTC_MARKET_CAP_INDEX_ADDRESS = 0x1234567890123456789012345678901234567890;

//     address private constant WETH_ADDRESS = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
//     address private constant WBTC_ADDRESS = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
//     address private constant USDC_ADDRESS = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

//     uint256 private constant REBALANCE_THRESHOLD = 0.0001e18;
//     uint256 private constant PRECISION = 1e18;

//     uint8 private constant WETH_DECIMALS = 18;
//     uint8 private constant WBTC_DECIMALS = 8;
//     uint8 private constant USDC_DECIMALS = 6;

//     error WethWbtcMarketCapIndexFacet_InvalidWeightsAndPrices();

//     event IndexConnected(address indexed indexAddress);
//     event IndexDisconnected(address indexed indexAddress);
//     event Rebalanced(uint256 wethBalance, uint256 wbtcBalance, uint256 usdcBalance);

//     function connectToIndex(address indexAddress) external {
//         IndexFactory(INDEX_FACTORY_ADDRESS).connectToIndex(indexAddress);
//         _rebalance();

//         emit IndexConnected(indexAddress);
//     }

//     function disconnectFromIndex(address indexAddress) external {
//         _rebalance();
//         IndexFactory(INDEX_FACTORY_ADDRESS).disconnectFromIndex(indexAddress);
//         emit IndexDisconnected(indexAddress);
//     }

//     function rebalance() external {
//         _rebalance();
//     }

//     function getConnectedIndex() external view returns (address) {
//         return IndexFactory(INDEX_FACTORY_ADDRESS).getIndexForGarden(address(this));
//     }

//     function _rebalance() internal {
//         address indexAddress = IndexFactory(INDEX_FACTORY_ADDRESS).getIndexForGarden(address(this));
//         (uint256[] memory weights, uint256[] memory prices,) = Index(indexAddress).getWeightsAndPrices();

//         if (weights.length != 2 || prices.length != 2) {
//             revert WethWbtcMarketCapIndexFacet_InvalidWeightsAndPrices();
//         }

//         uint256 wethBalance = IERC20(WETH_ADDRESS).balanceOf(address(this));
//         uint256 wbtcBalance = IERC20(WBTC_ADDRESS).balanceOf(address(this));
//         uint256 usdcBalance = IERC20(USDC_ADDRESS).balanceOf(address(this));

//         uint256 wethBalanceInUsd = wethBalance * prices[0];
//         uint256 wbtcBalanceInUsd = wbtcBalance * prices[1];

//         uint256 totalBalanceInUsd = wethBalanceInUsd + wbtcBalanceInUsd;
//         uint256 totalBalanceInUsdc = usdcBalance + totalBalanceInUsd;

//         uint256 expectedWethBalanceInUsd = totalBalanceInUsdc * weights[0];
//         uint256 expectedWbtcBalanceInUsd = totalBalanceInUsdc * weights[1];

//         //Weth is our base token to swap all the excessive tokens to it and then swap to wbtc
//         if (usdcBalance > 1e6) {
//             address usdcAddress = USDC_ADDRESS;
//             address wethAddress = WETH_ADDRESS;
//             uint256 amountToSellUsdc = usdcBalance - 1e6;
//             IUniswapV3.ExactInputSingleHopSwapParams memory params = IUniswapV3.ExactInputSingleHopSwapParams({
//                 swapFee: 100,
//                 amountIn: amountToSellUsdc,
//                 amountOutMinimum: 0,
//                 deadline: block.timestamp + 300,
//                 tokenIn: usdcAddress,
//                 tokenOut: wethAddress
//             });
//             _swapExactInputSingleHop(params);
//         }
//         if (wbtcBalanceInUsd > expectedWbtcBalanceInUsd) {
//             address wbtcAddress = WBTC_ADDRESS;
//             address wethAddress = WETH_ADDRESS;
//             uint256 amountToSellWbtc = (wbtcBalanceInUsd - expectedWbtcBalanceInUsd) / prices[1];
//             IUniswapV3.ExactInputSingleHopSwapParams memory params = IUniswapV3.ExactInputSingleHopSwapParams({
//                 swapFee: 100,
//                 amountIn: amountToSellWbtc,
//                 amountOutMinimum: 0,
//                 deadline: block.timestamp + 300,
//                 tokenIn: wbtcAddress,
//                 tokenOut: wethAddress
//             });
//             _swapExactInputSingleHop(params);
//         } else {
//             address wethAddress = WETH_ADDRESS;
//             address wbtcAddress = WBTC_ADDRESS;
//             uint256 amountToBuyWbtc = (expectedWbtcBalanceInUsd - wbtcBalanceInUsd) / prices[1];
//             IUniswapV3.ExactInputSingleHopSwapParams memory params = IUniswapV3.ExactInputSingleHopSwapParams({
//                 swapFee: 100,
//                 amountIn: amountToBuyWbtc,
//                 amountOutMinimum: 0,
//                 deadline: block.timestamp + 300,
//                 tokenIn: wethAddress,
//                 tokenOut: wbtcAddress
//             });
//             _swapExactInputSingleHop(params);
//         }

//         emit Rebalanced(wethBalance, wbtcBalance, usdcBalance);
//     }
// }
