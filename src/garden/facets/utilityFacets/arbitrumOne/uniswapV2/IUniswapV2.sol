// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    @title IUniswapV2
    @author BLOK Capital DAO
    @notice Interface for Uniswap V2 integration (swaps and quote functions)
    @dev This interface provides functions for executing token swaps on Uniswap V2
         and querying quote/amount calculations.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

interface IUniswapV2 {
    // ========================================================================
    // Structs
    // ========================================================================

    /// @notice Parameters for exact-input token-to-token swap
    /// @param amountIn Amount of input token to swap
    /// @param amountOutMin Minimum acceptable output amount (slippage protection)
    /// @param path Array of token addresses representing the swap path
    /// @param to Recipient address for the output tokens
    /// @param deadline Unix timestamp after which the swap is invalid
    struct UniswapV2SwapExactTokensForTokensParams {
        uint256 amountIn;
        uint256 amountOutMin;
        address[] path;
        address to;
        uint256 deadline;
    }

    /// @notice Parameters for exact-output token-to-token swap
    /// @param amountOut Amount of output token desired
    /// @param amountInMax Maximum acceptable input amount (slippage protection)
    /// @param path Array of token addresses representing the swap path
    /// @param to Recipient address for the output tokens
    /// @param deadline Unix timestamp after which the swap is invalid
    struct UniswapV2SwapTokensForExactTokensParams {
        uint256 amountOut;
        uint256 amountInMax;
        address[] path;
        address to;
        uint256 deadline;
    }

    /// @notice Parameters for exact-input ETH-to-token swap
    /// @param amountOutMin Minimum acceptable output amount (slippage protection)
    /// @param path Array of token addresses representing the swap path
    /// @param to Recipient address for the output tokens
    /// @param deadline Unix timestamp after which the swap is invalid
    struct UniswapV2SwapExactETHForTokensParams {
        uint256 amountOutMin;
        address[] path;
        address to;
        uint256 deadline;
    }

    /// @notice Parameters for exact-output token-to-ETH swap
    /// @param amountOut Amount of ETH desired
    /// @param amountInMax Maximum acceptable input token amount (slippage protection)
    /// @param path Array of token addresses representing the swap path
    /// @param to Recipient address for the ETH
    /// @param deadline Unix timestamp after which the swap is invalid
    struct UniswapV2SwapTokensForExactETHParams {
        uint256 amountOut;
        uint256 amountInMax;
        address[] path;
        address to;
        uint256 deadline;
    }

    /// @notice Parameters for exact-input token-to-ETH swap
    /// @param amountIn Amount of input token to swap
    /// @param amountOutMin Minimum acceptable ETH output (slippage protection)
    /// @param path Array of token addresses representing the swap path
    /// @param to Recipient address for the ETH
    /// @param deadline Unix timestamp after which the swap is invalid
    struct UniswapV2SwapExactTokensForETHParams {
        uint256 amountIn;
        uint256 amountOutMin;
        address[] path;
        address to;
        uint256 deadline;
    }

    /// @notice Parameters for exact-output ETH-to-token swap
    /// @param amountOut Amount of output token desired
    /// @param path Array of token addresses representing the swap path
    /// @param to Recipient address for the output tokens
    /// @param deadline Unix timestamp after which the swap is invalid
    struct UniswapV2SwapETHForExactTokensParams {
        uint256 amountOut;
        address[] path;
        address to;
        uint256 deadline;
    }

    /// @notice Parameters for exact-input token-to-token swap supporting fee-on-transfer tokens
    /// @param amountIn Amount of input token to swap
    /// @param amountOutMin Minimum acceptable output amount (slippage protection)
    /// @param path Array of token addresses representing the swap path
    /// @param to Recipient address for the output tokens
    /// @param deadline Unix timestamp after which the swap is invalid
    struct UniswapV2SwapExactTokensForTokensSupportingFeeOnTransferTokensParams {
        uint256 amountIn;
        uint256 amountOutMin;
        address[] path;
        address to;
        uint256 deadline;
    }

    /// @notice Parameters for exact-input ETH-to-token swap supporting fee-on-transfer tokens
    /// @param amountOutMin Minimum acceptable output amount (slippage protection)
    /// @param path Array of token addresses representing the swap path
    /// @param to Recipient address for the output tokens
    /// @param deadline Unix timestamp after which the swap is invalid
    struct UniswapV2SwapExactETHForTokensSupportingFeeOnTransferTokensParams {
        uint256 amountOutMin;
        address[] path;
        address to;
        uint256 deadline;
    }

    /// @notice Parameters for exact-input token-to-ETH swap supporting fee-on-transfer tokens
    /// @param amountIn Amount of input token to swap
    /// @param amountOutMin Minimum acceptable ETH output (slippage protection)
    /// @param path Array of token addresses representing the swap path
    /// @param to Recipient address for the ETH
    /// @param deadline Unix timestamp after which the swap is invalid
    struct UniswapV2SwapExactTokensForETHSupportingFeeOnTransferTokensParams {
        uint256 amountIn;
        uint256 amountOutMin;
        address[] path;
        address to;
        uint256 deadline;
    }

    // ========================================================================
    // Functions
    // ========================================================================

    /// @notice Swaps an exact amount of input tokens for as many output tokens as possible
    /// @dev All pools in the path must be registered in the PoolRegistry
    /// @param params Swap parameters including amounts, path, and deadline
    /// @return amounts Array of input and output amounts for each step in the path
    function uniswapV2SwapExactTokensForTokens(UniswapV2SwapExactTokensForTokensParams calldata params)
        external
        returns (uint256[] memory amounts);

    /// @notice Swaps tokens for an exact amount of output tokens
    /// @dev All pools in the path must be registered in the PoolRegistry
    /// @param params Swap parameters including amounts, path, and deadline
    /// @return amounts Array of input and output amounts for each step in the path
    function uniswapV2SwapTokensForExactTokens(UniswapV2SwapTokensForExactTokensParams calldata params)
        external
        returns (uint256[] memory amounts);

    /// @notice Swaps an exact amount of ETH for as many output tokens as possible
    /// @dev All pools in the path must be registered in the PoolRegistry
    /// @param params Swap parameters including amounts, path, and deadline
    /// @return amounts Array of input and output amounts for each step in the path
    function uniswapV2SwapExactETHForTokens(UniswapV2SwapExactETHForTokensParams calldata params)
        external
        payable
        returns (uint256[] memory amounts);

    /// @notice Swaps tokens for an exact amount of ETH
    /// @dev All pools in the path must be registered in the PoolRegistry
    /// @param params Swap parameters including amounts, path, and deadline
    /// @return amounts Array of input and output amounts for each step in the path
    function uniswapV2SwapTokensForExactETH(UniswapV2SwapTokensForExactETHParams calldata params)
        external
        returns (uint256[] memory amounts);

    /// @notice Swaps an exact amount of tokens for as much ETH as possible
    /// @dev All pools in the path must be registered in the PoolRegistry
    /// @param params Swap parameters including amounts, path, and deadline
    /// @return amounts Array of input and output amounts for each step in the path
    function uniswapV2SwapExactTokensForETH(UniswapV2SwapExactTokensForETHParams calldata params)
        external
        returns (uint256[] memory amounts);

    /// @notice Swaps ETH for an exact amount of output tokens
    /// @dev All pools in the path must be registered in the PoolRegistry
    /// @param params Swap parameters including amounts, path, and deadline
    /// @return amounts Array of input and output amounts for each step in the path
    function uniswapV2SwapETHForExactTokens(UniswapV2SwapETHForExactTokensParams calldata params)
        external
        payable
        returns (uint256[] memory amounts);

    /// @notice Swaps an exact amount of input tokens for as many output tokens as possible, supporting fee-on-transfer
    /// tokens @dev All pools in the path must be registered in the PoolRegistry
    /// @param params Swap parameters including amounts, path, and deadline
    function uniswapV2SwapExactTokensForTokensSupportingFeeOnTransferTokens(UniswapV2SwapExactTokensForTokensSupportingFeeOnTransferTokensParams calldata params)
        external;

    /// @notice Swaps an exact amount of ETH for as many output tokens as possible, supporting fee-on-transfer tokens
    /// @dev All pools in the path must be registered in the PoolRegistry
    /// @param params Swap parameters including amounts, path, and deadline
    function uniswapV2SwapExactETHForTokensSupportingFeeOnTransferTokens(UniswapV2SwapExactETHForTokensSupportingFeeOnTransferTokensParams calldata params)
        external
        payable;

    /// @notice Swaps an exact amount of tokens for as much ETH as possible, supporting fee-on-transfer tokens
    /// @dev All pools in the path must be registered in the PoolRegistry
    /// @param params Swap parameters including amounts, path, and deadline
    function uniswapV2SwapExactTokensForETHSupportingFeeOnTransferTokens(UniswapV2SwapExactTokensForETHSupportingFeeOnTransferTokensParams calldata params)
        external;

    // ========================================================================
    // View Functions
    // ========================================================================

    /// @notice Given an input amount and reserves, returns the maximum output amount
    /// @param amountIn Amount of input token
    /// @param reserveIn Reserve of input token in the pair
    /// @param reserveOut Reserve of output token in the pair
    /// @return amountOut Maximum output amount
    function uniswapV2GetAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    )
        external
        pure
        returns (uint256 amountOut);

    /// @notice Given an output amount and reserves, returns a required input amount
    /// @param amountOut Amount of output token
    /// @param reserveIn Reserve of input token in the pair
    /// @param reserveOut Reserve of output token in the pair
    /// @return amountIn Required input amount
    function uniswapV2GetAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    )
        external
        pure
        returns (uint256 amountIn);

    /// @notice Returns the amount of output tokens for a given input amount along a path
    /// @param amountIn Amount of input token
    /// @param path Array of token addresses representing the swap path
    /// @return amounts Array of output amounts for each step in the path
    function uniswapV2GetAmountsOut(
        uint256 amountIn,
        address[] calldata path
    )
        external
        view
        returns (uint256[] memory amounts);

    /// @notice Returns the amount of input tokens required for a given output amount along a path
    /// @param amountOut Amount of output token
    /// @param path Array of token addresses representing the swap path
    /// @return amounts Array of input amounts for each step in the path
    function uniswapV2GetAmountsIn(
        uint256 amountOut,
        address[] calldata path
    )
        external
        view
        returns (uint256[] memory amounts);

    /// @notice Given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    /// @param amountA Amount of token A
    /// @param reserveA Reserve of token A in the pair
    /// @param reserveB Reserve of token B in the pair
    /// @return amountB Equivalent amount of token B
    function uniswapV2Quote(uint256 amountA, uint256 reserveA, uint256 reserveB) external pure returns (uint256 amountB);
}
