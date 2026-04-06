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
import { SwapInstruction, QuoteInstruction } from "src/interfaces/ISwapInstruction.sol";

/**
 * @title CamelotV3Facet
 * @author BLOK Capital DAO
 * @notice Facet for Camelot V3 swaps and quotes on Arbitrum One. Single swap selector,
 *         single quote selector. Camelot V3 uses dynamic fees (Algebra protocol) — no
 *         fee parameter needed.
 */
contract CamelotV3Facet is ICamelotV3, CamelotV3Base, Facet {
    // ========================================================================
    // External Functions
    // ========================================================================

    /// @inheritdoc ICamelotV3
    function camelotV3Swap(SwapInstruction calldata instruction)
        external
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
    {
        _camelotV3Swap(instruction);
    }

    // ========================================================================
    // External Functions (View)
    // ========================================================================

    /// @inheritdoc ICamelotV3
    function camelotV3GetSqrtTwapX96(address poolAddress, uint32 twapInterval)
        external
        view
        returns (uint160 sqrtPriceX96, uint256 deadline)
    {
        return _camelotV3GetSqrtTwapX96(poolAddress, twapInterval);
    }

    /// @inheritdoc ICamelotV3
    function camelotV3Quote(QuoteInstruction calldata instruction) external view returns (uint256 result) {
        return _camelotV3Quote(instruction);
    }
}
