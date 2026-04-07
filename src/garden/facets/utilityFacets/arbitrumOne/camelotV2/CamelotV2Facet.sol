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
import { SwapInstruction, QuoteInstruction } from "src/interfaces/ISwapInstruction.sol";

/**
 * @title CamelotV2Facet
 * @author BLOK Capital DAO
 * @notice Facet for Camelot V2 swaps and quotes on Arbitrum One. Single swap selector,
 *         single quote selector. Camelot V2 uses the classic AMM (constant-product) with
 *         0.3% fee. Only exact-input swaps are supported.
 */
contract CamelotV2Facet is ICamelotV2, CamelotV2Base, Facet {
    // ========================================================================
    // External Functions
    // ========================================================================

    /// @inheritdoc ICamelotV2
    function camelotV2Swap(SwapInstruction calldata instruction)
        external
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
    {
        _camelotV2Swap(instruction);
    }

    // ========================================================================
    // External Functions (View)
    // ========================================================================

    /// @inheritdoc ICamelotV2
    function camelotV2Quote(QuoteInstruction calldata instruction) external view returns (uint256 result) {
        return _camelotV2Quote(instruction);
    }
}
