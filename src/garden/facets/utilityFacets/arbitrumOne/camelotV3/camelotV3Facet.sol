// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { CamelotV3Base } from "src/garden/facets/utilityFacets/arbitrumOne/camelotV3/camelotV3Base.sol";
import { ICamelotV3 } from "src/garden/facets/utilityFacets/arbitrumOne/camelotV3/ICamelotV3.sol";
import { Facet } from "src/garden/facets/Facet.sol";

/**
 * @title CamelotV3Facet
 * @author BLOK Capital DAO
 * @notice Facet that implements the ICamelotV3 interface to allow swapping tokens through Camelot V3 on Arbitrum One.
 * This facet provides external functions for garden owners to perform token swaps using Camelot V3, with appropriate
 * access control and user-facing error messages. It inherits from CamelotV3Base which contains the internal logic for
 * interacting with Camelot V3, while CamelotV3Facet itself provides the external interface for these operations.
 */
contract CamelotV3Facet is ICamelotV3, CamelotV3Base, Facet {
    /// @inheritdoc ICamelotV3
    function camelotV3ExactInputSingle(CamelotV3ExactInputSingleParams memory params)
        external
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
        returns (uint256 amountOut)
    {
        _camelotV3ExactInputSingle(params);
    }

    /// @inheritdoc ICamelotV3
    function camelotV3ExactInput(CamelotV3ExactInputParams memory params)
        external
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
        returns (uint256 amountOut)
    {
        _camelotV3ExactInput(params);
    }

    /// @inheritdoc ICamelotV3
    function camelotV3ExactOutputSingle(CamelotV3ExactOutputSingleParams memory params)
        external
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
        returns (uint256 amountIn)
    {
        _camelotV3ExactOutputSingle(params);
    }

    /// @inheritdoc ICamelotV3
    function camelotV3ExactOutput(CamelotV3ExactOutputParams memory params)
        external
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
        returns (uint256 amountIn)
    {
        _camelotV3ExactOutput(params);
    }

    /// @inheritdoc ICamelotV3
    function camelotV3GetSqrtTwapX96(address poolAddress, uint32 twapInterval)
        external
        view
        returns (uint160 sqrtPriceX96, uint256 deadline)
    {
        return _camelotV3GetSqrtTwapX96(poolAddress, twapInterval);
    }

    /// @inheritdoc ICamelotV3
    function camelotV3QuoteExactInputForPool(
        address poolAddress,
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        uint32 twapInterval
    )
        external
        view
        returns (uint256 amountOut)
    {
        return _camelotV3QuoteExactInputForPool(poolAddress, amountIn, tokenIn, tokenOut, twapInterval);
    }
}
