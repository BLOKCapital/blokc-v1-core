// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    @title UniswapV2Facet
    @author BLOK Capital DAO
    @notice Facet exposing Uniswap V2 swap and quote functions
    @dev This facet provides integration with Uniswap V2 for token swaps and price
         quote queries. All swap operations are protected by owner-only access control.

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

contract UniswapV2Facet is IUniswapV2, UniswapV2Base, Facet {
    using SafeERC20 for IERC20;

    // ========================================================================
    // External Functions (State-Changing)
    // ========================================================================

    /// @notice Swaps an exact amount of input tokens for as many output tokens as possible
    /// @param params Swap parameters including amounts, path, and deadline
    /// @dev Validates all pools in the path are registered, handles token approvals, and executes swap.
    ///      Uses SafeERC20 for secure token operations.
    function swapExactTokensForTokens(SwapExactTokensForTokensParams calldata params)
        external
        override
        onlyGardenOwner
        ifIndexNotConnected
        returns (uint256[] memory amounts)
    {
        return _swapExactTokensForTokens(params);
    }

    /// @notice Swaps tokens for an exact amount of output tokens
    /// @param params Swap parameters including amounts, path, and deadline
    /// @dev Validates all pools in the path are registered, handles token approvals, and executes swap.
    ///      Uses SafeERC20 for secure token operations.
    function swapTokensForExactTokens(SwapTokensForExactTokensParams calldata params)
        external
        override
        onlyGardenOwner
        ifIndexNotConnected
        returns (uint256[] memory amounts)
    {
        return _swapTokensForExactTokens(params);
    }

    /// @notice Swaps an exact amount of ETH for as many output tokens as possible
    /// @param params Swap parameters including amounts, path, and deadline
    /// @dev Validates all pools in the path are registered and executes swap.
    ///      ETH is sent as msg.value.
    function swapExactETHForTokens(SwapExactETHForTokensParams calldata params)
        external
        payable
        override
        onlyGardenOwner
        ifIndexNotConnected
        returns (uint256[] memory amounts)
    {
        return _swapExactETHForTokens(params);
    }

    /// @notice Swaps tokens for an exact amount of ETH
    /// @param params Swap parameters including amounts, path, and deadline
    /// @dev Validates all pools in the path are registered, handles token approvals, and executes swap.
    ///      Uses SafeERC20 for secure token operations.
    function swapTokensForExactETH(SwapTokensForExactETHParams calldata params)
        external
        override
        onlyGardenOwner
        ifIndexNotConnected
        returns (uint256[] memory amounts)
    {
        return _swapTokensForExactETH(params);
    }

    /// @notice Swaps an exact amount of tokens for as much ETH as possible
    /// @param params Swap parameters including amounts, path, and deadline
    /// @dev Validates all pools in the path are registered, handles token approvals, and executes swap.
    ///      Uses SafeERC20 for secure token operations.
    function swapExactTokensForETH(SwapExactTokensForETHParams calldata params)
        external
        override
        onlyGardenOwner
        ifIndexNotConnected
        returns (uint256[] memory amounts)
    {
        return _swapExactTokensForETH(params);
    }

    /// @notice Swaps ETH for an exact amount of output tokens
    /// @param params Swap parameters including amounts, path, and deadline
    /// @dev Validates all pools in the path are registered and executes swap.
    ///      ETH is sent as msg.value.
    function swapETHForExactTokens(SwapETHForExactTokensParams calldata params)
        external
        payable
        override
        onlyGardenOwner
        ifIndexNotConnected
        returns (uint256[] memory amounts)
    {
        return _swapETHForExactTokens(params);
    }

    /// @notice Swaps an exact amount of input tokens for as many output tokens as possible, supporting fee-on-transfer tokens
    /// @param params Swap parameters including amounts, path, and deadline
    /// @dev Validates all pools in the path are registered, handles token approvals, and executes swap.
    ///      Uses SafeERC20 for secure token operations. Suitable for tokens with transfer fees.
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        SwapExactTokensForTokensSupportingFeeOnTransferTokensParams calldata params
    ) external override onlyGardenOwner ifIndexNotConnected {
        _swapExactTokensForTokensSupportingFeeOnTransferTokens(params);
    }

    /// @notice Swaps an exact amount of ETH for as many output tokens as possible, supporting fee-on-transfer tokens
    /// @param params Swap parameters including amounts, path, and deadline
    /// @dev Validates all pools in the path are registered and executes swap.
    ///      ETH is sent as msg.value. Suitable for tokens with transfer fees.
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        SwapExactETHForTokensSupportingFeeOnTransferTokensParams calldata params
    ) external payable override onlyGardenOwner ifIndexNotConnected {
        _swapExactETHForTokensSupportingFeeOnTransferTokens(params);
    }

    /// @notice Swaps an exact amount of tokens for as much ETH as possible, supporting fee-on-transfer tokens
    /// @param params Swap parameters including amounts, path, and deadline
    /// @dev Validates all pools in the path are registered, handles token approvals, and executes swap.
    ///      Uses SafeERC20 for secure token operations. Suitable for tokens with transfer fees.
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        SwapExactTokensForETHSupportingFeeOnTransferTokensParams calldata params
    ) external override onlyGardenOwner ifIndexNotConnected {
        _swapExactTokensForETHSupportingFeeOnTransferTokens(params);
    }

    // ========================================================================
    // External Functions (View)
    // ========================================================================

    /// @notice Given an input amount and reserves, returns the maximum output amount
    /// @param amountIn Amount of input token
    /// @param reserveIn Reserve of input token in the pair
    /// @param reserveOut Reserve of output token in the pair
    /// @return amountOut Maximum output amount
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        override
        returns (uint256 amountOut)
    {
        return _getAmountOut(amountIn, reserveIn, reserveOut);
    }

    /// @notice Given an output amount and reserves, returns a required input amount
    /// @param amountOut Amount of output token
    /// @param reserveIn Reserve of input token in the pair
    /// @param reserveOut Reserve of output token in the pair
    /// @return amountIn Required input amount
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        override
        returns (uint256 amountIn)
    {
        return _getAmountIn(amountOut, reserveIn, reserveOut);
    }

    /// @notice Returns the amount of output tokens for a given input amount along a path
    /// @param amountIn Amount of input token
    /// @param path Array of token addresses representing the swap path
    /// @return amounts Array of output amounts for each step in the path
    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        override
        returns (uint256[] memory amounts)
    {
        return _getAmountsOut(amountIn, path);
    }

    /// @notice Returns the amount of input tokens required for a given output amount along a path
    /// @param amountOut Amount of output token
    /// @param path Array of token addresses representing the swap path
    /// @return amounts Array of input amounts for each step in the path
    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        override
        returns (uint256[] memory amounts)
    {
        return _getAmountsIn(amountOut, path);
    }

    /// @notice Given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    /// @param amountA Amount of token A
    /// @param reserveA Reserve of token A in the pair
    /// @param reserveB Reserve of token B in the pair
    /// @return amountB Equivalent amount of token B
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB)
        external
        pure
        override
        returns (uint256 amountB)
    {
        return _quote(amountA, reserveA, reserveB);
    }
}
