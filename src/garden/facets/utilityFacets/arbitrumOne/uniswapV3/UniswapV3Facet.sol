// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    @title UniswapFacet
    @author BLOK Capital DAO
    @notice Facet exposing Uniswap V3 swap and TWAP functions
    @dev This facet provides integration with Uniswap V3 for token swaps and price
         oracle queries. All swap operations are protected by owner-only access control.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

// OpenZeppelin Contracts
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Uniswap V3 Contracts
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

// Local Interfaces
import { IUniswapV3 } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/IUniswapV3.sol";
import { IPoolRegistry } from "src/interfaces/IPoolRegistry.sol";

// Local Libraries
import { TickMath } from "src/garden/libraries/TickMath.sol";
import { UniswapV3Base } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3Base.sol";
import { Facet } from "src/garden/facets/Facet.sol";

contract UniswapV3Facet is UniswapV3Base, IUniswapV3, Facet {
    using SafeERC20 for IERC20;

    // ========================================================================
    // External Functions (State-Changing)
    // ========================================================================

    /// @notice Executes a single-hop exact-input swap on Uniswap V3
    /// @param params Exact input single-hop swap parameters
    /// @dev Validates pool registration, handles token approvals, and executes swap.
    ///      Uses SafeERC20 for secure token operations.
    function swapExactInputSingleHop(IUniswapV3.ExactInputSingleHopSwapParams memory params)
        external
        override
        onlyGardenOwner
        ifIndexNotConnected
    {
        _swapExactInputSingleHop(params);
    }

    /// @notice Executes a multi-hop exact-input swap on Uniswap V3
    /// @param params Multi-hop swap parameters including path, amounts, and deadline
    /// @dev Validates all pools in the path are registered, handles approvals,
    ///      encodes the path, and executes the swap.
    function swapExactInputMultiHop(IUniswapV3.ExactInputMultiHopSwapParams memory params)
        external
        override
        onlyGardenOwner
        ifIndexNotConnected
    {
        _swapExactInputMultiHop(params);
    }

    /// @notice Executes a single-hop exact-output swap on Uniswap V3
    /// @param params Swap parameters including tokens, amounts, fees, and deadline
    /// @dev Validates pool registration, handles token approvals, and executes swap.
    ///      Uses SafeERC20 for secure token operations.
    function swapExactOutputSingleHop(IUniswapV3.ExactOutputSingleHopSwapParams memory params)
        external
        override
        onlyGardenOwner
        ifIndexNotConnected
    {
        _swapExactOutputSingleHop(params);
    }

    /// @notice Executes a multi-hop exact-output swap on Uniswap V3
    /// @param params Multi-hop swap parameters including path, amounts, and deadline
    /// @dev Validates all pools in the path are registered, handles approvals,
    ///      encodes the path, and executes the swap.
    function swapExactOutputMultiHop(IUniswapV3.ExactOutputMultiHopSwapParams memory params)
        external
        override
        onlyGardenOwner
        ifIndexNotConnected
    {
        _swapExactOutputMultiHop(params);
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
}
