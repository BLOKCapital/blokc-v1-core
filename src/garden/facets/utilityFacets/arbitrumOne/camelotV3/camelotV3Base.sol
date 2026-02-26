// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { ICamelotRouterV3 } from "src/interfaces/ICamelotRouterV3.sol";
import { ICamelotV3 } from "src/garden/facets/utilityFacets/arbitrumOne/camelotV3/ICamelotV3.sol";
import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Thrown when the factory poolByPair call returns an invalid pool address
error CamelotV3Facet_InvalidPoolAddress();

/// @notice Thrown when the resolved pool address is the zero address
error CamelotV3Facet_InvalidPool();

/// @notice Thrown when a pool along the swap path is not registered in the pool registry
error CamelotV3Facet_UnregisteredPool();

/**
 * @title CamelotV3Base
 * @notice Base contract that implements internal functions for swapping tokens through Camelot V3 on Arbitrum One. This
 * contract is intended to be inherited by a CamelotV3Facet that exposes the swap functions with appropriate access
 * control and user-facing error messages. It includes functions to perform single-hop and multi-hop exact-input and
 * exact-output swaps, along with events for off-chain tracking of swap operations.
 */
abstract contract CamelotV3Base {
    using SafeERC20 for IERC20;

    /// @notice Camelot V3 router address on Arbitrum One
    address internal constant CAMELOT_V3_ROUTER_ADDRESS = 0x1F721E2E82F6676FCE4eA07A5958cF098D339e18;

    /// @notice Camelot V3 factory address on Arbitrum One
    address internal constant CAMELOT_V3_FACTORY_ADDRESS = 0x1a3c9B1d2F0529D97f2afC5136Cc23e58f1FD35B;

    /// @notice Liquidity pool registry address on Arbitrum One
    address internal constant POOL_REGISTRY_ADDRESS = 0x8f49107B2059e59fD93164C29c462f7EB4f310E4;

    /// @notice Emitted when a Camelot V3 swap is successfully executed
    /// @param tokenIn The input token address
    /// @param tokenOut The output token address
    /// @param amountIn The amount of input tokens swapped
    /// @param amountOut The amount of output tokens received
    event CamelotV3FacetTokensSwapped(
        address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
    );

    /// @notice Executes a single-hop exact-input swap on Camelot V3
    /// @param params Single-hop swap parameters including tokens, amounts, and deadline
    function _camelotV3ExactInputSingle(ICamelotV3.CamelotV3ExactInputSingleParams memory params) internal {
        ICamelotRouterV3 router = ICamelotRouterV3(CAMELOT_V3_ROUTER_ADDRESS);
        IERC20 tokenIn = IERC20(params.tokenIn);

        _validatePool(params.tokenIn, params.tokenOut);

        tokenIn.forceApprove(CAMELOT_V3_ROUTER_ADDRESS, params.amountIn);

        ICamelotRouterV3.ExactInputSingleParams memory swapParams = ICamelotRouterV3.ExactInputSingleParams({
            tokenIn: params.tokenIn,
            tokenOut: params.tokenOut,
            recipient: address(this),
            deadline: params.deadline,
            amountIn: params.amountIn,
            amountOutMinimum: params.amountOutMinimum,
            limitSqrtPrice: params.limitSqrtPrice
        });

        uint256 amountOut = router.exactInputSingle(swapParams);

        // Emit the tokens swapped event
        emit CamelotV3FacetTokensSwapped(params.tokenIn, params.tokenOut, params.amountIn, amountOut);
    }

    /// @notice Executes a multi-hop exact-input swap on Camelot V3
    /// @param params Multi-hop swap parameters including path, amounts, and deadline
    function _camelotV3ExactInput(ICamelotV3.CamelotV3ExactInputParams memory params) internal {
        ICamelotRouterV3 router = ICamelotRouterV3(CAMELOT_V3_ROUTER_ADDRESS);
        IERC20 tokenIn = IERC20(params.path[0]);

        // Validate all pools in the multi-hop path are registered
        _validateMultiHopPools(params.path);

        // Approve the input tokens for the swap
        tokenIn.forceApprove(CAMELOT_V3_ROUTER_ADDRESS, params.amountIn);

        // Encode path (token, token, token, ...)
        bytes memory encodedPath = _encodePath(params.path);

        ICamelotRouterV3.ExactInputParams memory swapParams = ICamelotRouterV3.ExactInputParams({
            path: encodedPath,
            recipient: address(this),
            deadline: params.deadline,
            amountIn: params.amountIn,
            amountOutMinimum: params.amountOutMinimum
        });

        // Execute the swap
        uint256 amountOut = router.exactInput(swapParams);

        // Emit the tokens swapped event
        emit CamelotV3FacetTokensSwapped(
            params.path[0], params.path[params.path.length - 1], params.amountIn, amountOut
        );
    }

    /// @notice Executes a single-hop exact-output swap on Camelot V3
    /// @param params Single-hop swap parameters including tokens, amounts, and deadline
    function _camelotV3ExactOutputSingle(ICamelotV3.CamelotV3ExactOutputSingleParams memory params) internal {
        ICamelotRouterV3 router = ICamelotRouterV3(CAMELOT_V3_ROUTER_ADDRESS);
        IERC20 tokenIn = IERC20(params.tokenIn);
        address tokenOut = params.tokenOut;

        // Validate pool registration
        _validatePool(address(tokenIn), tokenOut);

        // Approve the input tokens for the swap
        tokenIn.forceApprove(CAMELOT_V3_ROUTER_ADDRESS, params.amountInMaximum);

        // Build swap parameters
        ICamelotRouterV3.ExactOutputSingleParams memory swapParams = ICamelotRouterV3.ExactOutputSingleParams({
            tokenIn: address(tokenIn),
            tokenOut: tokenOut,
            recipient: address(this),
            deadline: params.deadline,
            amountOut: params.amountOut,
            amountInMaximum: params.amountInMaximum,
            limitSqrtPrice: params.limitSqrtPrice
        });

        // Execute the swap
        uint256 amountIn = router.exactOutputSingle(swapParams);

        // Emit the tokens swapped event
        emit CamelotV3FacetTokensSwapped(address(tokenIn), tokenOut, amountIn, params.amountOut);
    }

    /// @notice Executes a multi-hop exact-output swap on Camelot V3
    /// @param params Multi-hop swap parameters including path, amounts, and deadline
    function _camelotV3ExactOutput(ICamelotV3.CamelotV3ExactOutputParams memory params) internal {
        ICamelotRouterV3 router = ICamelotRouterV3(CAMELOT_V3_ROUTER_ADDRESS);
        IERC20 tokenIn = IERC20(params.path[0]);
        address tokenOut = params.path[params.path.length - 1];

        // Validate all pools in the multi-hop path are registered
        _validateMultiHopPools(params.path);

        // Approve the input tokens for the swap
        tokenIn.forceApprove(CAMELOT_V3_ROUTER_ADDRESS, params.amountInMaximum);

        // Encode path (token, token, token, ...)
        bytes memory encodedPath = _encodePath(params.path);

        // Build swap parameters
        ICamelotRouterV3.ExactOutputParams memory swapParams = ICamelotRouterV3.ExactOutputParams({
            path: encodedPath,
            recipient: address(this),
            deadline: params.deadline,
            amountOut: params.amountOut,
            amountInMaximum: params.amountInMaximum
        });

        // Execute the swap
        uint256 amountIn = router.exactOutput(swapParams);

        // Emit the tokens swapped event
        emit CamelotV3FacetTokensSwapped(address(tokenIn), tokenOut, amountIn, params.amountOut);
    }

    /// @notice Validates that all pools in a multi-hop path exist and are registered
    /// @param path Array of token addresses describing the swap path
    function _validateMultiHopPools(address[] memory path) internal view {
        for (uint256 i = 0; i < path.length - 1; i++) {
            _validatePool(path[i], path[i + 1]);
        }
    }

    /// @notice Validates that a pool exists and is registered in the pool registry
    /// @param tokenIn The input token address
    /// @param tokenOut The output token address
    function _validatePool(address tokenIn, address tokenOut) internal view {
        // Get pool address from factory
        (bool ok, bytes memory data) = CAMELOT_V3_FACTORY_ADDRESS.staticcall(
            abi.encodeWithSignature("poolByPair(address,address)", tokenIn, tokenOut)
        );

        if (!ok) {
            revert CamelotV3Facet_InvalidPoolAddress();
        }

        address pool = abi.decode(data, (address));

        if (pool == address(0)) {
            revert CamelotV3Facet_InvalidPool();
        }

        // Check if the pool is registered
        if (!ILiquidityPoolRegistry(POOL_REGISTRY_ADDRESS).isPoolRegistered(pool)) {
            revert CamelotV3Facet_UnregisteredPool();
        }
    }

    /// @notice Encodes a multi-hop path for the Camelot V3 router
    /// @param path Array of token addresses describing the swap path
    /// @return encodedPath ABI-packed encoded path bytes
    function _encodePath(address[] memory path) internal pure returns (bytes memory encodedPath) {
        encodedPath = abi.encodePacked(path[0]);
        for (uint256 i = 1; i < path.length; ++i) {
            encodedPath = abi.encodePacked(encodedPath, path[i]);
        }
    }
}
