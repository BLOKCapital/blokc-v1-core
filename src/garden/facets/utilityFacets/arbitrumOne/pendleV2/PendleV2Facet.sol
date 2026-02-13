// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    @title PendleV2Facet
    @author BLOK Capital DAO
    @notice Facet for Pendle V2 protocol integration
    @dev Facet for Pendle V2 protocol integration
         This facet provides the functionality for the Pendle V2 protocol.
         It contains the logic for swapping tokens for PT and PT for tokens.

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

contract PendleV2Facet is IPendleV2, PendleV2Base, Facet {
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
        override
        onlyGardenOwner
        returns (uint256 netPtOut, uint256 netSyFee, uint256 netSyInterm)
    {
        return _swapExactTokenForPt(receiver, market, minPtOut, guessPtOut, input, limit);
    }

    function swapExactPtForToken(
        address receiver,
        address market,
        uint256 exactPtIn,
        TokenOutput calldata output,
        LimitOrderData calldata limit
    )
        external
        override
        onlyGardenOwner
        returns (uint256 netTokenOut, uint256 netSyFee, uint256 netSyInterm)
    {
        return _swapExactPtForToken(receiver, market, exactPtIn, output, limit);
    }
}
