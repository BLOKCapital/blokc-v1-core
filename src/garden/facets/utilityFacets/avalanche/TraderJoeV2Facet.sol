// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title TraderJoeV2Facet
    @author BLOK Capital DAO
    @notice Facet exposing Trader Joe V2 (LBRouter) liquidity and swap functions
    @dev This facet provides integration with Trader Joe V2 on Avalanche.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ILBRouter } from "@joe-v2/src/interfaces/ILBRouter.sol";
import { Facet } from "src/garden/facets/Facet.sol";
import { TraderJoeV2Base } from "src/garden/facets/utilityFacets/avalanche/TraderJoeV2Base.sol";
import { ITraderJoeV2 } from "src/garden/facets/utilityFacets/avalanche/ITraderJoeV2.sol";

contract TraderJoeV2Facet is ITraderJoeV2, TraderJoeV2Base, Facet {
    // -------------------------------------------------------------------------
    // Swaps
    // -------------------------------------------------------------------------

    /// @inheritdoc ITraderJoeV2
    function traderJoeV2SwapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        ILBRouter.Path memory path,
        address to,
        uint256 deadline
    )
        external
        override
        onlyGardenOwner
        ifIndexNotConnected
        returns (uint256 amountOut)
    {
        return _traderJoeV2SwapExactTokensForTokens(amountIn, amountOutMin, path, to, deadline);
    }

    /// @inheritdoc ITraderJoeV2
    function traderJoeV2SwapExactTokensForNative(
        uint256 amountIn,
        uint256 amountOutMinNative,
        ILBRouter.Path memory path,
        address payable to,
        uint256 deadline
    )
        external
        override
        onlyGardenOwner
        ifIndexNotConnected
        returns (uint256 amountOut)
    {
        return _traderJoeV2SwapExactTokensForNative(amountIn, amountOutMinNative, path, to, deadline);
    }

    /// @inheritdoc ITraderJoeV2
    function traderJoeV2SwapExactNativeForTokens(
        uint256 amountOutMin,
        ILBRouter.Path memory path,
        address to,
        uint256 deadline
    )
        external
        payable
        override
        onlyGardenOwner
        ifIndexNotConnected
        returns (uint256 amountOut)
    {
        return _traderJoeV2SwapExactNativeForTokens(amountOutMin, path, to, deadline);
    }

    /// @inheritdoc ITraderJoeV2
    function traderJoeV2SwapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        ILBRouter.Path memory path,
        address to,
        uint256 deadline
    )
        external
        override
        onlyGardenOwner
        ifIndexNotConnected
        returns (uint256[] memory amountIn)
    {
        return _traderJoeV2SwapTokensForExactTokens(amountOut, amountInMax, path, to, deadline);
    }

    /// @inheritdoc ITraderJoeV2
    function traderJoeV2SwapTokensForExactNative(
        uint256 amountOut,
        uint256 amountInMax,
        ILBRouter.Path memory path,
        address payable to,
        uint256 deadline
    )
        external
        override
        onlyGardenOwner
        ifIndexNotConnected
        returns (uint256[] memory amountsIn)
    {
        return _traderJoeV2SwapTokensForExactNative(amountOut, amountInMax, path, to, deadline);
    }

    /// @inheritdoc ITraderJoeV2
    function traderJoeV2SwapNativeForExactTokens(
        uint256 amountOut,
        ILBRouter.Path memory path,
        address to,
        uint256 deadline
    )
        external
        payable
        override
        onlyGardenOwner
        ifIndexNotConnected
        returns (uint256[] memory amountsIn)
    {
        return _traderJoeV2SwapNativeForExactTokens(amountOut, path, to, deadline);
    }
}


