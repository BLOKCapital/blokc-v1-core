// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

// Local Interfaces
import { IUniswapV2 } from "src/garden/facets/utilityFacets/ethereum/uniswapV2/IUniswapV2.sol";

// Local Libraries
import { UniswapV2Base } from "src/garden/facets/utilityFacets/ethereum/uniswapV2/UniswapV2Base.sol";
import { Facet } from "src/garden/facets/Facet.sol";
import { SwapInstruction, QuoteInstruction } from "src/interfaces/ISwapInstruction.sol";

/**
 * @title UniswapV2Facet
 * @author Blok Capital DAO
 * @notice Facet that implements the IUniswapV2 interface to allow swapping tokens through the Uniswap V2 router on
 * Ethereum Mainnet. This facet provides external functions for garden owners to perform token swaps using Uniswap V2,
 * with appropriate access control and user-facing error messages. It inherits from UniswapV2Base which contains the
 * internal logic for interacting with Uniswap V2, while UniswapV2Facet itself provides the external interface for
 * these operations.
 */
contract UniswapV2Facet is IUniswapV2, UniswapV2Base, Facet {
    // ========================================================================
    // External Functions
    // ========================================================================

    /// @inheritdoc IUniswapV2
    function uniswapV2Swap(SwapInstruction calldata instruction)
        external
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
    {
        _uniswapV2Swap(instruction);
    }

    // ========================================================================
    // External Functions (View)
    // ========================================================================

    /// @inheritdoc IUniswapV2
    function uniswapV2Quote(QuoteInstruction calldata instruction) external view override returns (uint256 result) {
        return _uniswapV2Quote(instruction);
    }

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
}
