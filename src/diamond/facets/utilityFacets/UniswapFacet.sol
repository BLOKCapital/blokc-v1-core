// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/*###############################################################################

    @title UniswapFacet
    @author BLOK Capital DAO
    @notice External facet exposing Uniswap swap and TWAP functions; delegates logic to UniswapBase.
    @dev This facet wires the IUniswap interface to internal UniswapBase implementation
         and registers the interface id during initialization.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import { IUniswap } from "src/interfaces/IUniswap.sol";
import { IPoolRegistry } from "src/interfaces/IPoolRegistry.sol";
import { LibDiamond } from "src/diamond/libraries/LibDiamond.sol";
import { TickMath } from "src/diamond/libraries/TickMath.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

error UniswapFacet_InsufficientBalance();
error UniswapFacet_ApprovalFailed();
error UniswapFacet_UnregisteredPool();
error UniswapFacet_SwapDeadlineHasPassed();
error UniswapFacet_InvalidPath();
error UniswapFacet_InvalidAmount();
error UniswapFacet_PathMustHaveAtLeastTwoPools();

contract UniswapFacet is IUniswap {
    event UniswapFacetTokensSwapped(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    address internal constant UNISWAP_FACTORY_ADDRESS = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    /// @inheritdoc IUniswap
    function swapExactInputSingleHop(UniswapSingleHopSwapParams calldata params) external override {
        ISwapRouter router = ISwapRouter(params.routerAddress);
        IERC20 tokenIn = IERC20(params.tokenIn);

        // deadline check and balance check
        if (block.timestamp > params.deadline) revert UniswapFacet_SwapDeadlineHasPassed();
        if (tokenIn.balanceOf(address(this)) < params.amountIn) revert UniswapFacet_InsufficientBalance();

        // get pool address from factory
        address pool =
            IUniswapV3Factory(UNISWAP_FACTORY_ADDRESS).getPool(params.tokenIn, params.tokenOut, params.swapFee);

        address liquidityPoolRegistry = LibDiamond.liquidityPoolRegistry();

        // check pool exists and is registered
        if (pool == address(0) || !IPoolRegistry(liquidityPoolRegistry).isPoolRegistered(pool)) {
            revert UniswapFacet_UnregisteredPool();
        }

        // set approval for router using safe pattern (reset to 0 if >0)
        uint256 currentAllowance = tokenIn.allowance(address(this), params.routerAddress);
        if (currentAllowance > 0) {
            if (!tokenIn.approve(address(router), 0)) revert UniswapFacet_ApprovalFailed();
        }
        if (!tokenIn.approve(address(router), params.amountIn)) revert UniswapFacet_ApprovalFailed();

        // build swap params and execute
        ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter.ExactInputSingleParams({
            tokenIn: params.tokenIn,
            tokenOut: params.tokenOut,
            fee: params.swapFee,
            recipient: address(this),
            deadline: params.deadline,
            amountIn: params.amountIn,
            amountOutMinimum: params.amountOutMinimum,
            sqrtPriceLimitX96: 0
        });

        // execute the swap
        uint256 amountOut = router.exactInputSingle(swapParams);

        emit UniswapFacetTokensSwapped(params.tokenIn, params.tokenOut, params.amountIn, amountOut);
    }

    /// @inheritdoc IUniswap
    function swapExactInputMultiHop(UniswapMultiHopSwapParams calldata params) external override {
        ISwapRouter router = ISwapRouter(params.routerAddress);

        if (params.pathWithFees.length < 2) revert UniswapFacet_InvalidPath();
        if (block.timestamp > params.deadline) revert UniswapFacet_SwapDeadlineHasPassed();
        if (params.amountIn == 0) revert UniswapFacet_InvalidAmount();

        IERC20 tokenA = IERC20(params.pathWithFees[0].token);

        // handle allowance pattern
        uint256 currentAllowance = tokenA.allowance(address(this), params.routerAddress);
        if (currentAllowance > 0) {
            if (!tokenA.approve(address(router), 0)) revert UniswapFacet_ApprovalFailed();
        }
        if (!tokenA.approve(address(router), params.amountIn)) revert UniswapFacet_ApprovalFailed();

        address liquidityPoolRegistry = LibDiamond.liquidityPoolRegistry();

        // validate all pools in the multi-hop path are registered
        _checkPoolsRegistered(params, liquidityPoolRegistry);

        // encode path (token, fee, token, fee, token, ...)
        bytes memory path = _encodePath(params);

        // build swap params and execute
        ISwapRouter.ExactInputParams memory swapParams = ISwapRouter.ExactInputParams({
            path: path,
            recipient: address(this),
            deadline: params.deadline,
            amountIn: params.amountIn,
            amountOutMinimum: params.amountOutMin
        });

        // execute the swap
        uint256 amountOut = router.exactInput(swapParams);
        emit UniswapFacetTokensSwapped(
            params.pathWithFees[0].token,
            params.pathWithFees[params.pathWithFees.length - 1].token,
            params.amountIn,
            amountOut
        );
    }

    /// @inheritdoc IUniswap
    function getSqrtTwapX96(UniswapSingleHopTwapParams memory params)
        external
        view
        returns (uint160 sqrtPriceX96, uint256 deadline)
    {
        if (params.twapInterval == 0) {
            // use the instantaneous slot0 sqrt price
            (sqrtPriceX96,,,,,,) = IUniswapV3Pool(params.uniswapV3Pool).slot0();
            deadline = block.timestamp + 300;
        } else {
            uint32[] memory secondsAgo = new uint32[](2);
            secondsAgo[0] = params.twapInterval;
            secondsAgo[1] = 0;
            // Observe two cumulative ticks and compute average tick over interval
            (int56[] memory tickCumulative,) = IUniswapV3Pool(params.uniswapV3Pool).observe(secondsAgo);

            // average tick = (tickCumulative[1] - tickCumulative[0]) / interval
            int24 avgTick = int24(int56(tickCumulative[1] - tickCumulative[0]) / int56(int32(params.twapInterval)));

            sqrtPriceX96 = TickMath.getSqrtRatioAtTick(avgTick);
            deadline = block.timestamp + 300;
        }
    }

    /// @inheritdoc IUniswap
    function getCombinedTwapX96(UniswapMultiHopTwapParams memory params)
        external
        view
        returns (uint256 combinedPriceX96, uint256 deadline)
    {
        if (params.pools.length < 2) {
            revert UniswapFacet_PathMustHaveAtLeastTwoPools();
        }

        combinedPriceX96 = _calculateCombinedPrice(params);
        deadline = block.timestamp + 300;
    }

    function _checkPoolsRegistered(
        UniswapMultiHopSwapParams calldata params,
        address liquidityPoolRegistry
    )
        internal
        view
    {
        for (uint256 i = 1; i < params.pathWithFees.length; ++i) {
            address tokenPrev = params.pathWithFees[i - 1].token;
            address tokenCurr = params.pathWithFees[i].token;
            uint24 fee = params.pathWithFees[i].fee;
            // get pool address from factory
            address pool = IUniswapV3Factory(UNISWAP_FACTORY_ADDRESS).getPool(tokenPrev, tokenCurr, fee);
            // check pool exists and is registered
            if (pool == address(0) || !IPoolRegistry(liquidityPoolRegistry).isPoolRegistered(pool)) {
                revert UniswapFacet_UnregisteredPool();
            }
        }
    }

    function _encodePath(UniswapMultiHopSwapParams calldata params) internal pure returns (bytes memory path) {
        path = abi.encodePacked(params.pathWithFees[0].token);
        for (uint256 i = 1; i < params.pathWithFees.length; ++i) {
            path = abi.encodePacked(path, params.pathWithFees[i - 1].fee, params.pathWithFees[i].token);
        }
    }

    function _calculateCombinedPrice(UniswapMultiHopTwapParams memory params)
        internal
        view
        returns (uint256 combinedPriceX96)
    {
        // start with 2**96 to preserve Q96 fixed-point scaling
        combinedPriceX96 = _pow(2, 96, 1);

        for (uint256 i = 0; i < params.pools.length; i++) {
            uint160 sqrtPriceX96;
            address pool = params.pools[i].pool;
            bool inverse = params.pools[i].inverse;

            if (params.twapInterval == 0) {
                // use the instantaneous slot0 sqrt price
                (sqrtPriceX96,,,,,,) = IUniswapV3Pool(pool).slot0();
            } else {
                uint32[] memory secondsAgo = new uint32[](2);
                secondsAgo[0] = params.twapInterval;
                secondsAgo[1] = 0;
                // Observe two cumulative ticks and compute average tick over interval
                (int56[] memory tickCumulative,) = IUniswapV3Pool(pool).observe(secondsAgo);
                int24 avgTick = int24((tickCumulative[1] - tickCumulative[0]) / int56(int32(params.twapInterval)));
                sqrtPriceX96 = TickMath.getSqrtRatioAtTick(avgTick);
            }

            // if inverse, use reciprocal of the sqrt price (scaled)
            if (inverse) {
                sqrtPriceX96 = uint160(2 ** 192 / uint256(sqrtPriceX96));
            }

            // multiply and normalize back to Q96
            combinedPriceX96 = (uint256(combinedPriceX96) * uint256(sqrtPriceX96)) / _pow(2, 96, 1);
        }
    }

    /**
     * @notice Internal integer power with rounding and overflow guards implemented in assembly.
     * @dev This helper is used for fixed-point normalization. Interface preserved from original.
     * @param x Base.
     * @param n Exponent.
     * @param b Base scaling (used for fixed-point rounding).
     * @return z Result of x**n in scaled representation.
     */
    function _pow(uint256 x, uint256 n, uint256 b) internal pure returns (uint256 z) {
        assembly {
            switch x
            case 0 {
                switch n
                case 0 { z := b }
                // 0**0 = 1 in this context
                default { z := 0 }
            }
            default {
                switch mod(n, 2)
                case 0 { z := b }
                default { z := x }
                let half := div(b, 2)
                for { n := div(n, 2) } n { n := div(n, 2) } {
                    let xx := mul(x, x)
                    if iszero(eq(div(xx, x), x)) { revert(0, 0) }
                    let xxRound := add(xx, half)
                    if lt(xxRound, xx) { revert(0, 0) }
                    x := div(xxRound, b)
                    if mod(n, 2) {
                        let zx := mul(z, x)
                        if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0, 0) }
                        let zxRound := add(zx, half)
                        if lt(zxRound, zx) { revert(0, 0) }
                        z := div(zxRound, b)
                    }
                }
            }
        }
    }
}
