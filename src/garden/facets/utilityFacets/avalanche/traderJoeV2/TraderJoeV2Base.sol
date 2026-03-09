// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title TraderJoeV2Base
    @author BLOK Capital DAO
    @notice Base contract for Trader Joe V2 (LBRouter) integration on Avalanche
    @dev This contract wraps the Joe V2 LBRouter for liquidity and swap operations.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { ILBRouter } from "@joe-v2/src/interfaces/ILBRouter.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ILBFactory } from "@joe-v2/src/interfaces/ILBFactory.sol";
import { ILBPair } from "@joe-v2/src/interfaces/ILBPair.sol";
import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";

import { ITraderJoeV2 } from "src/garden/facets/utilityFacets/avalanche/traderJoeV2/ITraderJoeV2.sol";

// ============================================================================
// Errors
// ============================================================================

error TraderJoeV2Facet_DeadlinePassed();
error TraderJoeV2Facet_InsufficientBalance();
error TraderJoeV2Facet_ApprovalFailed();
error TraderJoeV2Facet_InvalidAmount();
error TraderJoeV2Facet_InvalidPath();
error TraderJoeV2Facet_ArrayLengthMismatch();
error TraderJoeV2Facet_UnregisteredPool();

abstract contract TraderJoeV2Base {
    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    /// @notice Avalanche Trader Joe V2 LBRouter address
    address internal constant TRADER_JOE_V2_ROUTER_ADDRESS = 0x60aE616a2155Ee3d9A68541Ba4544862310933d4;

    /// @notice Trader Joe V2 LBFactory address on Avalanche
    address internal constant TRADER_JOE_V2_FACTORY_ADDRESS = 0xb43120c4745967fa9b93E79C149E66B0f2D6Fe0c;

    /// @notice LiquidityPoolRegistry address used for pool validation
    address internal constant POOL_REGISTRY_ADDRESS = 0xBa7898DbE9C2be340197e1fffe85FC5a3B977744;

    // -------------------------------------------------------------------------
    // Internal helpers
    // -------------------------------------------------------------------------

    function _router() internal view returns (ILBRouter) {
        return ILBRouter(TRADER_JOE_V2_ROUTER_ADDRESS);
    }

    function _factory() internal view returns (ILBFactory) {
        return ILBFactory(TRADER_JOE_V2_FACTORY_ADDRESS);
    }

    function _safeApprove(IERC20 token, address spender, uint256 amount) internal {
        uint256 allowance = token.allowance(address(this), spender);
        if (allowance > 0) {
            if (!token.approve(spender, 0)) revert TraderJoeV2Facet_ApprovalFailed();
        }
        if (!token.approve(spender, amount)) revert TraderJoeV2Facet_ApprovalFailed();
    }

    function _validatePath(ILBRouter.Path memory path) internal pure {
        if (path.pairBinSteps.length < 1 || path.tokenPath.length < 2) {
            revert TraderJoeV2Facet_InvalidPath();
        }
        if (path.pairBinSteps.length != path.tokenPath.length - 1) {
            revert TraderJoeV2Facet_ArrayLengthMismatch();
        }
        if (path.versions.length != path.pairBinSteps.length) {
            revert TraderJoeV2Facet_ArrayLengthMismatch();
        }
    }

    /// @notice Validates the swap path and that all underlying pools are registered
    /// @dev Uses the Trader Joe LBFactory to resolve LB pairs, then checks LiquidityPoolRegistry
    function _validatePathAndPools(ILBRouter.Path memory path) internal view {
        _validatePath(path);

        uint256 numPairs = path.tokenPath.length - 1;

        for (uint256 i = 0; i < numPairs; ++i) {
            IERC20 tokenX = path.tokenPath[i];
            IERC20 tokenY = path.tokenPath[i + 1];
            uint16 binStep = uint16(path.pairBinSteps[i]);

            ILBFactory.LBPairInformation memory pairInfo = _factory().getLBPairInformation(tokenX, tokenY, binStep);
            _checkPoolRegistered(address(pairInfo.LBPair));
        }
    }

    /// @notice Checks that a given pool is registered in the LiquidityPoolRegistry
    /// @param pool Address of the liquidity pool to validate
    function _checkPoolRegistered(address pool) internal view {
        if (pool == address(0) || !ILiquidityPoolRegistry(POOL_REGISTRY_ADDRESS).isPoolRegistered(pool)) {
            revert TraderJoeV2Facet_UnregisteredPool();
        }
    }

    // -------------------------------------------------------------------------
    // Liquidity
    // -------------------------------------------------------------------------

    function _traderJoeV2CreateLBPair(
        address tokenX,
        address tokenY,
        uint24 activeId,
        uint16 binStep
    )
        internal
        returns (ILBPair pair)
    {
        if (binStep == 0) {
            revert TraderJoeV2Facet_InvalidAmount();
        }

        pair = _factory().createLBPair(IERC20(tokenX), IERC20(tokenY), activeId, binStep);

        _checkPoolRegistered(address(pair));
    }

    // -------------------------------------------------------------------------
    // Swaps
    // -------------------------------------------------------------------------

    function _traderJoeV2SwapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        ILBRouter.Path memory path,
        address to,
        uint256 deadline
    )
        internal
        returns (uint256 amountOut)
    {
        if (block.timestamp > deadline) revert TraderJoeV2Facet_DeadlinePassed();
        _validatePathAndPools(path);

        IERC20 tokenIn = path.tokenPath[0];
        if (tokenIn.balanceOf(address(this)) < amountIn) {
            revert TraderJoeV2Facet_InsufficientBalance();
        }

        _safeApprove(tokenIn, TRADER_JOE_V2_ROUTER_ADDRESS, amountIn);
        amountOut = _router().swapExactTokensForTokens(amountIn, amountOutMin, path, to, deadline);
    }

    function _traderJoeV2SwapExactTokensForNative(
        uint256 amountIn,
        uint256 amountOutMinNative,
        ILBRouter.Path memory path,
        address payable to,
        uint256 deadline
    )
        internal
        returns (uint256 amountOut)
    {
        if (block.timestamp > deadline) revert TraderJoeV2Facet_DeadlinePassed();
        _validatePathAndPools(path);

        IERC20 tokenIn = path.tokenPath[0];
        if (tokenIn.balanceOf(address(this)) < amountIn) {
            revert TraderJoeV2Facet_InsufficientBalance();
        }

        _safeApprove(tokenIn, TRADER_JOE_V2_ROUTER_ADDRESS, amountIn);
        amountOut = _router().swapExactTokensForNATIVE(amountIn, amountOutMinNative, path, to, deadline);
    }

    function _traderJoeV2SwapExactNativeForTokens(
        uint256 amountOutMin,
        ILBRouter.Path memory path,
        address to,
        uint256 deadline
    )
        internal
        returns (uint256 amountOut)
    {
        if (block.timestamp > deadline) revert TraderJoeV2Facet_DeadlinePassed();
        if (msg.value == 0) revert TraderJoeV2Facet_InsufficientBalance();
        _validatePathAndPools(path);

        amountOut = _router().swapExactNATIVEForTokens{ value: msg.value }(amountOutMin, path, to, deadline);
    }

    function _traderJoeV2SwapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        ILBRouter.Path memory path,
        address to,
        uint256 deadline
    )
        internal
        returns (uint256[] memory amountIn)
    {
        if (block.timestamp > deadline) revert TraderJoeV2Facet_DeadlinePassed();
        if (amountOut == 0 || amountInMax == 0) revert TraderJoeV2Facet_InvalidAmount();
        _validatePathAndPools(path);

        IERC20 tokenIn = path.tokenPath[0];
        if (tokenIn.balanceOf(address(this)) < amountInMax) {
            revert TraderJoeV2Facet_InsufficientBalance();
        }

        _safeApprove(tokenIn, TRADER_JOE_V2_ROUTER_ADDRESS, amountInMax);
        amountIn = _router().swapTokensForExactTokens(amountOut, amountInMax, path, to, deadline);
    }

    function _traderJoeV2SwapTokensForExactNative(
        uint256 amountOut,
        uint256 amountInMax,
        ILBRouter.Path memory path,
        address payable to,
        uint256 deadline
    )
        internal
        returns (uint256[] memory amountsIn)
    {
        if (block.timestamp > deadline) revert TraderJoeV2Facet_DeadlinePassed();
        if (amountOut == 0 || amountInMax == 0) revert TraderJoeV2Facet_InvalidAmount();
        _validatePathAndPools(path);

        IERC20 tokenIn = path.tokenPath[0];
        if (tokenIn.balanceOf(address(this)) < amountInMax) {
            revert TraderJoeV2Facet_InsufficientBalance();
        }

        _safeApprove(tokenIn, TRADER_JOE_V2_ROUTER_ADDRESS, amountInMax);
        amountsIn = _router().swapTokensForExactNATIVE(amountOut, amountInMax, path, to, deadline);
    }

    function _traderJoeV2SwapNativeForExactTokens(
        uint256 amountOut,
        ILBRouter.Path memory path,
        address to,
        uint256 deadline
    )
        internal
        returns (uint256[] memory amountsIn)
    {
        if (block.timestamp > deadline) revert TraderJoeV2Facet_DeadlinePassed();
        if (msg.value == 0 || amountOut == 0) revert TraderJoeV2Facet_InvalidAmount();
        _validatePathAndPools(path);

        amountsIn = _router().swapNATIVEForExactTokens{ value: msg.value }(amountOut, path, to, deadline);
    }
}
