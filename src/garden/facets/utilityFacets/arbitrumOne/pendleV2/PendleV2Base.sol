// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IPAllActionV3 } from "@pendle/pendle-core-v2-public/contracts/interfaces/IPAllActionV3.sol";
import { IPMarket } from "@pendle/pendle-core-v2-public/contracts/interfaces/IPMarket.sol";
import { IPPrincipalToken } from "@pendle/pendle-core-v2-public/contracts/interfaces/IPPrincipalToken.sol";
import {
    TokenInput,
    TokenOutput,
    LimitOrderData,
    ApproxParams,
    ExitPostExpReturnParams
} from "@pendle/pendle-core-v2-public/contracts/interfaces/IPAllActionTypeV3.sol";

/// @notice Thrown when a post-expiry redemption is attempted on a market that has not yet matured
error PendleV2Facet_MarketNotExpired();

/**
 * @title PendleV2Base
 * @notice Base contract that implements internal functions for swapping tokens through the Pendle V2 router on Arbitrum
 * One. This contract is intended to be inherited by a PendleV2Facet that exposes the swap functions with appropriate
 * access control and user-facing error messages. It includes the core logic for interacting with the Pendle V2 router
 * to perform token swaps, along with events for off-chain tracking of these operations.
 */
abstract contract PendleV2Base {
    using SafeERC20 for IERC20;

    /// @notice The address of the Pendle V2 router on Arbitrum One
    address private constant PENDLE_V2_ROUTER_ADDRESS = 0x929eC64C34a17401F460460d4B9390518e525bB4;

    event PendleV2FacetSwappedExactTokenForPt(
        address indexed receiver,
        address indexed market,
        uint256 minPtOut,
        uint256 netPtOut,
        uint256 netSyFee,
        uint256 netSyInterm
    );

    event PendleV2FacetSwappedExactPtForToken(
        address indexed receiver,
        address indexed market,
        uint256 exactPtIn,
        uint256 netTokenOut,
        uint256 netSyFee,
        uint256 netSyInterm
    );

    event PendleV2FacetExitPostExpiry(
        address indexed receiver, address indexed market, uint256 netPtIn, uint256 netTokenOut, uint256 totalSyOut
    );

    /// @notice Swaps an exact amount of tokens for Principal Tokens (PT) via the Pendle V2 router
    /// @param receiver Address to receive the PT output
    /// @param market Address of the Pendle market
    /// @param minPtOut Minimum PT output amount (slippage protection)
    /// @param guessPtOut Approximation parameters for PT output calculation
    /// @param input Token input parameters including token address and amount
    /// @param limit Limit order data for the swap
    /// @return netPtOut The net PT amount received
    /// @return netSyFee The SY fee incurred
    /// @return netSyInterm The intermediate SY amount
    function _pendleV2SwapExactTokenForPt(
        address receiver,
        address market,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut,
        TokenInput calldata input,
        LimitOrderData calldata limit
    )
        internal
        returns (uint256 netPtOut, uint256 netSyFee, uint256 netSyInterm)
    {
        IPAllActionV3 router = IPAllActionV3(PENDLE_V2_ROUTER_ADDRESS);

        IERC20 tokenIn = IERC20(input.tokenIn);

        tokenIn.forceApprove(address(router), input.netTokenIn);
        (netPtOut, netSyFee, netSyInterm) =
            router.swapExactTokenForPt{ value: msg.value }(receiver, market, minPtOut, guessPtOut, input, limit);
        tokenIn.forceApprove(address(router), 0);
        emit PendleV2FacetSwappedExactTokenForPt(receiver, market, minPtOut, netPtOut, netSyFee, netSyInterm);
    }

    /// @notice Swaps an exact amount of Principal Tokens (PT) for tokens via the Pendle V2 router
    /// @param receiver Address to receive the token output
    /// @param market Address of the Pendle market
    /// @param exactPtIn Exact amount of PT to swap
    /// @param output Token output parameters including token address and minimum amount
    /// @param limit Limit order data for the swap
    /// @return netTokenOut The net token amount received
    /// @return netSyFee The SY fee incurred
    /// @return netSyInterm The intermediate SY amount
    function _pendleV2SwapExactPtForToken(
        address receiver,
        address market,
        uint256 exactPtIn,
        TokenOutput calldata output,
        LimitOrderData calldata limit
    )
        internal
        returns (uint256 netTokenOut, uint256 netSyFee, uint256 netSyInterm)
    {
        IPAllActionV3 router = IPAllActionV3(PENDLE_V2_ROUTER_ADDRESS);

        (, IPPrincipalToken PT,) = IPMarket(market).readTokens();
        IERC20 pt = IERC20(address(PT));

        pt.forceApprove(address(router), exactPtIn);
        (netTokenOut, netSyFee, netSyInterm) = router.swapExactPtForToken(receiver, market, exactPtIn, output, limit);
        pt.forceApprove(address(router), 0);
        emit PendleV2FacetSwappedExactPtForToken(receiver, market, exactPtIn, netTokenOut, netSyFee, netSyInterm);
    }

    /// @notice Redeems Principal Tokens (PT) for tokens after the Pendle market has matured
    /// @dev After expiry the market's `notExpired` guard blocks all swaps, so PT must be redeemed rather than traded.
    /// Reverts if the market has not yet expired: pre-expiry `redeemPY` requires a matching YT balance, so redeeming
    /// PT alone would transfer the PT into the YT contract without redeeming it.
    /// @param receiver Address to receive the token output
    /// @param market Address of the Pendle market
    /// @param netPtIn Amount of PT to redeem
    /// @param output Token output parameters including token address and minimum amount
    /// @return totalTokenOut The net token amount received
    /// @return params Breakdown of the redemption as reported by the Pendle router
    function _pendleV2ExitPostExpToToken(
        address receiver,
        address market,
        uint256 netPtIn,
        TokenOutput calldata output
    )
        internal
        returns (uint256 totalTokenOut, ExitPostExpReturnParams memory params)
    {
        if (!IPMarket(market).isExpired()) revert PendleV2Facet_MarketNotExpired();

        IPAllActionV3 router = IPAllActionV3(PENDLE_V2_ROUTER_ADDRESS);

        (, IPPrincipalToken PT,) = IPMarket(market).readTokens();
        IERC20 pt = IERC20(address(PT));

        pt.forceApprove(address(router), netPtIn);
        // netLpIn is hardcoded to 0: gardens never hold Pendle LP.
        (totalTokenOut, params) = router.exitPostExpToToken(receiver, market, netPtIn, 0, output);
        pt.forceApprove(address(router), 0);
        // Only totalSyOut is emitted from `params`: with netLpIn == 0 the remove-liquidity fields are always zero and
        // netPtRedeem always equals netPtIn. totalSyOut is the SY intermediate, mirroring netSyInterm on the swap
        // events.
        emit PendleV2FacetExitPostExpiry(receiver, market, netPtIn, totalTokenOut, params.totalSyOut);
    }
}

