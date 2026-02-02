// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    @title UniswapV2Base
    @author BLOK Capital DAO
    @notice Base contract exposing Uniswap V2 swap and quote functions
    @dev This base contract provides integration with Uniswap V2 for token swaps and
         quote calculations.

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
import { IPoolRegistry } from "src/interfaces/IPoolRegistry.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when contract has insufficient token balance
error UniswapV2Facet_InsufficientBalance();

/// @notice Thrown when token approval fails
error UniswapV2Facet_ApprovalFailed();

/// @notice Thrown when pool is not registered in the PoolRegistry
error UniswapV2Facet_UnregisteredPool();

/// @notice Thrown when swap deadline has already passed
error UniswapV2Facet_SwapDeadlineHasPassed();

/// @notice Thrown when swap path is invalid
error UniswapV2Facet_InvalidPath();

/// @notice Thrown when swap amount is zero
error UniswapV2Facet_InvalidAmount();

/// @notice Thrown when router address is zero
error UniswapV2Facet_InvalidRouterAddress();

/// @notice Thrown when token address is zero
error UniswapV2Facet_InvalidTokenAddress();

/// @notice Thrown when ETH value sent is insufficient
error UniswapV2Facet_InsufficientETHValue();

// ============================================================================
// UniswapV2Base
// ============================================================================

/// @title UniswapV2Base
/// @notice Base contract providing Uniswap V2 integration for swaps and quote queries
/// @dev This base contract provides integration with Uniswap V2 for token swaps and
///      quote calculations.
abstract contract UniswapV2Base {
    using SafeERC20 for IERC20;

    // ========================================================================
    // Constants
    // ========================================================================

    /// @notice Uniswap V2 Router02 address on Arbitrum One
    address internal constant UNISWAP_V2_ROUTER_ADDRESS = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    /// @notice Pool Registry address on Arbitrum One
    address internal constant POOL_REGISTRY_ADDRESS = 0xBa7898DbE9C2be340197e1fffe85FC5a3B977744;

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
    // Internal Swap Functions
    // ========================================================================

    /// @notice Uniswap V2 base exact input token-to-token swap
    /// @param params Swap parameters including amounts, path, and deadline
    /// @dev Validates all pools in the path are registered, handles approvals, and executes swap
    function _swapExactTokensForTokens(IUniswapV2.SwapExactTokensForTokensParams memory params)
        internal
        returns (uint256[] memory amounts)
    {
        if (params.amountIn == 0) revert UniswapV2Facet_InvalidAmount();
        if (params.path.length < 2) revert UniswapV2Facet_InvalidPath();
        if (block.timestamp > params.deadline) revert UniswapV2Facet_SwapDeadlineHasPassed();

        // Validate all pools in path
        _validatePath(params.path);

        IUniswapV2Router02 router = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDRESS);
        IERC20 tokenIn = IERC20(params.path[0]);

        // Approve router to spend tokens
        tokenIn.approve(UNISWAP_V2_ROUTER_ADDRESS, params.amountIn);

        // Execute swap
        amounts = router.swapExactTokensForTokens(
            params.amountIn, params.amountOutMin, params.path, params.to, params.deadline
        );

        emit UniswapV2FacetTokensSwapped(params.path[0], params.path[params.path.length - 1], amounts[0], amounts[amounts.length - 1]);
    }

    /// @notice Uniswap V2 base exact output token-to-token swap
    /// @param params Swap parameters including amounts, path, and deadline
    /// @dev Validates all pools in the path are registered, handles approvals, and executes swap
    function _swapTokensForExactTokens(IUniswapV2.SwapTokensForExactTokensParams memory params)
        internal
        returns (uint256[] memory amounts)
    {
        if (params.amountOut == 0) revert UniswapV2Facet_InvalidAmount();
        if (params.path.length < 2) revert UniswapV2Facet_InvalidPath();
        if (block.timestamp > params.deadline) revert UniswapV2Facet_SwapDeadlineHasPassed();

        // Validate all pools in path
        _validatePath(params.path);

        IUniswapV2Router02 router = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDRESS);
        IERC20 tokenIn = IERC20(params.path[0]);

        // Approve router to spend tokens
        tokenIn.forceApprove(UNISWAP_V2_ROUTER_ADDRESS, params.amountInMax);

        // Execute swap
        amounts = router.swapTokensForExactTokens(
            params.amountOut, params.amountInMax, params.path, params.to, params.deadline
        );

        emit UniswapV2FacetTokensSwapped(params.path[0], params.path[params.path.length - 1], amounts[0], amounts[amounts.length - 1]);
    }

    /// @notice Uniswap V2 base exact input ETH-to-token swap
    /// @param params Swap parameters including amounts, path, and deadline
    /// @dev Validates all pools in the path are registered and executes swap
    function _swapExactETHForTokens(IUniswapV2.SwapExactETHForTokensParams memory params)
        internal
        returns (uint256[] memory amounts)
    {
        if (params.path.length < 2) revert UniswapV2Facet_InvalidPath();
        if (block.timestamp > params.deadline) revert UniswapV2Facet_SwapDeadlineHasPassed();

        IUniswapV2Router02 router = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDRESS);

        // Validate path starts with WETH
        if (params.path[0] != router.WETH()) revert UniswapV2Facet_InvalidPath();

        // Validate all pools in path
        _validatePath(params.path);

        // Execute swap with ETH value
        amounts = router.swapExactETHForTokens{ value: msg.value }(
            params.amountOutMin, params.path, params.to, params.deadline
        );

        emit UniswapV2FacetTokensSwapped(params.path[0], params.path[params.path.length - 1], amounts[0], amounts[amounts.length - 1]);
    }

    /// @notice Uniswap V2 base exact output token-to-ETH swap
    /// @param params Swap parameters including amounts, path, and deadline
    /// @dev Validates all pools in the path are registered, handles approvals, and executes swap
    function _swapTokensForExactETH(IUniswapV2.SwapTokensForExactETHParams memory params)
        internal
        returns (uint256[] memory amounts)
    {
        if (params.amountOut == 0) revert UniswapV2Facet_InvalidAmount();
        if (params.path.length < 2) revert UniswapV2Facet_InvalidPath();
        if (block.timestamp > params.deadline) revert UniswapV2Facet_SwapDeadlineHasPassed();

        IUniswapV2Router02 router = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDRESS);

        // Validate path ends with WETH
        if (params.path[params.path.length - 1] != router.WETH()) revert UniswapV2Facet_InvalidPath();

        // Validate all pools in path
        _validatePath(params.path);

        IERC20 tokenIn = IERC20(params.path[0]);

        // Approve router to spend tokens
        tokenIn.forceApprove(UNISWAP_V2_ROUTER_ADDRESS, params.amountInMax);

        // Execute swap
        amounts = router.swapTokensForExactETH(
            params.amountOut, params.amountInMax, params.path, params.to, params.deadline
        );

        emit UniswapV2FacetTokensSwapped(params.path[0], params.path[params.path.length - 1], amounts[0], amounts[amounts.length - 1]);
    }

    /// @notice Uniswap V2 base exact input token-to-ETH swap
    /// @param params Swap parameters including amounts, path, and deadline
    /// @dev Validates all pools in the path are registered, handles approvals, and executes swap
    function _swapExactTokensForETH(IUniswapV2.SwapExactTokensForETHParams memory params)
        internal
        returns (uint256[] memory amounts)
    {
        if (params.amountIn == 0) revert UniswapV2Facet_InvalidAmount();
        if (params.path.length < 2) revert UniswapV2Facet_InvalidPath();
        if (block.timestamp > params.deadline) revert UniswapV2Facet_SwapDeadlineHasPassed();

        IUniswapV2Router02 router = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDRESS);

        // Validate path ends with WETH
        if (params.path[params.path.length - 1] != router.WETH()) revert UniswapV2Facet_InvalidPath();

        // Validate all pools in path
        _validatePath(params.path);

        IERC20 tokenIn = IERC20(params.path[0]);

        // Approve router to spend tokens
        tokenIn.forceApprove(UNISWAP_V2_ROUTER_ADDRESS, params.amountIn);

        // Execute swap
        amounts = router.swapExactTokensForETH(
            params.amountIn, params.amountOutMin, params.path, params.to, params.deadline
        );

        emit UniswapV2FacetTokensSwapped(params.path[0], params.path[params.path.length - 1], amounts[0], amounts[amounts.length - 1]);
    }

    /// @notice Uniswap V2 base exact output ETH-to-token swap
    /// @param params Swap parameters including amounts, path, and deadline
    /// @dev Validates all pools in the path are registered and executes swap
    function _swapETHForExactTokens(IUniswapV2.SwapETHForExactTokensParams memory params)
        internal
        returns (uint256[] memory amounts)
    {
        if (params.amountOut == 0) revert UniswapV2Facet_InvalidAmount();
        if (params.path.length < 2) revert UniswapV2Facet_InvalidPath();
        if (block.timestamp > params.deadline) revert UniswapV2Facet_SwapDeadlineHasPassed();

        IUniswapV2Router02 router = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDRESS);

        // Validate path starts with WETH
        if (params.path[0] != router.WETH()) revert UniswapV2Facet_InvalidPath();

        // Validate all pools in path
        _validatePath(params.path);

        // Execute swap with ETH value
        amounts = router.swapETHForExactTokens{ value: msg.value }(
            params.amountOut, params.path, params.to, params.deadline
        );

        emit UniswapV2FacetTokensSwapped(params.path[0], params.path[params.path.length - 1], amounts[0], amounts[amounts.length - 1]);
    }

    /// @notice Uniswap V2 base exact input token-to-token swap supporting fee-on-transfer tokens
    /// @param params Swap parameters including amounts, path, and deadline
    /// @dev Validates all pools in the path are registered, handles approvals, and executes swap
    function _swapExactTokensForTokensSupportingFeeOnTransferTokens(
        IUniswapV2.SwapExactTokensForTokensSupportingFeeOnTransferTokensParams memory params
    ) internal {
        if (params.amountIn == 0) revert UniswapV2Facet_InvalidAmount();
        if (params.path.length < 2) revert UniswapV2Facet_InvalidPath();
        if (block.timestamp > params.deadline) revert UniswapV2Facet_SwapDeadlineHasPassed();

        // Validate all pools in path
        _validatePath(params.path);

        IUniswapV2Router02 router = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDRESS);
        IERC20 tokenIn = IERC20(params.path[0]);

        // Approve router to spend tokens
        tokenIn.forceApprove(UNISWAP_V2_ROUTER_ADDRESS, params.amountIn);

        // Execute swap
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            params.amountIn, params.amountOutMin, params.path, params.to, params.deadline
        );

        emit UniswapV2FacetTokensSwapped(params.path[0], params.path[params.path.length - 1], params.amountIn, 0);
    }

    /// @notice Uniswap V2 base exact input ETH-to-token swap supporting fee-on-transfer tokens
    /// @param params Swap parameters including amounts, path, and deadline
    /// @dev Validates all pools in the path are registered and executes swap
    function _swapExactETHForTokensSupportingFeeOnTransferTokens(
        IUniswapV2.SwapExactETHForTokensSupportingFeeOnTransferTokensParams memory params
    ) internal {
        if (params.path.length < 2) revert UniswapV2Facet_InvalidPath();
        if (block.timestamp > params.deadline) revert UniswapV2Facet_SwapDeadlineHasPassed();

        IUniswapV2Router02 router = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDRESS);

        // Validate path starts with WETH
        if (params.path[0] != router.WETH()) revert UniswapV2Facet_InvalidPath();

        // Validate all pools in path
        _validatePath(params.path);

        // Execute swap with ETH value
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{ value: msg.value }(
            params.amountOutMin, params.path, params.to, params.deadline
        );

        emit UniswapV2FacetTokensSwapped(params.path[0], params.path[params.path.length - 1], msg.value, 0);
    }

    /// @notice Uniswap V2 base exact input token-to-ETH swap supporting fee-on-transfer tokens
    /// @param params Swap parameters including amounts, path, and deadline
    /// @dev Validates all pools in the path are registered, handles approvals, and executes swap
    function _swapExactTokensForETHSupportingFeeOnTransferTokens(
        IUniswapV2.SwapExactTokensForETHSupportingFeeOnTransferTokensParams memory params
    ) internal {
        if (params.amountIn == 0) revert UniswapV2Facet_InvalidAmount();
        if (params.path.length < 2) revert UniswapV2Facet_InvalidPath();
        if (block.timestamp > params.deadline) revert UniswapV2Facet_SwapDeadlineHasPassed();

        IUniswapV2Router02 router = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDRESS);

        // Validate path ends with WETH
        if (params.path[params.path.length - 1] != router.WETH()) revert UniswapV2Facet_InvalidPath();

        // Validate all pools in path
        _validatePath(params.path);

        IERC20 tokenIn = IERC20(params.path[0]);

        // Approve router to spend tokens
        tokenIn.forceApprove(UNISWAP_V2_ROUTER_ADDRESS, params.amountIn);

        // Execute swap
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            params.amountIn, params.amountOutMin, params.path, params.to, params.deadline
        );

        emit UniswapV2FacetTokensSwapped(params.path[0], params.path[params.path.length - 1], params.amountIn, 0);
    }

    // ========================================================================
    // Internal View Functions
    // ========================================================================

    /// @notice Returns the amount of output tokens for a given input amount along a path
    /// @param amountIn Amount of input token
    /// @param path Array of token addresses representing the swap path
    /// @return amounts Array of output amounts for each step in the path
    function _getAmountsOut(uint256 amountIn, address[] memory path)
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
    function _getAmountsIn(uint256 amountOut, address[] memory path)
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
    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
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
    function _getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountIn)
    {
        IUniswapV2Router02 router = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDRESS);
        amountIn = router.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    /// @notice Given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    /// @param amountA Amount of token A
    /// @param reserveA Reserve of token A in the pair
    /// @param reserveB Reserve of token B in the pair
    /// @return amountB Equivalent amount of token B
    function _quote(uint256 amountA, uint256 reserveA, uint256 reserveB)
        internal
        pure
        returns (uint256 amountB)
    {
        IUniswapV2Router02 router = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDRESS);
        amountB = router.quote(amountA, reserveA, reserveB);
    }

    // ========================================================================
    // Internal Helper Functions
    // ========================================================================

    /// @notice Validates that all pools in a path exist and are registered
    /// @param path Array of token addresses representing the swap path
    function _validatePath(address[] memory path) internal view {
        for (uint256 i = 0; i < path.length - 1; ++i) {
            address tokenA = path[i];
            address tokenB = path[i + 1];

            if (tokenA == address(0) || tokenB == address(0)) {
                revert UniswapV2Facet_InvalidTokenAddress();
            }

            // Validate pool exists and is registered
            bytes32 poolId = keccak256(abi.encode(tokenA, tokenB));
            address pool = IPoolRegistry(POOL_REGISTRY_ADDRESS).poolAddressById(poolId);
            if (pool == address(0) || !IPoolRegistry(POOL_REGISTRY_ADDRESS).isPoolRegistered(pool)) {
                revert UniswapV2Facet_UnregisteredPool();
            }
        }
    }
}
