// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

// OpenZeppelin Contracts
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Uniswap V3 Contracts
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

// Local Interfaces
import { IUniswapV3 } from "src/garden/facets/utilityFacets/ethereum/uniswapV3/IUniswapV3.sol";
import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";

// Local Libraries
import { TickMath } from "src/garden/libraries/TickMath.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when contract has insufficient token balance
error UniswapV3Facet_InsufficientBalance();

/// @notice Thrown when token approval fails
error UniswapV3Facet_ApprovalFailed();

/// @notice Thrown when pool is not registered in the LiquidityPoolRegistry
error UniswapV3Facet_UnregisteredPool();

/// @notice Thrown when swap deadline has already passed
error UniswapV3Facet_SwapDeadlineHasPassed();

/// @notice Thrown when swap path is invalid
error UniswapV3Facet_InvalidPath();

/// @notice Thrown when swap amount is zero
error UniswapV3Facet_InvalidAmount();

/// @notice Thrown when multi-hop path has fewer than two pools
error UniswapV3Facet_PathMustHaveAtLeastTwoPools();

/// @notice Thrown when router address is zero
error UniswapV3Facet_InvalidRouterAddress();

/// @notice Thrown when token address is zero
error UniswapV3Facet_InvalidTokenAddress();

/// @notice Thrown when pool address is zero
error UniswapV3Facet_InvalidPoolAddress();

/**
 * @title UniswapV3Base
 * @notice Base contract for Uniswap V3 interactions on Arbitrum One, providing shared logic for swaps and price
 * queries. This abstract contract is inherited by UniswapV3Facet which implements the external functions. It includes
 * internal functions for executing exact input/output swaps (single and multi-hop) and fetching TWAP prices. The
 * contract also validates pool registrations and handles token approvals securely using SafeERC20.
 */
abstract contract UniswapV3Base {
    using SafeERC20 for IERC20;

    // ========================================================================
    // Constants
    // ========================================================================

    /// @notice Uniswap V3 Router address on Ethereum Mainnet
    address internal constant UNISWAP_V3_ROUTER_ADDRESS = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    /// @notice Pool Registry address on Ethereum Mainnet
    address internal constant POOL_REGISTRY_ADDRESS = 0xDe6338E4dd7B0A2076e8CE63cC0443dC6cE7f0B6;
    /// @notice Uniswap V3 Factory address on Ethereum Mainnet
    address internal constant UNISWAP_FACTORY_ADDRESS = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    // ========================================================================
    // Events
    // ========================================================================

    /// @notice Emitted when tokens are swapped on Uniswap
    /// @param tokenIn The input token address
    /// @param tokenOut The output token address
    /// @param amountIn The input amount
    /// @param amountOut The output amount received
    event UniswapV3FacetTokensSwapped(
        address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
    );

    /// @notice Uniswap V3 base exact input single swap
    /// @param params Single-hop swap parameters including tokens, amounts, fees, and deadline
    /// @dev Validates pool registration, handles token approvals, and executes swap.
    ///      Uses SafeERC20 for secure token operations.
    function _uniswapV3ExactInputSingle(IUniswapV3.UniswapV3ExactInputSingleParams memory params)
        internal
        returns (uint256 amountOut)
    {
        ISwapRouter router = ISwapRouter(UNISWAP_V3_ROUTER_ADDRESS);
        IERC20 tokenIn = IERC20(params.tokenIn);

        _validatePool(params.tokenIn, params.tokenOut, params.swapFee);

        // Approve the input tokens for the swap
        tokenIn.forceApprove(UNISWAP_V3_ROUTER_ADDRESS, params.amountIn);

        // Build swap parameters
        ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter.ExactInputSingleParams({
            tokenIn: params.tokenIn,
            tokenOut: params.tokenOut,
            recipient: address(this),
            deadline: params.deadline,
            amountIn: params.amountIn,
            amountOutMinimum: params.amountOutMinimum,
            sqrtPriceLimitX96: 0,
            fee: params.swapFee
        });

        // Execute the swap
        amountOut = router.exactInputSingle(swapParams);

        // Emit the tokens swapped event
        emit UniswapV3FacetTokensSwapped(params.tokenIn, params.tokenOut, params.amountIn, amountOut);
    }

    /// @notice Uniswap V3 base exact input swap
    /// @param params Multi-hop swap parameters including path, amounts, and deadline
    /// @dev Validates all pools in the path are registered, handles approvals,
    ///      encodes the path, and executes the swap.
    function _uniswapV3ExactInput(IUniswapV3.UniswapV3ExactInputParams memory params) internal {
        if (params.pathWithFees.length < 2) {
            revert UniswapV3Facet_InvalidPath();
        }

        ISwapRouter router = ISwapRouter(UNISWAP_V3_ROUTER_ADDRESS);
        IERC20 tokenIn = IERC20(params.pathWithFees[0].token);
        address tokenOut = params.pathWithFees[params.pathWithFees.length - 1].token;

        // Validate all pools in the multi-hop path are registered
        _validateMultiHopPools(params.pathWithFees);

        // Approve the input tokens for the swap
        tokenIn.forceApprove(UNISWAP_V3_ROUTER_ADDRESS, params.amountIn);

        // Encode path (token, fee, token, fee, token, ...)
        bytes memory path = _encodePath(params.pathWithFees);
        ISwapRouter.ExactInputParams memory swapParams = ISwapRouter.ExactInputParams({
            path: path,
            recipient: address(this),
            deadline: params.deadline,
            amountIn: params.amountIn,
            amountOutMinimum: params.amountOutMin
        });

        // Execute the swap
        uint256 amountOut = router.exactInput(swapParams);

        // Emit the tokens swapped event
        emit UniswapV3FacetTokensSwapped(address(tokenIn), tokenOut, params.amountIn, amountOut);
    }

    /// @notice Uniswap V3 base exact output single swap
    /// @param params Single-hop swap parameters including tokens, amounts, fees, and deadline
    /// @dev Validates pool registration, handles token approvals, and executes swap.
    ///      Uses SafeERC20 for secure token operations.
    function _uniswapV3ExactOutputSingle(IUniswapV3.UniswapV3ExactOutputSingleParams memory params) internal {
        ISwapRouter router = ISwapRouter(UNISWAP_V3_ROUTER_ADDRESS);

        IERC20 tokenIn = IERC20(params.tokenIn);
        address tokenOut = params.tokenOut;

        _validatePool(address(tokenIn), tokenOut, params.swapFee);

        // Approve the input tokens for the swap
        tokenIn.forceApprove(UNISWAP_V3_ROUTER_ADDRESS, params.amountInMaximum);

        // Build swap parameters
        ISwapRouter.ExactOutputSingleParams memory swapParams = ISwapRouter.ExactOutputSingleParams({
            tokenIn: address(tokenIn),
            tokenOut: tokenOut,
            fee: params.swapFee,
            recipient: address(this),
            deadline: params.deadline,
            amountOut: params.amountOut,
            amountInMaximum: params.amountInMaximum,
            sqrtPriceLimitX96: 0
        });

        // Execute the swap
        uint256 amountIn = router.exactOutputSingle(swapParams);

        // Emit the tokens swapped event
        emit UniswapV3FacetTokensSwapped(address(tokenIn), tokenOut, amountIn, params.amountOut);
    }

    /// @notice Uniswap V3 base exact output swap
    /// @param params Multi-hop swap parameters including path, amounts, and deadline
    /// @dev Validates all pools in the path are registered, handles approvals,
    ///      encodes the path, and executes the swap.
    function _uniswapV3ExactOutput(IUniswapV3.UniswapV3ExactOutputParams memory params) internal {
        if (params.pathWithFees.length < 2) {
            revert UniswapV3Facet_InvalidPath();
        }
        if (block.timestamp > params.deadline) {
            revert UniswapV3Facet_SwapDeadlineHasPassed();
        }
        ISwapRouter router = ISwapRouter(UNISWAP_V3_ROUTER_ADDRESS);
        IERC20 tokenIn = IERC20(params.pathWithFees[0].token);

        // Validate all pools in the multi-hop path are registered
        _validateMultiHopPools(params.pathWithFees);

        tokenIn.forceApprove(UNISWAP_V3_ROUTER_ADDRESS, params.amountInMaximum);

        // Encode path (token, fee, token, fee, token, ...)
        bytes memory path = _encodePath(params.pathWithFees);
        ISwapRouter.ExactOutputParams memory swapParams = ISwapRouter.ExactOutputParams({
            path: path,
            recipient: address(this),
            deadline: params.deadline,
            amountOut: params.amountOut,
            amountInMaximum: params.amountInMaximum
        });

        // Execute the swap
        uint256 amountIn = router.exactOutput(swapParams);

        // Emit the tokens swapped event
        emit UniswapV3FacetTokensSwapped(
            params.pathWithFees[0].token,
            params.pathWithFees[params.pathWithFees.length - 1].token,
            amountIn,
            params.amountOut
        );
    }

    /// @notice Quotes output amount for exact input on a specific Uniswap V3 pool
    function _uniswapV3QuoteExactInputForPool(
        address poolAddress,
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        uint32 twapInterval
    )
        internal
        view
        returns (uint256 amountOut)
    {
        if (poolAddress == address(0)) revert UniswapV3Facet_InvalidPoolAddress();
        if (!ILiquidityPoolRegistry(POOL_REGISTRY_ADDRESS).isPoolRegistered(poolAddress)) {
            revert UniswapV3Facet_UnregisteredPool();
        }

        (uint160 sqrtPriceX96,) = _getSqrtTwapX96(poolAddress, twapInterval);
        address token0 = IUniswapV3Pool(poolAddress).token0();
        address token1 = IUniswapV3Pool(poolAddress).token1();

        return _quoteExactInputFromSqrtPrice(sqrtPriceX96, amountIn, tokenIn, tokenOut, token0, token1);
    }

    /// @notice Converts sqrtPriceX96 to amountOut given token order
    function _quoteExactInputFromSqrtPrice(
        uint160 sqrtPriceX96,
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        address token0,
        address token1
    )
        internal
        pure
        returns (uint256 amountOut)
    {
        if (tokenIn == token0 && tokenOut == token1) {
            return _amountOutForZeroForOne(uint256(sqrtPriceX96), amountIn);
        }
        if (tokenIn == token1 && tokenOut == token0) {
            return _amountOutForOneForZero(uint256(sqrtPriceX96), amountIn);
        }
        revert UniswapV3Facet_InvalidPath();
    }

    function _amountOutForZeroForOne(uint256 sqrtPriceX96, uint256 amountIn) internal pure returns (uint256) {
        uint256 priceToken1PerToken0 = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) >> 192;
        return (amountIn * priceToken1PerToken0) >> 96;
    }

    function _amountOutForOneForZero(uint256 sqrtPriceX96, uint256 amountIn) internal pure returns (uint256) {
        uint256 priceToken1PerToken0 = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) >> 192;
        return amountIn / priceToken1PerToken0;
    }

    /// @notice Gets the TWAP sqrt price for a single Uniswap V3 pool
    /// @dev Returns either the current spot price (if twapInterval is 0) or the
    ///      TWAP price over the specified interval. Price is returned in Q64.96 format.
    /// @param uniswapV3Pool Address of the Uniswap V3 pool to query
    /// @param twapInterval TWAP observation interval in seconds (applies to all pools)
    /// @return sqrtPriceX96 The sqrt price in Q64.96 format
    /// @return deadline Suggested deadline for swaps using this price (now + 300s)
    function _getSqrtTwapX96(
        address uniswapV3Pool,
        uint32 twapInterval
    )
        internal
        view
        returns (uint160 sqrtPriceX96, uint256 deadline)
    {
        if (uniswapV3Pool == address(0)) {
            revert UniswapV3Facet_InvalidPoolAddress();
        }

        if (twapInterval == 0) {
            // Use the instantaneous slot0 sqrt price
            (sqrtPriceX96,,,,,,) = IUniswapV3Pool(uniswapV3Pool).slot0();
            deadline = block.timestamp + 300;
        } else {
            uint32[] memory secondsAgo = new uint32[](2);
            secondsAgo[0] = twapInterval;
            secondsAgo[1] = 0;

            // Observe two cumulative ticks and compute average tick over interval
            (int56[] memory tickCumulative,) = IUniswapV3Pool(uniswapV3Pool).observe(secondsAgo);

            // Average tick = (tickCumulative[1] - tickCumulative[0]) / interval
            int24 avgTick = int24(int56(tickCumulative[1] - tickCumulative[0]) / int56(int32(twapInterval)));

            sqrtPriceX96 = TickMath.getSqrtRatioAtTick(avgTick);
            deadline = block.timestamp + 300;
        }
    }

    /// @notice Gets a combined TWAP price across multiple Uniswap V3 pools
    /// @dev Multiplies prices from multiple pools together, with optional inversion.
    ///      Useful for calculating prices across complex paths (e.g., ETH -> USDC -> DAI).
    /// @param pools Array of PoolInfo describing which pools to combine
    /// @param twapInterval TWAP observation interval in seconds (applies to all pools)
    /// @return combinedPriceX96 The combined price in Q96 format
    /// @return deadline Suggested deadline for swaps using this price (now + 300s)
    function _getCombinedTwapX96(
        IUniswapV3.PoolInfo[] memory pools,
        uint32 twapInterval
    )
        internal
        view
        returns (uint256 combinedPriceX96, uint256 deadline)
    {
        if (pools.length < 2) {
            revert UniswapV3Facet_PathMustHaveAtLeastTwoPools();
        }

        combinedPriceX96 = _calculateCombinedPrice(pools, twapInterval);
        deadline = block.timestamp + 300;
    }

    /// @notice Validates a pool registration
    /// @dev Validates a pool registration by checking if the pool exists and is registered
    /// @param tokenIn The input token address
    /// @param tokenOut The output token address
    /// @param swapFee The fee tier of the pool
    function _validatePool(address tokenIn, address tokenOut, uint24 swapFee) internal view {
        address pool = IUniswapV3Factory(UNISWAP_FACTORY_ADDRESS).getPool(tokenIn, tokenOut, swapFee);

        if (pool == address(0) || !ILiquidityPoolRegistry(POOL_REGISTRY_ADDRESS).isPoolRegistered(pool)) {
            revert UniswapV3Facet_UnregisteredPool();
        }
    }

    /// @notice Validates that all pools in a multi-hop path exist and are registered
    /// @param pathWithFees Array of TokenWithFee describing the path
    function _validateMultiHopPools(IUniswapV3.TokenWithFee[] memory pathWithFees) internal view {
        for (uint256 i = 1; i < pathWithFees.length; ++i) {
            address tokenPrev = pathWithFees[i - 1].token;
            address tokenCurr = pathWithFees[i].token;
            uint24 fee = pathWithFees[i].fee;

            if (tokenCurr == address(0)) {
                revert UniswapV3Facet_InvalidTokenAddress();
            }

            _validatePool(tokenPrev, tokenCurr, fee);
        }
    }

    /// @notice Encodes a multi-hop path for Uniswap V3 router
    /// @dev Encodes path as: token0, fee0, token1, fee1, token2, ...
    /// @param pathWithFees Array of TokenWithFee describing the path
    /// @return path Encoded path bytes
    function _encodePath(IUniswapV3.TokenWithFee[] memory pathWithFees) internal pure returns (bytes memory path) {
        path = abi.encodePacked(pathWithFees[0].token);
        for (uint256 i = 1; i < pathWithFees.length; ++i) {
            path = abi.encodePacked(path, pathWithFees[i - 1].fee, pathWithFees[i].token);
        }
    }

    /// @notice Calculates combined TWAP price across multiple pools
    /// @dev Multiplies prices together, handling inversions. Uses Q96 fixed-point arithmetic.
    /// @param pools Array of PoolInfo describing which pools to combine
    /// @param twapInterval TWAP observation interval in seconds (applies to all pools)
    /// @return combinedPriceX96 Combined price in Q96 format
    function _calculateCombinedPrice(
        IUniswapV3.PoolInfo[] memory pools,
        uint32 twapInterval
    )
        internal
        view
        returns (uint256 combinedPriceX96)
    {
        // Start with 2**96 to preserve Q96 fixed-point scaling
        combinedPriceX96 = _pow(2, 96, 1);

        for (uint256 i = 0; i < pools.length; i++) {
            if (pools[i].pool == address(0)) {
                revert UniswapV3Facet_InvalidPoolAddress();
            }

            uint160 sqrtPriceX96;
            address pool = pools[i].pool;
            bool inverse = pools[i].inverse;

            if (twapInterval == 0) {
                // Use the instantaneous slot0 sqrt price
                (sqrtPriceX96,,,,,,) = IUniswapV3Pool(pool).slot0();
            } else {
                uint32[] memory secondsAgo = new uint32[](2);
                secondsAgo[0] = twapInterval;
                secondsAgo[1] = 0;

                // Observe two cumulative ticks and compute average tick over interval
                (int56[] memory tickCumulative,) = IUniswapV3Pool(pool).observe(secondsAgo);
                int24 avgTick = int24((tickCumulative[1] - tickCumulative[0]) / int56(int32(twapInterval)));
                sqrtPriceX96 = TickMath.getSqrtRatioAtTick(avgTick);
            }

            // If inverse, use reciprocal of the sqrt price (scaled)
            if (inverse) {
                sqrtPriceX96 = uint160(2 ** 192 / uint256(sqrtPriceX96));
            }

            // Multiply and normalize back to Q96
            combinedPriceX96 = (uint256(combinedPriceX96) * uint256(sqrtPriceX96)) / _pow(2, 96, 1);
        }
    }

    /// @notice Internal integer power function with rounding and overflow guards
    /// @dev This helper is used for fixed-point normalization in Q96 calculations.
    ///      Implemented in assembly for gas efficiency.
    /// @param x Base value
    /// @param n Exponent
    /// @param b Base scaling (used for fixed-point rounding)
    /// @return z Result of x**n in scaled representation
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
                    if iszero(eq(div(xx, x), x)) { revert(0, 0) } // Overflow check
                    let xxRound := add(xx, half)
                    if lt(xxRound, xx) { revert(0, 0) } // Overflow check
                    x := div(xxRound, b)
                    if mod(n, 2) {
                        let zx := mul(z, x)
                        if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0, 0) } // Overflow check
                        let zxRound := add(zx, half)
                        if lt(zxRound, zx) { revert(0, 0) } // Overflow check
                        z := div(zxRound, b)
                    }
                }
            }
        }
    }
}
