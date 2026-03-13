// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { ICamelotV2 } from "src/garden/facets/utilityFacets/arbitrumOne/camelotV2/ICamelotV2.sol";
import { ICamelotRouterV2 } from "src/interfaces/ICamelotRouterV2.sol";
import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ICamelotV2PairLike {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

/// @notice Thrown when the swap output amount is below the minimum acceptable threshold
error CamelotV2Facet_InsufficientAmountOut();

/// @notice Thrown when the factory getPair call fails
error CamelotV2Facet_GetPairFailed();

/// @notice Thrown when the resolved pool address is the zero address
error CamelotV2Facet_InvalidPoolAddress();

/// @notice Thrown when a pool along the swap path is not registered in the pool registry
error CamelotV2Facet_UnregisteredPool();

/**
 * @title CamelotV2Base
 * @notice Base contract that implements internal functions for swapping tokens through Camelot V2 on Arbitrum One. This
 * contract is intended to be inherited by a CamelotV2Facet that exposes the swap functions with appropriate access
 * control and user-facing error messages. It includes functions to perform single-hop and multi-hop exact-input and
 * exact-output swaps, along with events for off-chain tracking of swap operations.
 */
abstract contract CamelotV2Base {
    using SafeERC20 for IERC20;

    /// @notice Camelot V2 router address on Arbitrum One
    address internal constant CAMELOT_V2_ROUTER_ADDRESS = 0xc873fEcbd354f5A56E00E710B90EF4201db2448d;

    /// @notice Camelot V2 factory address on Arbitrum One
    address internal constant CAMELOT_V2_FACTORY_ADDRESS = 0x6EcCab422D763aC031210895C81787E87B43A652;

    /// @notice Liquidity pool registry address on Arbitrum One
    address internal constant POOL_REGISTRY_ADDRESS = 0xeADe4091f50B1fd0b6315c9028543f5177E59a56;

    /// @notice Emitted when a Camelot V2 swap is successfully executed
    /// @param tokenIn The input token address
    /// @param tokenOut The output token address
    /// @param amountIn The amount of input tokens swapped
    /// @param amountOut The amount of output tokens received
    event CamelotV2FacetTokensSwapped(
        address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
    );

    /// @notice Executes a Camelot V2 exact input single-hop swap
    /// @param amountIn The amount of input tokens to swap
    /// @param amountOutMin The minimum amount of output tokens to receive
    /// @param path The path of tokens to swap
    /// @param referrer The address of the referrer
    /// @param deadline The deadline for the swap
    function _camelotV2ExactInputSingle(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address referrer,
        uint256 deadline
    )
        internal
    {
        // Validate the pools for the given path
        _validatePools(path);

        // Approve the input tokens for the swap
        IERC20 tokenIn = IERC20(path[0]);
        tokenIn.forceApprove(CAMELOT_V2_ROUTER_ADDRESS, amountIn);

        // Execute the swap
        ICamelotRouterV2(CAMELOT_V2_ROUTER_ADDRESS)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                amountIn, amountOutMin, path, address(this), referrer, deadline
            );

        // Get the amount of output tokens received
        uint256 amountOut = IERC20(path[path.length - 1]).balanceOf(address(this));

        // Validate the amount of output tokens received
        if (amountOut < amountOutMin) {
            revert CamelotV2Facet_InsufficientAmountOut();
        }

        // Emit the tokens swapped event
        emit CamelotV2FacetTokensSwapped(path[0], path[path.length - 1], amountIn, amountOut);
    }

    /// @notice Executes a Camelot V2 exact input multi-hop swap
    /// @param amountInMax The maximum amount of input tokens to swap
    /// @param amountOutMin The minimum amount of output tokens to receive
    /// @param path The path of tokens to swap
    /// @param referrer The address of the referrer
    /// @param deadline The deadline for the swap
    function _camelotV2ExactInput(
        uint256 amountInMax,
        uint256 amountOutMin,
        address[] calldata path,
        address referrer,
        uint256 deadline
    )
        internal
    {
        // Validate the pools for the given path
        _validatePools(path);

        // Approve the input tokens for the swap
        IERC20 tokenIn = IERC20(path[0]);
        tokenIn.forceApprove(CAMELOT_V2_ROUTER_ADDRESS, amountInMax);

        // Execute the swap
        ICamelotRouterV2(CAMELOT_V2_ROUTER_ADDRESS)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                amountInMax, amountOutMin, path, address(this), referrer, deadline
            );

        // Get the amount of output tokens received
        uint256 amountOut = IERC20(path[path.length - 1]).balanceOf(address(this));

        // Validate the amount of output tokens received

        if (amountOut < amountOutMin) {
            revert CamelotV2Facet_InsufficientAmountOut();
        }

        // Emit the tokens swapped event
        emit CamelotV2FacetTokensSwapped(path[0], path[path.length - 1], amountInMax, amountOut);
    }

    /// @notice Executes a Camelot V2 exact output single-hop swap to ETH
    /// @param amountIn The amount of input tokens to swap
    /// @param amountOutMin The minimum amount of output tokens to receive
    /// @param path The path of tokens to swap
    /// @param referrer The address of the referrer
    /// @param deadline The deadline for the swap
    function _camelotV2ExactOutputSingle(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address referrer,
        uint256 deadline
    )
        internal
    {
        _validatePools(path);

        // Approve the input tokens for the swap
        IERC20 tokenIn = IERC20(path[0]);
        tokenIn.forceApprove(CAMELOT_V2_ROUTER_ADDRESS, amountIn);

        // Execute the swap
        ICamelotRouterV2(CAMELOT_V2_ROUTER_ADDRESS)
            .swapExactTokensForETHSupportingFeeOnTransferTokens(
                amountIn, amountOutMin, path, address(this), referrer, deadline
            );

        // Get the amount of output tokens received
        uint256 amountOut = address(this).balance;

        // Validate the amount of output tokens received

        if (amountOut < amountOutMin) {
            revert CamelotV2Facet_InsufficientAmountOut();
        }

        // Emit the tokens swapped event
        emit CamelotV2FacetTokensSwapped(path[0], path[path.length - 1], amountIn, amountOut);
    }

    /// @notice Quotes output amount for exact input on a specific Camelot V2 pool (must be registered)
    function _camelotV2QuoteExactInputForPool(
        address poolAddress,
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    )
        internal
        view
        returns (uint256 amountOut)
    {
        if (poolAddress == address(0)) revert CamelotV2Facet_InvalidPoolAddress();
        if (!ILiquidityPoolRegistry(POOL_REGISTRY_ADDRESS).isPoolRegistered(poolAddress)) {
            revert CamelotV2Facet_UnregisteredPool();
        }

        (uint112 reserve0, uint112 reserve1,) = ICamelotV2PairLike(poolAddress).getReserves();
        address token0 = ICamelotV2PairLike(poolAddress).token0();
        address token1 = ICamelotV2PairLike(poolAddress).token1();

        uint256 reserveIn;
        uint256 reserveOut;
        if (tokenIn == token0 && tokenOut == token1) {
            reserveIn = uint256(reserve0);
            reserveOut = uint256(reserve1);
        } else if (tokenIn == token1 && tokenOut == token0) {
            reserveIn = uint256(reserve1);
            reserveOut = uint256(reserve0);
        } else {
            revert CamelotV2Facet_InvalidPoolAddress();
        }

        // Camelot V2 uses same constant-product formula as Uniswap V2 (0.3% fee)
        require(amountIn > 0, "CamelotV2: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "CamelotV2: INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        return numerator / denominator;
    }

    /// @notice Validates that all pools along the swap path exist and are registered
    /// @param path The array of token addresses forming the swap path
    function _validatePools(address[] calldata path) internal view {
        for (uint256 i = 0; i < path.length - 1; i++) {
            (bool ok, bytes memory data) = CAMELOT_V2_FACTORY_ADDRESS.staticcall(
                abi.encodeWithSignature("getPair(address,address)", path[i], path[i + 1])
            );

            if (!ok) {
                revert CamelotV2Facet_GetPairFailed();
            }

            address pool = abi.decode(data, (address));

            if (pool == address(0)) {
                revert CamelotV2Facet_InvalidPoolAddress();
            }

            if (!ILiquidityPoolRegistry(POOL_REGISTRY_ADDRESS).isPoolRegistered(pool)) {
                revert CamelotV2Facet_UnregisteredPool();
            }
        }
    }
}
