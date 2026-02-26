// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { Facet } from "src/garden/facets/Facet.sol";
import { CamelotV2Base } from "src/garden/facets/utilityFacets/arbitrumOne/camelotV2/CamelotV2Base.sol";
import { ICamelotV2 } from "src/garden/facets/utilityFacets/arbitrumOne/camelotV2/ICamelotV2.sol";

/**
 * @title CamelotV2Facet
 * @author BLOK Capital DAO
 * @notice Facet that implements the ICamelotV2 interface to allow swapping tokens through Camelot V2 on Arbitrum One.
 * This facet provides external functions for garden owners to perform token swaps using Camelot V2, with appropriate
 * access control and user-facing error messages. It inherits from CamelotV2Base which contains the internal logic for
 * interacting with Camelot V2, while CamelotV2Facet itself provides the external interface for these operations.
 */
contract CamelotV2Facet is ICamelotV2, CamelotV2Base, Facet {
    /// @inheritdoc ICamelotV2
    function camelotV2ExactInputSingle(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address referrer,
        uint256 deadline
    )
        external
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
    {
        _camelotV2ExactInputSingle(amountIn, amountOutMin, path, referrer, deadline);
    }

    /// @inheritdoc ICamelotV2
    function camelotV2ExactInput(
        uint256 amountInMax,
        uint256 amountOutMin,
        address[] calldata path,
        address referrer,
        uint256 deadline
    )
        external
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
    {
        _camelotV2ExactInput(amountInMax, amountOutMin, path, referrer, deadline);
    }

    /// @inheritdoc ICamelotV2
    function camelotV2ExactOutputSingle(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address referrer,
        uint256 deadline
    )
        external
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
    {
        _camelotV2ExactOutputSingle(amountIn, amountOutMin, path, referrer, deadline);
    }
}
