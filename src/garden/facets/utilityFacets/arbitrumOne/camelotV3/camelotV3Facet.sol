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

import { CamelotV3Base } from "src/garden/facets/utilityFacets/arbitrumOne/camelotV3/camelotV3Base.sol";
import { ICamelotV3 } from "src/garden/facets/utilityFacets/arbitrumOne/camelotV3/ICamelotV3.sol";
import { Facet } from "src/garden/facets/Facet.sol";

contract CamelotV3Facet is ICamelotV3, CamelotV3Base, Facet {
    /// @inheritdoc ICamelotV3
    function camelotV3ExactInputSingle(CamelotV3ExactInputSingleParams memory params)
        external
        override
        onlyGardenOwner
        nonReentrant
        ifIndexNotConnected
        returns (uint256 amountOut)
    {
        _camelotV3ExactInputSingle(params);
    }

    /// @inheritdoc ICamelotV3
    function camelotV3ExactInput(CamelotV3ExactInputParams memory params)
        external
        override
        onlyGardenOwner
        nonReentrant
        ifIndexNotConnected
        returns (uint256 amountOut)
    {
        _camelotV3ExactInput(params);
    }

    /// @inheritdoc ICamelotV3
    function camelotV3ExactOutputSingle(CamelotV3ExactOutputSingleParams memory params)
        external
        override
        onlyGardenOwner
        nonReentrant
        ifIndexNotConnected
        returns (uint256 amountIn)
    {
        _camelotV3ExactOutputSingle(params);
    }

    /// @inheritdoc ICamelotV3
    function camelotV3ExactOutput(CamelotV3ExactOutputParams memory params)
        external
        override
        onlyGardenOwner
        nonReentrant
        ifIndexNotConnected
        returns (uint256 amountIn)
    {
        _camelotV3ExactOutput(params);
    }
}
