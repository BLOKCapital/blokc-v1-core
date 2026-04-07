// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { SwapInstruction, QuoteInstruction } from "src/interfaces/ISwapInstruction.sol";

/// @title ICamelotV2
/// @author BLOK Capital DAO
/// @notice Interface for Camelot V2 integration (swaps and quotes)
interface ICamelotV2 {
    /// @notice Single entry point for all Camelot V2 swaps.
    ///         Handles single-hop and multi-hop exact-input swaps.
    ///         Camelot V2 uses fee-on-transfer compatible router functions.
    ///         Exact-output is not supported (reverts with CamelotV2Facet_ExactOutputNotSupported).
    /// @param instruction The universal SwapInstruction (same struct across all DEX facets)
    function camelotV2Swap(SwapInstruction calldata instruction) external;

    /// @notice Single entry point for all Camelot V2 quotes.
    ///         Handles single-hop and multi-hop, exact-input and exact-output.
    ///         Uses constant-product formula with 0.3% fee.
    /// @param instruction The universal QuoteInstruction (same struct across all DEX facets)
    /// @return result exactOutput=false: estimated output. exactOutput=true: estimated input needed.
    function camelotV2Quote(QuoteInstruction calldata instruction) external view returns (uint256 result);
}
