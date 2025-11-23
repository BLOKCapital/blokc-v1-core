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

/// @title UniswapFacet Error Tests
/// @notice Tests error conditions for UniswapFacet functions
contract UniswapFacetErrorsTest is UtilityFacetsTestBase {
    function setUp() public override {
        super.setUp();
        _addUtilityFacetsToDiamond();
    }

    function test_RevertIf_SwapDeadlineHasPassed() public {
        IUniswapV3.ExactInputSingleHopSwapParams memory params = IUniswapV3.ExactInputSingleHopSwapParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            swapFee: 3000,
            deadline: block.timestamp - 1, // Past deadline
            amountIn: 1000,
            amountOutMinimum: 900
        });

        vm.prank(owner);
        vm.expectRevert(UniswapV3Facet_SwapDeadlineHasPassed.selector);
        getUniswapV3Facet().swapExactInputSingleHop(params);
    }

    function test_RevertIf_InvalidPathForMultiHop() public {
        IUniswapV3.TokenWithFee[] memory path = new IUniswapV3.TokenWithFee[](1); // Only one token, invalid

        IUniswapV3.ExactInputMultiHopSwapParams memory params = IUniswapV3.ExactInputMultiHopSwapParams({
            pathWithFees: path,
            deadline: block.timestamp + 1000,
            amountIn: 1000,
            amountOutMin: 900
        });

        vm.prank(owner);
        vm.expectRevert(UniswapV3Facet_InvalidPath.selector);
        getUniswapV3Facet().swapExactInputMultiHop(params);
    }

    function test_RevertIf_ZeroPoolAddressForGetSqrtTwapX96() public {
        vm.expectRevert(UniswapV3Facet_InvalidPoolAddress.selector);
        getUniswapV3Facet().getSqrtTwapX96(address(0), 3600);
    }

    function test_RevertIf_PathMustHaveAtLeastTwoPools() public {
        IUniswapV3.PoolInfo[] memory pools = new IUniswapV3.PoolInfo[](1); // Only one pool

        vm.expectRevert(UniswapV3Facet_PathMustHaveAtLeastTwoPools.selector);
        getUniswapV3Facet().getCombinedTwapX96(pools, 3600);
    }

    function test_RevertIf_ZeroPoolAddressInCombinedTwap() public {
        IUniswapV3.PoolInfo[] memory pools = new IUniswapV3.PoolInfo[](2);
        pools[0] = IUniswapV3.PoolInfo({ pool: address(0), inverse: false }); // Zero address
        pools[1] = IUniswapV3.PoolInfo({ pool: makeAddr("pool2"), inverse: false });

        vm.expectRevert(UniswapV3Facet_InvalidPoolAddress.selector);
        getUniswapV3Facet().getCombinedTwapX96(pools, 3600);
    }
}
