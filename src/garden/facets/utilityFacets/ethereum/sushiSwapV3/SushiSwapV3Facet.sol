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
import { ISushiSwapV3 } from "src/garden/facets/utilityFacets/ethereum/sushiSwapV3/ISushiSwapV3.sol";

// Local Libraries
import { SushiSwapV3Base } from "src/garden/facets/utilityFacets/ethereum/sushiSwapV3/SushiSwapV3Base.sol";
import { Facet } from "src/garden/facets/Facet.sol";

/**
 * @title SushiSwapV3Facet
 * @notice Facet for SushiSwap V3 (clAMM) interactions on Ethereum Mainnet.
 * @dev SushiSwap V3 has no SwapRouter — swaps call pool.swap() directly, which triggers
 *      uniswapV3SwapCallback on this contract to pull tokens into the pool mid-swap.
 *      uniswapV3SwapCallback must be registered as a facet selector so the diamond proxy
 *      routes pool callbacks here. It is NOT nonReentrant (called from inside a live swap)
 *      but is secured by verifying msg.sender against the registered pool in callbackData.
 */
contract SushiSwapV3Facet is ISushiSwapV3, SushiSwapV3Base, Facet {
    using SafeERC20 for IERC20;

    // ========================================================================
    // External Functions (Swaps)
    // ========================================================================

    /// @inheritdoc ISushiSwapV3
    function sushiSwapV3ExactInputSingle(SushiSwapV3ExactInputSingleParams memory params)
        external
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
    {
        _sushiSwapV3ExactInputSingle(params);
    }

    /// @inheritdoc ISushiSwapV3
    function sushiSwapV3ExactInput(SushiSwapV3ExactInputParams memory params)
        external
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
    {
        _sushiSwapV3ExactInput(params);
    }

    /// @inheritdoc ISushiSwapV3
    function sushiSwapV3ExactOutputSingle(SushiSwapV3ExactOutputSingleParams memory params)
        external
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
    {
        _sushiSwapV3ExactOutputSingle(params);
    }

    /// @notice Multi-hop exact-output is not supported — use sushiSwapV3ExactInput instead
    /// @dev Reverse-chaining multiple pool.swap() calls for exact output requires reimplementing
    ///      Uniswap's SwapRouter callback chain, which SushiSwap V3 does not provide.
    function sushiSwapV3ExactOutput(SushiSwapV3ExactOutputParams memory) external override {
        revert("SushiSwapV3: multi-hop exactOutput not supported");
    }

    // ========================================================================
    // External Functions (View — TWAP)
    // ========================================================================

    /// @inheritdoc ISushiSwapV3
    function getSushiSqrtTwapX96(
        address sushiSwapV3Pool,
        uint32 twapInterval
    )
        external
        view
        override
        returns (uint160 sqrtPriceX96, uint256 deadline)
    {
        return _getSushiSqrtTwapX96(sushiSwapV3Pool, twapInterval);
    }

    /// @inheritdoc ISushiSwapV3
    function getSushiCombinedTwapX96(
        PoolInfo[] memory pools,
        uint32 twapInterval
    )
        external
        view
        override
        returns (uint256 combinedPriceX96, uint256 deadline)
    {
        return _getSushiCombinedTwapX96(pools, twapInterval);
    }

    /// @inheritdoc ISushiSwapV3
    function sushiSwapV3QuoteExactInputForPool(
        address poolAddress,
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        uint32 twapInterval
    )
        external
        view
        override
        returns (uint256 amountOut)
    {
        return _sushiSwapV3QuoteExactInputForPool(poolAddress, amountIn, tokenIn, tokenOut, twapInterval);
    }

    // ========================================================================
    // Swap Callback (invoked by SushiSwap V3 pools mid-swap)
    // ========================================================================

    /// @notice Called by a SushiSwap V3 pool during pool.swap() to pull owed tokens
    /// @dev Must be registered as a facet selector so the diamond proxy routes pool callbacks here.
    ///      NOT nonReentrant — called from inside an active swap (reentrancy lock already held).
    ///      Security: verifies msg.sender is the exact registered pool encoded in callbackData.
    /// @param amount0Delta Token0 owed to the pool (positive = we pay)
    /// @param amount1Delta Token1 owed to the pool (positive = we pay)
    /// @param data ABI-encoded (address tokenIn, address pool)
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        _handleSushiSwapCallback(amount0Delta, amount1Delta, data);
    }
}
