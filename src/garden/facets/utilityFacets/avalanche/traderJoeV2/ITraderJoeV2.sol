// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title ITraderJoeV2
    @author BLOK Capital DAO
    @notice Interface for Trader Joe V2 (LBRouter) integration on Avalanche

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ILBRouter } from "@joe-v2/src/interfaces/ILBRouter.sol";

interface ITraderJoeV2 {
    // -------------------------------------------------------------------------
    // Swaps (no fee-on-transfer specialization here, we keep a minimal surface)
    // -------------------------------------------------------------------------
    // @dev Uses ILBRouter.Path directly from the Trader Joe V2 library

    function traderJoeV2SwapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        ILBRouter.Path memory path,
        address to,
        uint256 deadline
    ) external returns (uint256 amountOut);

    function traderJoeV2SwapExactTokensForNative(
        uint256 amountIn,
        uint256 amountOutMinNative,
        ILBRouter.Path memory path,
        address payable to,
        uint256 deadline
    ) external returns (uint256 amountOut);

    function traderJoeV2SwapExactNativeForTokens(
        uint256 amountOutMin,
        ILBRouter.Path memory path,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountOut);

    function traderJoeV2SwapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        ILBRouter.Path memory path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amountIn);

    function traderJoeV2SwapTokensForExactNative(
        uint256 amountOut,
        uint256 amountInMax,
        ILBRouter.Path memory path,
        address payable to,
        uint256 deadline
    ) external returns (uint256[] memory amountsIn);

    function traderJoeV2SwapNativeForExactTokens(
        uint256 amountOut,
        ILBRouter.Path memory path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amountsIn);
}


