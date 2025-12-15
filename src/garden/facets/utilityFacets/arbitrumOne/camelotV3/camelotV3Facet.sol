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
}
