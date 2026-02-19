// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { PendleV2Base } from "src/garden/facets/utilityFacets/arbitrumOne/pendleV2/PendleV2Base.sol";
import { IPendleV2 } from "src/garden/facets/utilityFacets/arbitrumOne/pendleV2/IPendleV2.sol";
import { Facet } from "src/garden/facets/Facet.sol";
import {
    ApproxParams,
    TokenInput,
    TokenOutput,
    LimitOrderData
} from "@pendle/pendle-core-v2-public/contracts/interfaces/IPAllActionTypeV3.sol";

/**
 * @title PendleV2Facet
 * @author BLOK Capital DAO
 * @notice Facet that implements the IPendleV2 interface to allow swapping tokens through the Pendle V2 router on
 * Arbitrum One.
 * This facet provides external functions for garden owners to perform token swaps using Pendle V2, with appropriate
 * access control and user-facing error messages. It inherits from PendleV2Base which contains the internal logic for
 * interacting with Pendle V2, while PendleV2Facet itself provides the external interface for these operations.
 */
contract PendleV2Facet is IPendleV2, PendleV2Base, Facet {
    /// @inheritdoc IPendleV2
    function pendleV2SwapExactTokenForPt(
        address receiver,
        address market,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut,
        TokenInput calldata input,
        LimitOrderData calldata limit
    )
        external
        payable
        override
        onlyGardenOwner
        nonReentrant
        ifIndexNotConnected
        returns (uint256 netPtOut, uint256 netSyFee, uint256 netSyInterm)
    {
        return _pendleV2SwapExactTokenForPt(receiver, market, minPtOut, guessPtOut, input, limit);
    }

    /// @inheritdoc IPendleV2
    function pendleV2SwapExactPtForToken(
        address receiver,
        address market,
        uint256 exactPtIn,
        TokenOutput calldata output,
        LimitOrderData calldata limit
    )
        external
        override
        onlyGardenOwner
        nonReentrant
        ifIndexNotConnected
        returns (uint256 netTokenOut, uint256 netSyFee, uint256 netSyInterm)
    {
        return _pendleV2SwapExactPtForToken(receiver, market, exactPtIn, output, limit);
    }
}
