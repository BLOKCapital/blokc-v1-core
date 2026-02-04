// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*###############################################################################

    @title CamelotV2Base
    @author BLOK Capital DAO
    @notice Base contract for Camelot V2 integration (swaps)
    @dev This contract provides the base functionality for Camelot V2 integration

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

/// @notice Camelot V2 facet insufficient amount out error
error CamelotV2Facet_InsufficientAmountOut();
/// @notice Camelot V2 facet get pair failed error
error CamelotV2Facet_GetPairFailed();
/// @notice Camelot V2 facet invalid pool address error
error CamelotV2Facet_InvalidPoolAddress();
/// @notice Camelot V2 facet unregistered pool error
error CamelotV2Facet_UnregisteredPool();

abstract contract CamelotV2Base {
    using SafeERC20 for IERC20;
    //Arbitrum One
    address internal constant CAMELOT_V2_ROUTER_ADDRESS = 0xc873fEcbd354f5A56E00E710B90EF4201db2448d;
    address internal constant CAMELOT_V2_FACTORY_ADDRESS = 0x6EcCab422D763aC031210895C81787E87B43A652;
    address internal constant POOL_REGISTRY_ADDRESS = 0xBa7898DbE9C2be340197e1fffe85FC5a3B977744;

    /// @notice Camelot V2 facet tokens swapped event
    /// @param tokenIn The input token
    /// @param tokenOut The output token
    /// @param amountIn The amount of input tokens swapped
    /// @param amountOut The amount of output tokens received
    event CamelotV2FacetTokensSwapped(
        address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
    );

    /// @notice Camelot V2 base exact input single swap
    /// @param amountIn The amount of input tokens to swap
    /// @param amountOutMin The minimum amount of output tokens to receive
    /// @param path The path of tokens to swap
    /// @param to The address to receive the output tokens
    /// @param referrer The address of the referrer
    /// @param deadline The deadline for the swap
    function _camelotV2ExactInputSingle(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
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
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, amountOutMin, path, to, referrer, deadline);

        // Get the amount of output tokens received
        uint256 amountOut = IERC20(path[path.length - 1]).balanceOf(address(this));

        // Validate the amount of output tokens received
        if (amountOut < amountOutMin) {
            revert CamelotV2Facet_InsufficientAmountOut();
        }

        // Emit the tokens swapped event
        emit CamelotV2FacetTokensSwapped(path[0], path[path.length - 1], amountIn, amountOut);
    }

    /// @notice Camelot V2 base exact input swap
    /// @param amountInMax The maximum amount of input tokens to swap
    /// @param amountOutMin The minimum amount of output tokens to receive
    /// @param path The path of tokens to swap
    /// @param to The address to receive the output tokens
    /// @param referrer The address of the referrer
    /// @param deadline The deadline for the swap
    function _camelotV2ExactInput(
        uint256 amountInMax,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
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
            .swapExactETHForTokensSupportingFeeOnTransferTokens(amountOutMin, path, to, referrer, deadline);

        // Get the amount of output tokens received
        uint256 amountOut = IERC20(path[path.length - 1]).balanceOf(address(this));

        // Validate the amount of output tokens received

        if (amountOut < amountOutMin) {
            revert CamelotV2Facet_InsufficientAmountOut();
        }

        // Emit the tokens swapped event
        emit CamelotV2FacetTokensSwapped(path[0], path[path.length - 1], amountInMax, amountOut);
    }

    /// @notice Camelot V2 base exact output single swap
    /// @param amountIn The amount of input tokens to swap
    /// @param amountOutMin The minimum amount of output tokens to receive
    /// @param path The path of tokens to swap
    /// @param to The address to receive the input tokens
    /// @param referrer The address of the referrer
    /// @param deadline The deadline for the swap
    function _camelotV2ExactOutputSingle(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
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
            .swapExactTokensForETHSupportingFeeOnTransferTokens(amountIn, amountOutMin, path, to, referrer, deadline);

        // Get the amount of output tokens received
        uint256 amountOut = address(this).balance;

        // Validate the amount of output tokens received

        if (amountOut < amountOutMin) {
            revert CamelotV2Facet_InsufficientAmountOut();
        }

        // Emit the tokens swapped event
        emit CamelotV2FacetTokensSwapped(path[0], path[path.length - 1], amountIn, amountOut);
    }

    /// @notice Camelot V2 base validate pools
    /// @param path The path of tokens to swap
    /// @dev This function validates the pools for the given path
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
