//SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    @title CamelotV3Facet
    @author BLOK Capital DAO
    @notice Facet contract for Camelot V3 integration (swaps)
    @dev This contract provides the functionality for Camelot V3 integration (swaps)

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { CamelotV3Base } from "./camelotV3Base.sol";
import { ICamelotV3 } from "src/garden/facets/utilityFacets/arbitrumOne/camelotV3/ICamelotV3.sol";

contract CamelotV3Facet is ICamelotV3, CamelotV3Base {
    /// @inheritdoc ICamelotV3
    function camelotV3ExactInputSingle(CamelotV3ExactInputSingleParams memory params)
        external
        returns (uint256 amountOut)
    {
        _camelotV3ExactInputSingle(params);
    }

    /// @inheritdoc ICamelotV3
    function camelotV3ExactInput(CamelotV3ExactInputParams memory params) external returns (uint256 amountOut) {
        _camelotV3ExactInput(params);
    }

    /// @inheritdoc ICamelotV3
    function camelotV3ExactOutputSingle(CamelotV3ExactOutputSingleParams memory params)
        external
        returns (uint256 amountIn)
    {
        _camelotV3ExactOutputSingle(params);
    }

    /// @inheritdoc ICamelotV3
    function camelotV3ExactOutput(CamelotV3ExactOutputParams memory params) external returns (uint256 amountIn) {
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
