//SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    @title CamelotV3Base
    @author BLOK Capital DAO
    @notice Base contract for Camelot V3 integration (swaps)
    @dev This contract provides the base functionality for Camelot V3 integration (swaps)

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

/// @notice Camelot V3 facet invalid pool address error
error CamelotV3Facet_InvalidPoolAddress();

/// @notice Camelot V3 facet invalid pool error
error CamelotV3Facet_InvalidPool();

/// @notice Camelot V3 facet unregistered pool error
error CamelotV3Facet_UnregisteredPool();

abstract contract CamelotV3Base {
    using SafeERC20 for IERC20;
    address internal constant CAMELOT_V3_ROUTER_ADDRESS = 0x1F721E2E82F6676FCE4eA07A5958cF098D339e18;
    address internal constant CAMELOT_V3_FACTORY_ADDRESS = 0x1a3c9B1d2F0529D97f2afC5136Cc23e58f1FD35B;
    address internal constant POOL_REGISTRY_ADDRESS = 0xBa7898DbE9C2be340197e1fffe85FC5a3B977744;

    /// @notice Camelot V3 facet tokens swapped event
    /// @param tokenIn The input token
    /// @param tokenOut The output token
    /// @param amountIn The amount of input tokens swapped
    /// @param amountOut The amount of output tokens received
    event CamelotV3FacetTokensSwapped(
        address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
    );

    /// @notice Camelot V3 base exact input single swap
    /// @param params Single-hop swap parameters including tokens, amounts, and deadline
    /// @dev Validates pool registration, handles token approvals, and executes swap.
    ///      Uses SafeERC20 for secure token operations.
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

    /// @notice Camelot V3 base exact input swap
    /// @param params Multi-hop swap parameters including path, amounts, and deadline
    /// @dev Validates all pools in the path are registered, handles approvals,
    ///      encodes the path, and executes the swap.
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

    /// @notice Camelot V3 base exact output single swap
    /// @param params Single-hop swap parameters including tokens, amounts, and deadline
    /// @dev Validates pool registration, handles token approvals, and executes swap.
    ///      Uses SafeERC20 for secure token operations.
    function _camelotV3ExactOutputSingle(ICamelotV3.CamelotV3ExactOutputSingleParams memory params) internal {
        ICamelotRouterV3 router = ICamelotRouterV3(CAMELOT_V3_ROUTER_ADDRESS);
        IERC20 tokenOut = IERC20(params.tokenOut);

        // Validate pool registration
        _validatePool(params.tokenIn, params.tokenOut);

        // Approve the output tokens for the swap
        tokenOut.forceApprove(CAMELOT_V3_ROUTER_ADDRESS, params.amountOut);

        // Build swap parameters
        ICamelotRouterV3.ExactOutputSingleParams memory swapParams = ICamelotRouterV3.ExactOutputSingleParams({
            tokenIn: params.tokenIn,
            tokenOut: params.tokenOut,
            recipient: address(this),
            deadline: params.deadline,
            amountOut: params.amountOut,
            amountInMaximum: params.amountInMaximum,
            limitSqrtPrice: params.limitSqrtPrice
        });

        // Execute the swap
        uint256 amountIn = router.exactOutputSingle(swapParams);

        // Emit the tokens swapped event
        emit CamelotV3FacetTokensSwapped(params.tokenIn, params.tokenOut, amountIn, params.amountOut);
    }

    /// @notice Camelot V3 base exact output swap
    /// @param params Multi-hop swap parameters including path, amounts, and deadline
    /// @dev Validates all pools in the path are registered, handles approvals,
    ///      encodes the path, and executes the swap.
    function _camelotV3ExactOutput(ICamelotV3.CamelotV3ExactOutputParams memory params) internal {
        ICamelotRouterV3 router = ICamelotRouterV3(CAMELOT_V3_ROUTER_ADDRESS);
        IERC20 tokenOut = IERC20(params.path[params.path.length - 1]);

        // Validate all pools in the multi-hop path are registered
        _validateMultiHopPools(params.path);

        // Approve the output tokens for the swap
        tokenOut.forceApprove(CAMELOT_V3_ROUTER_ADDRESS, params.amountOut);

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
        emit CamelotV3FacetTokensSwapped(
            params.path[0], params.path[params.path.length - 1], amountIn, params.amountOut
        );
    }

    /// @notice Validates that all pools in a multi-hop path exist and are registered
    /// @param path Array of addresses describing the path
    function _validateMultiHopPools(address[] memory path) internal view {
        for (uint256 i = 0; i < path.length - 1; i++) {
            _validatePool(path[i], path[i + 1]);
        }
    }

    /// @notice Validates a pool registration
    /// @dev Validates a pool registration by checking if the pool exists and is registered
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

    /// @notice Encodes a multi-hop path for Camelot V3 router
    /// @dev Encodes path as: token0, token1, token2, ...
    /// @param path Array of addresses describing the path
    /// @return encodedPath Encoded path bytes
    function _encodePath(address[] memory path) internal pure returns (bytes memory encodedPath) {
        encodedPath = abi.encodePacked(path[0]);
        for (uint256 i = 1; i < path.length; ++i) {
            encodedPath = abi.encodePacked(encodedPath, path[i]);
        }
    }
}
