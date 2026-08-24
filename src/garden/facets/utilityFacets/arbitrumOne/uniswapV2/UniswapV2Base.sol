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

// Uniswap V2 Contracts
import { IUniswapV2Router02 } from "v2-periphery/interfaces/IUniswapV2Router02.sol";
// Local Interfaces
import { IUniswapV2 } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV2/IUniswapV2.sol";
import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";
import { SwapInstruction, QuoteInstruction } from "src/interfaces/ISwapInstruction.sol";
import { DexPoolValidator } from "src/garden/libraries/DexPoolValidator.sol";
import { ArbitrumOneAddresses } from "src/garden/libraries/ArbitrumOneAddresses.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when pool is not registered in the PoolRegistry
error UniswapV2Facet_UnregisteredPool();

/// @notice Thrown when pool address is invalid (zero address)
error UniswapV2Facet_InvalidPoolAddress();

/// @notice Thrown when swap path is invalid
error UniswapV2Facet_InvalidPath();

/**
 * @title UniswapV2Base
 * @author BLOK Capital DAO
 * @notice Base contract that implements internal functions for swapping tokens through the Uniswap V2 router on
 * Arbitrum One. This contract is intended to be inherited by a UniswapV2Facet that exposes the swap functions with
 * appropriate access control and user-facing error messages. It includes the core logic for interacting with the
 * Uniswap V2 router to perform token swaps, along with events for off-chain tracking of these operations.
 */
abstract contract UniswapV2Base {
    using SafeERC20 for IERC20;

    // ========================================================================
    // Constants
    // ========================================================================

    /// @notice Uniswap V2 Router02 address on Arbitrum One
    address internal constant UNISWAP_V2_ROUTER_ADDRESS = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    /// @notice Pool Registry address on Arbitrum One
    address public constant POOL_REGISTRY_ADDRESS = ArbitrumOneAddresses.POOL_REGISTRY_ADDRESS;
    /// @notice Uniswap V2 Factory address on Arbitrum One
    address internal constant UNISWAP_V2_FACTORY_ADDRESS = 0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9;

    // ========================================================================
    // Events
    // ========================================================================

    /// @notice Emitted when tokens are swapped on Uniswap V2
    /// @param tokenIn The input token address
    /// @param tokenOut The output token address
    /// @param amountIn The input amount
    /// @param amountOut The output amount received
    event UniswapV2FacetTokensSwapped(
        address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
    );

    // ========================================================================
    // Internal Swap Dispatcher
    // ========================================================================

    /// @notice Standardised swap dispatcher for the rebalance flow.
    ///         Validates pools upfront, then delegates to the appropriate internal helper.
    /// @param instruction The universal SwapInstruction
    function _uniswapV2Swap(SwapInstruction calldata instruction) internal {
        uint256 hops = instruction.pools.length;
        if (hops == 0 || instruction.tokens.length != hops + 1) revert UniswapV2Facet_InvalidPath();

        // Validate all pools upfront: registered in PoolRegistry + canonical in Uniswap factory
        _validateSwapPools(instruction);

        if (!instruction.exactOutput) {
            // Exact input: use swapExactTokensForTokens
            _uniswapV2SwapExactTokensForTokens(
                IUniswapV2.UniswapV2SwapExactTokensForTokensParams({
                    amountIn: instruction.amountIn,
                    amountOutMin: instruction.amountOut,
                    path: instruction.tokens,
                    to: address(this),
                    deadline: instruction.deadline == 0 ? block.timestamp + 30 minutes : instruction.deadline
                })
            );
        } else {
            // Exact output: use swapTokensForExactTokens
            _uniswapV2SwapTokensForExactTokens(
                IUniswapV2.UniswapV2SwapTokensForExactTokensParams({
                    amountOut: instruction.amountOut,
                    amountInMax: instruction.amountIn,
                    path: instruction.tokens,
                    to: address(this),
                    deadline: instruction.deadline == 0 ? block.timestamp + 30 minutes : instruction.deadline
                })
            );
        }
    }

    // ========================================================================
    // Internal Quote Dispatcher
    // ========================================================================

    /// @notice Unified quote dispatcher. Uses router's getAmountsOut / getAmountsIn.
    /// @param instruction The QuoteInstruction describing the path and direction
    /// @return result exactOutput=false: estimated output. exactOutput=true: estimated input needed.
    function _uniswapV2Quote(QuoteInstruction calldata instruction) internal view returns (uint256 result) {
        uint256 hops = instruction.pools.length;
        if (hops == 0 || instruction.tokens.length != hops + 1) revert UniswapV2Facet_InvalidPath();

        // Validate all pools are registered
        for (uint256 i; i < hops; i++) {
            if (instruction.pools[i] == address(0)) revert UniswapV2Facet_InvalidPoolAddress();
            if (!ILiquidityPoolRegistry(POOL_REGISTRY_ADDRESS).isPoolRegistered(instruction.pools[i])) {
                revert UniswapV2Facet_UnregisteredPool();
            }
        }

        IUniswapV2Router02 router = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDRESS);

        if (!instruction.exactOutput) {
            // Exact input: get expected output
            uint256[] memory amounts = router.getAmountsOut(instruction.amount, instruction.tokens);
            result = amounts[amounts.length - 1];
        } else {
            // Exact output: get required input
            uint256[] memory amounts = router.getAmountsIn(instruction.amount, instruction.tokens);
            result = amounts[0];
        }
    }

    // ========================================================================
    // Internal Swap Functions (helpers — no validation)
    // ========================================================================

    /// @notice Executes an exact-input token-to-token swap via Uniswap V2
    /// @param params Swap parameters including amounts, path, and deadline
    /// @return amounts Array of input and output amounts for each step in the path
    function _uniswapV2SwapExactTokensForTokens(IUniswapV2.UniswapV2SwapExactTokensForTokensParams memory params)
        internal
        returns (uint256[] memory amounts)
    {
        IUniswapV2Router02 router = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDRESS);
        IERC20 tokenIn = IERC20(params.path[0]);

        // Approve router to spend tokens
        tokenIn.forceApprove(UNISWAP_V2_ROUTER_ADDRESS, params.amountIn);

        // Execute swap
        amounts = router.swapExactTokensForTokens(
            params.amountIn, params.amountOutMin, params.path, address(this), params.deadline
        );

        emit UniswapV2FacetTokensSwapped(
            params.path[0], params.path[params.path.length - 1], amounts[0], amounts[amounts.length - 1]
        );
    }

    /// @notice Executes an exact-output token-to-token swap via Uniswap V2
    /// @param params Swap parameters including amounts, path, and deadline
    /// @return amounts Array of input and output amounts for each step in the path
    function _uniswapV2SwapTokensForExactTokens(IUniswapV2.UniswapV2SwapTokensForExactTokensParams memory params)
        internal
        returns (uint256[] memory amounts)
    {
        IUniswapV2Router02 router = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDRESS);
        IERC20 tokenIn = IERC20(params.path[0]);

        // Approve router to spend tokens
        tokenIn.forceApprove(UNISWAP_V2_ROUTER_ADDRESS, params.amountInMax);

        // Execute swap
        amounts = router.swapTokensForExactTokens(
            params.amountOut, params.amountInMax, params.path, address(this), params.deadline
        );

        emit UniswapV2FacetTokensSwapped(
            params.path[0], params.path[params.path.length - 1], amounts[0], amounts[amounts.length - 1]
        );
    }

    // ========================================================================
    // Internal View Functions
    // ========================================================================

    /// @notice Returns the amount of output tokens for a given input amount along a path
    /// @param amountIn Amount of input token
    /// @param path Array of token addresses representing the swap path
    /// @return amounts Array of output amounts for each step in the path
    function _uniswapV2GetAmountsOut(
        uint256 amountIn,
        address[] memory path
    )
        internal
        view
        returns (uint256[] memory amounts)
    {
        if (path.length < 2) revert UniswapV2Facet_InvalidPath();

        IUniswapV2Router02 router = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDRESS);
        amounts = router.getAmountsOut(amountIn, path);
    }

    /// @notice Returns the amount of input tokens required for a given output amount along a path
    /// @param amountOut Amount of output token
    /// @param path Array of token addresses representing the swap path
    /// @return amounts Array of input amounts for each step in the path
    function _uniswapV2GetAmountsIn(
        uint256 amountOut,
        address[] memory path
    )
        internal
        view
        returns (uint256[] memory amounts)
    {
        if (path.length < 2) revert UniswapV2Facet_InvalidPath();

        IUniswapV2Router02 router = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDRESS);
        amounts = router.getAmountsIn(amountOut, path);
    }

    /// @notice Given an input amount and reserves, returns the maximum output amount
    /// @param amountIn Amount of input token
    /// @param reserveIn Reserve of input token in the pair
    /// @param reserveOut Reserve of output token in the pair
    /// @return amountOut Maximum output amount
    function _uniswapV2GetAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    )
        internal
        pure
        returns (uint256 amountOut)
    {
        IUniswapV2Router02 router = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDRESS);
        amountOut = router.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    /// @notice Given an output amount and reserves, returns a required input amount
    /// @param amountOut Amount of output token
    /// @param reserveIn Reserve of input token in the pair
    /// @param reserveOut Reserve of output token in the pair
    /// @return amountIn Required input amount
    function _uniswapV2GetAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    )
        internal
        pure
        returns (uint256 amountIn)
    {
        IUniswapV2Router02 router = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDRESS);
        amountIn = router.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    // ========================================================================
    // Internal Validation Functions
    // ========================================================================

    /// @notice Validates a single V2 pool through the shared DexPoolValidator library
    function _validatePool(address pool, address tokenIn, address tokenOut) internal view {
        DexPoolValidator.validateV2Pool(POOL_REGISTRY_ADDRESS, UNISWAP_V2_FACTORY_ADDRESS, pool, tokenIn, tokenOut);
    }

    /// @notice Validates all pools in a SwapInstruction through DexPoolValidator
    function _validateSwapPools(SwapInstruction calldata instruction) internal view {
        DexPoolValidator.validateSwapPools(POOL_REGISTRY_ADDRESS, UNISWAP_V2_FACTORY_ADDRESS, instruction, false);
    }
}
