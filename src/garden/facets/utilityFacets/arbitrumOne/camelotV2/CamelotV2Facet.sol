// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    @title CamelotV2Facet
    @author BLOK Capital DAO
    @notice Facet contract for Camelot V2 integration (swaps)
    @dev This contract provides the functionality for Camelot V2 integration (swaps)

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { Facet } from "src/garden/facets/Facet.sol";
import { CamelotV2Base } from "src/garden/facets/utilityFacets/arbitrumOne/camelotV2/CamelotV2Base.sol";
import { ICamelotV2 } from "src/garden/facets/utilityFacets/arbitrumOne/camelotV2/ICamelotV2.sol";

contract CamelotV2Facet is ICamelotV2, CamelotV2Base, Facet {
    /// @inheritdoc ICamelotV2
    function camelotV2ExactInputSingle(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        address referrer,
        uint256 deadline
    )
        external
        override
    {
        _camelotV2ExactInputSingle(amountIn, amountOutMin, path, to, referrer, deadline);
    }

    /// @inheritdoc ICamelotV2
    function camelotV2ExactInput(
        uint256 amountInMax,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        address referrer,
        uint256 deadline
    )
        external
        override
    {
        _camelotV2ExactInput(amountInMax, amountOutMin, path, to, referrer, deadline);
    }

    /// @inheritdoc ICamelotV2
    function camelotV2ExactOutputSingle(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        address referrer,
        uint256 deadline
    )
        external
        override
    {
        _camelotV2ExactOutputSingle(amountIn, amountOutMin, path, to, referrer, deadline);
    }
}
