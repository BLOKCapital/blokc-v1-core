// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title PendleV2Base
    @author BLOK Capital DAO
    @notice Base contract for Pendle V2 protocol integration
    @dev Base contract for Pendle V2 protocol integration
         This contract provides the base functionality for the Pendle V2 facet.
         It contains the logic for swapping tokens for PT and PT for tokens.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IPAllActionV3 } from "@pendle/pendle-core-v2-public/contracts/interfaces/IPAllActionV3.sol";
import {
    TokenInput,
    TokenOutput,
    LimitOrderData,
    ApproxParams
} from "@pendle/pendle-core-v2-public/contracts/interfaces/IPAllActionTypeV3.sol";

abstract contract PendleV2Base {
    using SafeERC20 for IERC20;
    /// @notice The address of the Pendle V2 router on Arbitrum One
    address private constant PENDLE_V2_ROUTER_ADDRESS = 0x929eC64C34a17401F460460d4B9390518e525bB4;

    function _swapExactTokenForPt(
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
    }

    function _swapExactPtForToken(
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

        IERC20 tokenOut = IERC20(output.tokenOut);
        (netTokenOut, netSyFee, netSyInterm) = router.swapExactPtForToken(receiver, market, exactPtIn, output, limit);
    }
}
