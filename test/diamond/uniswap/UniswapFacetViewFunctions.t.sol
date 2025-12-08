// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { UtilityFacetsTestBase } from "../UtilityFacetsTestBase.sol";
import { IUniswapV3 } from "src/diamond/facets/utilityFacets/arbitrumOne/uniswapV3/IUniswapV3.sol";
import { UniswapV3Facet } from "src/diamond/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3Facet.sol";
import {
    UniswapV3Base,
    UniswapV3Facet_InvalidPoolAddress,
    UniswapV3Facet_PathMustHaveAtLeastTwoPools
} from "src/diamond/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3Base.sol";
import { MockUniswapV3Pool } from "test/mocks/MockUniswapV3Pool.sol";
import { TickMath } from "src/diamond/libraries/TickMath.sol";

/// @title UniswapFacet View Functions Tests
/// @notice Tests for TWAP query functions
contract UniswapFacetViewFunctionsTest is UtilityFacetsTestBase {
    MockUniswapV3Pool internal mockPool;
    uint160 internal constant INITIAL_SQRT_PRICE = 79_228_162_514_264_337_593_543_950_336; // 1:1 price in Q64.96

    function setUp() public override {
        super.setUp();
        _addUtilityFacetsToDiamond();

        // Deploy mock pool
        mockPool = new MockUniswapV3Pool(INITIAL_SQRT_PRICE, 0);
    }

    function test_GetSqrtTwapX96_ReturnsSpotPrice_WhenTwapIntervalIsZero() public {
        (uint160 sqrtPriceX96, uint256 deadline) = getUniswapV3Facet().getSqrtTwapX96(address(mockPool), 0);

        assertEq(sqrtPriceX96, INITIAL_SQRT_PRICE);
        assertGe(deadline, block.timestamp);
        assertLe(deadline, block.timestamp + 301); // Should be now + 300s
    }

    function test_GetSqrtTwapX96_ReturnsTWAP_WhenTwapIntervalIsSet() public {
        // Setup observation data for TWAP calculation
        int56[] memory tickCumulatives = new int56[](2);
        tickCumulatives[0] = -1000; // 3600 seconds ago
        tickCumulatives[1] = 0; // now

        uint160[] memory secondsPerLiquidity = new uint160[](2);
        secondsPerLiquidity[0] = 0;
        secondsPerLiquidity[1] = 0;

        mockPool.setObservationData(tickCumulatives, secondsPerLiquidity);

        (uint160 sqrtPriceX96, uint256 deadline) = getUniswapV3Facet().getSqrtTwapX96(address(mockPool), 3600);

        // Average tick should be approximately -1000 / 3600
        int24 expectedTick = int24(int256(-1000) / int256(3600));
        uint160 expectedSqrtPrice = TickMath.getSqrtRatioAtTick(expectedTick);

        assertEq(sqrtPriceX96, expectedSqrtPrice);
        assertGe(deadline, block.timestamp);
    }

    function test_GetSqrtTwapX96_RevertsIf_ZeroPoolAddress() public {
        vm.expectRevert(UniswapV3Facet_InvalidPoolAddress.selector);
        getUniswapV3Facet().getSqrtTwapX96(address(0), 0);
    }

    function test_GetCombinedTwapX96_RevertsIf_LessThanTwoPools() public {
        IUniswapV3.PoolInfo[] memory pools = new IUniswapV3.PoolInfo[](1);
        pools[0] = IUniswapV3.PoolInfo({ pool: address(mockPool), inverse: false });

        vm.expectRevert(UniswapV3Facet_PathMustHaveAtLeastTwoPools.selector);
        getUniswapV3Facet().getCombinedTwapX96(pools, 0);
    }

    function test_GetCombinedTwapX96_CombinesTwoPools() public {
        MockUniswapV3Pool mockPool2 = new MockUniswapV3Pool(INITIAL_SQRT_PRICE, 0);

        IUniswapV3.PoolInfo[] memory pools = new IUniswapV3.PoolInfo[](2);
        pools[0] = IUniswapV3.PoolInfo({ pool: address(mockPool), inverse: false });
        pools[1] = IUniswapV3.PoolInfo({ pool: address(mockPool2), inverse: false });

        (uint256 combinedPrice, uint256 deadline) = getUniswapV3Facet().getCombinedTwapX96(pools, 0);

        // Combined price should be the product of both prices (in Q96)
        assertGt(combinedPrice, 0);
        assertGe(deadline, block.timestamp);
    }

    function test_GetCombinedTwapX96_HandlesInversePools() public {
        MockUniswapV3Pool mockPool2 = new MockUniswapV3Pool(INITIAL_SQRT_PRICE, 0);

        IUniswapV3.PoolInfo[] memory pools = new IUniswapV3.PoolInfo[](2);
        pools[0] = IUniswapV3.PoolInfo({ pool: address(mockPool), inverse: false });
        pools[1] = IUniswapV3.PoolInfo({ pool: address(mockPool2), inverse: false });

        (uint256 combinedPrice, uint256 deadline) = getUniswapV3Facet().getCombinedTwapX96(pools, 0);

        assertGt(combinedPrice, 0);
        assertGe(deadline, block.timestamp);
    }

    function test_GetCombinedTwapX96_RevertsIf_ZeroPoolAddress() public {
        IUniswapV3.PoolInfo[] memory pools = new IUniswapV3.PoolInfo[](2);
        pools[0] = IUniswapV3.PoolInfo({ pool: address(0), inverse: false });
        pools[1] = IUniswapV3.PoolInfo({ pool: address(mockPool), inverse: false });

        vm.expectRevert(UniswapV3Facet_InvalidPoolAddress.selector);
        getUniswapV3Facet().getCombinedTwapX96(pools, 0);
    }
}
