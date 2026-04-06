// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

/// @notice Standardised swap instruction used by all DEX facet swap wrappers.
///         The CRE / frontend passes the same struct regardless of DEX — each facet
///         derives DEX-specific parameters (fee tiers, bin steps, coin indices, etc.)
///         on-chain from the pool contracts.
/// @param amountIn    exactOutput=false: exact spend amount.
///                     exactOutput=true:  maximum spend amount.
/// @param amountOut   exactOutput=false: minimum receive amount.
///                     exactOutput=true:  exact receive amount.
/// @param tokens      Ordered token path: [tokenIn, ..intermediaries.., tokenOut]
/// @param pools       One pool address per hop (pools.length == tokens.length - 1)
/// @param exactOutput False for exact-input swaps, true for exact-output swaps
struct SwapInstruction {
    uint256 amountIn;
    uint256 amountOut;
    address[] tokens;
    address[] pools;
    bool exactOutput;
}

/// @notice Standardised quote instruction used by all DEX facet quote functions.
///         Mirrors SwapInstruction but for view-only price estimation.
/// @param amount      exactOutput=false: input amount to quote output for.
///                     exactOutput=true:  desired output amount to quote input for.
/// @param tokens      Ordered token path: [tokenIn, ..intermediaries.., tokenOut]
/// @param pools       One pool address per hop (pools.length == tokens.length - 1)
/// @param exactOutput False: "how much output for this input?"
///                     True:  "how much input needed for this output?"
struct QuoteInstruction {
    uint256 amount;
    address[] tokens;
    address[] pools;
    bool exactOutput;
}
