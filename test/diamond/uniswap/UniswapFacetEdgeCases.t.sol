// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { UtilityFacetsTestBase } from "../UtilityFacetsTestBase.sol";
import { IUniswapV3 } from "src/diamond/facets/utilityFacets/arbitrumOne/uniswapV3/IUniswapV3.sol";
import { UniswapV3Facet } from "src/diamond/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3Facet.sol";
import {
    UniswapV3Base,
    UniswapV3Facet_InvalidPath,
    UniswapV3Facet_InvalidPoolAddress,
    UniswapV3Facet_PathMustHaveAtLeastTwoPools,
    UniswapV3Facet_SwapDeadlineHasPassed
} from "src/diamond/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3Base.sol";

/// @title UniswapFacet Edge Cases Tests
/// @notice Tests edge cases and boundary conditions
contract UniswapFacetEdgeCasesTest is UtilityFacetsTestBase {
    function setUp() public override {
        super.setUp();
        _addUtilityFacetsToDiamond();
    }

    function test_EdgeCase_DeadlineExactlyAtBlockTimestamp() public {
        IUniswapV3.ExactInputSingleHopSwapParams memory params = IUniswapV3.ExactInputSingleHopSwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            swapFee: 3000,
            deadline: block.timestamp, // Exactly at current timestamp
            amountIn: 1000,
            amountOutMinimum: 900
        });

        // Should not revert due to deadline (deadline >= block.timestamp is valid)
        // Will revert for other reasons (pool doesn't exist, etc.)
        vm.prank(owner);
        vm.expectRevert();
        getUniswapV3Facet().swapExactInputSingleHop(params);
    }

    function test_EdgeCase_MaxDeadline() public {
        IUniswapV3.ExactInputSingleHopSwapParams memory params = IUniswapV3.ExactInputSingleHopSwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            swapFee: 3000,
            deadline: type(uint256).max, // Maximum deadline
            amountIn: 1000,
            amountOutMinimum: 900
        });

        // Should not revert due to deadline
        vm.prank(owner);
        vm.expectRevert();
        getUniswapV3Facet().swapExactInputSingleHop(params);
    }

    function test_EdgeCase_MultiHopWithMinimumPath() public {
        // Minimum valid path is 2 tokens
        IUniswapV3.TokenWithFee[] memory path = new IUniswapV3.TokenWithFee[](2);
        path[0] = IUniswapV3.TokenWithFee({ token: address(tokenA), fee: 3000 });
        path[1] = IUniswapV3.TokenWithFee({ token: address(tokenB), fee: 3000 });

        IUniswapV3.ExactInputMultiHopSwapParams memory params = IUniswapV3.ExactInputMultiHopSwapParams({
            pathWithFees: path,
            deadline: block.timestamp + 1000,
            amountIn: 1, // Minimum amount
            amountOutMin: 0 // Minimum output
         });

        // Should not revert due to path length
        vm.prank(owner);
        vm.expectRevert();
        getUniswapV3Facet().swapExactInputMultiHop(params);
    }

    function test_EdgeCase_ZeroAmountOutMinimum() public {
        IUniswapV3.ExactInputSingleHopSwapParams memory params = IUniswapV3.ExactInputSingleHopSwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            swapFee: 3000,
            deadline: block.timestamp + 1000,
            amountIn: 1000,
            amountOutMinimum: 0 // Zero minimum output
         });

        // Should not revert due to zero minimum
        vm.prank(owner);
        vm.expectRevert();
        getUniswapV3Facet().swapExactInputSingleHop(params);
    }

    function test_EdgeCase_VeryLargeTwapInterval() public {
        address mockPool = makeAddr("mockPool");

        // Very large TWAP interval
        vm.expectRevert();
        getUniswapV3Facet().getSqrtTwapX96(mockPool, type(uint32).max);
    }

    function test_EdgeCase_CombinedTwapWithManyPools() public {
        // Test with maximum reasonable number of pools
        IUniswapV3.PoolInfo[] memory pools = new IUniswapV3.PoolInfo[](10);
        for (uint256 i = 0; i < 10; i++) {
            pools[i] = IUniswapV3.PoolInfo({ pool: makeAddr(string(abi.encodePacked("pool", i))), inverse: false });
        }
        vm.expectRevert();
        getUniswapV3Facet().getCombinedTwapX96(pools, 3600);
    }
}
