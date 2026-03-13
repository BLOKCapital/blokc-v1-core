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
import { IUniswapV3 } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/IUniswapV3.sol";

// Local Libraries
import { UniswapV3Base } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3Base.sol";
import { Facet } from "src/garden/facets/Facet.sol";

/**
 * @title UniswapV3Facet
 * @notice Facet for Uniswap V3 interactions on Arbitrum One, enabling token swaps and price oracle queries.
 * This contract implements the IUniswapV3 interface and inherits from UniswapV3Base for shared logic. It provides
 * external functions for executing exact input/output swaps (both single and multi-hop) and fetching TWAP prices.
 * The contract ensures that only the garden owner can execute swaps, validates pool registrations, and uses
 * SafeERC20 for secure token operations.
 */
contract UniswapV3Facet is IUniswapV3, UniswapV3Base, Facet {
    using SafeERC20 for IERC20;

    // ========================================================================
    // External Functions
    // ========================================================================

    /// @notice Executes a single-hop exact-input swap on Uniswap V3
    /// @param params Exact input single-hop swap parameters
    /// @dev Validates pool registration, handles token approvals, and executes swap.
    ///      Uses SafeERC20 for secure token operations.
    function uniswapV3ExactInputSingle(UniswapV3ExactInputSingleParams memory params)
        external
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
    {
        _uniswapV3ExactInputSingle(params);
    }

    /// @notice Executes a multi-hop exact-input swap on Uniswap V3
    /// @param params Multi-hop swap parameters including path, amounts, and deadline
    /// @dev Validates all pools in the path are registered, handles approvals,
    ///      encodes the path, and executes the swap.
    function uniswapV3ExactInput(UniswapV3ExactInputParams memory params)
        external
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
    {
        _uniswapV3ExactInput(params);
    }

    /// @notice Executes a single-hop exact-output swap on Uniswap V3
    /// @param params Swap parameters including tokens, amounts, fees, and deadline
    /// @dev Validates pool registration, handles token approvals, and executes swap.
    ///      Uses SafeERC20 for secure token operations.
    function uniswapV3ExactOutputSingle(UniswapV3ExactOutputSingleParams memory params)
        external
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
    {
        _uniswapV3ExactOutputSingle(params);
    }

    /// @notice Executes a multi-hop exact-output swap on Uniswap V3
    /// @param params Multi-hop swap parameters including path, amounts, and deadline
    /// @dev Validates all pools in the path are registered, handles approvals,
    ///      encodes the path, and executes the swap.
    function uniswapV3ExactOutput(UniswapV3ExactOutputParams memory params)
        external
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
    {
        _uniswapV3ExactOutput(params);
    }

    // ========================================================================
    // External Functions (View)
    // ========================================================================

    /// @notice Gets the TWAP sqrt price for a single Uniswap V3 pool
    /// @param uniswapV3Pool Address of the Uniswap V3 pool to query
    /// @param twapInterval TWAP observation interval in seconds (applies to all pools)
    /// @return sqrtPriceX96 The sqrt price in Q64.96 format
    /// @return deadline Suggested deadline for swaps using this price (now + 300s)
    /// @dev Returns either the current spot price (if twapInterval is 0) or the
    ///      TWAP price over the specified interval. Price is returned in Q64.96 format.
    function getSqrtTwapX96(
        address uniswapV3Pool,
        uint32 twapInterval
    )
        external
        view
        override
        returns (uint160 sqrtPriceX96, uint256 deadline)
    {
        return _getSqrtTwapX96(uniswapV3Pool, twapInterval);
    }

    /// @notice Gets a combined TWAP price across multiple Uniswap V3 pools
    /// @dev Multiplies prices from multiple pools together, with optional inversion.
    ///      Useful for calculating prices across complex paths (e.g., ETH -> USDC -> DAI).
    /// @param pools Array of PoolInfo describing which pools to combine
    /// @param twapInterval TWAP observation interval in seconds (applies to all pools)
    /// @return combinedPriceX96 The combined price in Q96 format
    /// @return deadline Suggested deadline for swaps using this price (now + 300s)
    function getCombinedTwapX96(
        PoolInfo[] memory pools,
        uint32 twapInterval
    )
        external
        view
        returns (uint256 combinedPriceX96, uint256 deadline)
    {
        return _getCombinedTwapX96(pools, twapInterval);
    }

    /// @inheritdoc IUniswapV3
    function uniswapV3QuoteExactInputForPool(
        address poolAddress,
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        uint32 twapInterval
    )
        external
        view
        returns (uint256 amountOut)
    {
        return _uniswapV3QuoteExactInputForPool(poolAddress, amountIn, tokenIn, tokenOut, twapInterval);
    }
}
