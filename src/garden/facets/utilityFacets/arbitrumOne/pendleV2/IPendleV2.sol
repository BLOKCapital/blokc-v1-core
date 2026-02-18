// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import {
    ApproxParams,
    TokenInput,
    TokenOutput,
    LimitOrderData
} from "@pendle/pendle-core-v2-public/contracts/interfaces/IPAllActionTypeV3.sol";

/// @title IPendleV2
/// @author BLOK Capital DAO
/// @notice Interface for Pendle V2 protocol integration (PT swaps)
interface IPendleV2 {
    /// @notice Swaps an exact amount of tokens for Principal Tokens (PT)
    /// @param receiver Address to receive the PT output
    /// @param market Address of the Pendle market
    /// @param minPtOut Minimum PT output amount (slippage protection)
    /// @param guessPtOut Approximation parameters for PT output calculation
    /// @param input Token input parameters including token address and amount
    /// @param limit Limit order data for the swap
    /// @return netPtOut The net PT amount received
    /// @return netSyFee The SY fee incurred
    /// @return netSyInterm The intermediate SY amount
    function swapExactTokenForPt(
        address receiver,
        address market,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut,
        TokenInput calldata input,
        LimitOrderData calldata limit
    )
        external
        payable
        returns (uint256 netPtOut, uint256 netSyFee, uint256 netSyInterm);

    /// @notice Swaps an exact amount of Principal Tokens (PT) for tokens
    /// @param receiver Address to receive the token output
    /// @param market Address of the Pendle market
    /// @param exactPtIn Exact amount of PT to swap
    /// @param output Token output parameters including token address and minimum amount
    /// @param limit Limit order data for the swap
    /// @return netTokenOut The net token amount received
    /// @return netSyFee The SY fee incurred
    /// @return netSyInterm The intermediate SY amount
    function swapExactPtForToken(
        address receiver,
        address market,
        uint256 exactPtIn,
        TokenOutput calldata output,
        LimitOrderData calldata limit
    )
        external
        returns (uint256 netTokenOut, uint256 netSyFee, uint256 netSyInterm);
}
