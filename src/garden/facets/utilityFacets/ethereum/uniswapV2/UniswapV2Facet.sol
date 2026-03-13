// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

// OpenZeppelin Contracts
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Local Interfaces
import { IUniswapV2 } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV2/IUniswapV2.sol";

// Local Libraries
import { UniswapV2Base } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV2/UniswapV2Base.sol";
import { Facet } from "src/garden/facets/Facet.sol";

/**
 * @title UniswapV2Facet
 * @author Blok Capital DAO
 * @notice Facet that implements the IUniswapV2 interface to allow swapping tokens through the Uniswap V2 router on
 * Arbitrum One. This facet provides external functions for garden owners to perform token swaps using Uniswap V2, with
 * appropriate access control and user-facing error messages. It inherits from UniswapV2Base which contains the internal
 * logic for interacting with Uniswap V2, while UniswapV2Facet itself provides the external interface for these
 * operations.
 */
contract UniswapV2Facet is IUniswapV2, UniswapV2Base, Facet {
    using SafeERC20 for IERC20;

    // ========================================================================
    // External Functions
    // ========================================================================

    /// @inheritdoc IUniswapV2
    function uniswapV2SwapExactTokensForTokens(UniswapV2SwapExactTokensForTokensParams calldata params)
        external
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
        returns (uint256[] memory amounts)
    {
        return _uniswapV2SwapExactTokensForTokens(params);
    }

    /// @inheritdoc IUniswapV2
    function uniswapV2SwapTokensForExactTokens(UniswapV2SwapTokensForExactTokensParams calldata params)
        external
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
        returns (uint256[] memory amounts)
    {
        return _uniswapV2SwapTokensForExactTokens(params);
    }

    /// @inheritdoc IUniswapV2
    function uniswapV2SwapExactETHForTokens(UniswapV2SwapExactETHForTokensParams calldata params)
        external
        payable
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
        returns (uint256[] memory amounts)
    {
        return _uniswapV2SwapExactETHForTokens(params);
    }

    /// @inheritdoc IUniswapV2
    function uniswapV2SwapTokensForExactETH(UniswapV2SwapTokensForExactETHParams calldata params)
        external
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
        returns (uint256[] memory amounts)
    {
        return _uniswapV2SwapTokensForExactETH(params);
    }

    /// @inheritdoc IUniswapV2
    function uniswapV2SwapExactTokensForETH(UniswapV2SwapExactTokensForETHParams calldata params)
        external
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
        returns (uint256[] memory amounts)
    {
        return _uniswapV2SwapExactTokensForETH(params);
    }

    /// @inheritdoc IUniswapV2
    function uniswapV2SwapETHForExactTokens(UniswapV2SwapETHForExactTokensParams calldata params)
        external
        payable
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
        returns (uint256[] memory amounts)
    {
        return _uniswapV2SwapETHForExactTokens(params);
    }

    /// @inheritdoc IUniswapV2
    function uniswapV2SwapExactTokensForTokensSupportingFeeOnTransferTokens(UniswapV2SwapExactTokensForTokensSupportingFeeOnTransferTokensParams calldata params)
        external
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
    {
        _uniswapV2SwapExactTokensForTokensSupportingFeeOnTransferTokens(params);
    }

    /// @inheritdoc IUniswapV2
    function uniswapV2SwapExactETHForTokensSupportingFeeOnTransferTokens(UniswapV2SwapExactETHForTokensSupportingFeeOnTransferTokensParams calldata params)
        external
        payable
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
    {
        _uniswapV2SwapExactETHForTokensSupportingFeeOnTransferTokens(params);
    }

    /// @inheritdoc IUniswapV2
    function uniswapV2SwapExactTokensForETHSupportingFeeOnTransferTokens(UniswapV2SwapExactTokensForETHSupportingFeeOnTransferTokensParams calldata params)
        external
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
    {
        _uniswapV2SwapExactTokensForETHSupportingFeeOnTransferTokens(params);
    }

    // ========================================================================
    // External Functions (View)
    // ========================================================================

    /// @inheritdoc IUniswapV2
    function uniswapV2GetAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    )
        external
        pure
        override
        returns (uint256 amountOut)
    {
        return _uniswapV2GetAmountOut(amountIn, reserveIn, reserveOut);
    }

    /// @inheritdoc IUniswapV2
    function uniswapV2GetAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    )
        external
        pure
        override
        returns (uint256 amountIn)
    {
        return _uniswapV2GetAmountIn(amountOut, reserveIn, reserveOut);
    }

    /// @inheritdoc IUniswapV2
    function uniswapV2GetAmountsOut(
        uint256 amountIn,
        address[] calldata path
    )
        external
        view
        override
        returns (uint256[] memory amounts)
    {
        return _uniswapV2GetAmountsOut(amountIn, path);
    }

    /// @inheritdoc IUniswapV2
    function uniswapV2GetAmountsIn(
        uint256 amountOut,
        address[] calldata path
    )
        external
        view
        override
        returns (uint256[] memory amounts)
    {
        return _uniswapV2GetAmountsIn(amountOut, path);
    }

    /// @inheritdoc IUniswapV2
    function uniswapV2Quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    )
        external
        pure
        override
        returns (uint256 amountB)
    {
        return _uniswapV2Quote(amountA, reserveA, reserveB);
    }

    /// @inheritdoc IUniswapV2
    function uniswapV2QuoteExactInputForPool(
        address poolAddress,
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    )
        external
        view
        override
        returns (uint256 amountOut)
    {
        return _uniswapV2QuoteExactInputForPool(poolAddress, amountIn, tokenIn, tokenOut);
    }
}
