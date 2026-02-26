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

    /// @notice Swaps an exact amount of input tokens for output tokens
    /// @param amountIn The exact amount of input tokens to swap
    /// @param amountOutMin The minimum amount of output tokens to receive
    /// @param path The swap path containing token pairs and bin steps
    /// @param to The address to receive the output tokens
    /// @param deadline The deadline timestamp for the swap
    /// @return amountOut The actual amount of output tokens received
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

    /// @notice Swaps an exact amount of input tokens for native tokens (AVAX)
    /// @param amountIn The exact amount of input tokens to swap
    /// @param amountOutMinNative The minimum amount of native tokens to receive
    /// @param path The swap path containing token pairs and bin steps
    /// @param to The address to receive the native tokens
    /// @param deadline The deadline timestamp for the swap
    /// @return amountOut The actual amount of native tokens received
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

    /// @notice Swaps an exact amount of native tokens (AVAX) for output tokens
    /// @param amountOutMin The minimum amount of output tokens to receive
    /// @param path The swap path containing token pairs and bin steps
    /// @param to The address to receive the output tokens
    /// @param deadline The deadline timestamp for the swap
    /// @return amountOut The actual amount of output tokens received
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

    /// @notice Swaps input tokens for an exact amount of output tokens
    /// @param amountOut The exact amount of output tokens to receive
    /// @param amountInMax The maximum amount of input tokens to spend
    /// @param path The swap path containing token pairs and bin steps
    /// @param to The address to receive the output tokens
    /// @param deadline The deadline timestamp for the swap
    /// @return amountIn The actual amount of input tokens spent
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

    /// @notice Swaps input tokens for an exact amount of native tokens (AVAX)
    /// @param amountOut The exact amount of native tokens to receive
    /// @param amountInMax The maximum amount of input tokens to spend
    /// @param path The swap path containing token pairs and bin steps
    /// @param to The address to receive the native tokens
    /// @param deadline The deadline timestamp for the swap
    /// @return amountsIn The actual amounts of input tokens spent at each step
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

    /// @notice Swaps native tokens (AVAX) for an exact amount of output tokens
    /// @param amountOut The exact amount of output tokens to receive
    /// @param path The swap path containing token pairs and bin steps
    /// @param to The address to receive the output tokens
    /// @param deadline The deadline timestamp for the swap
    /// @return amountsIn The actual amounts of native tokens spent at each step
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


