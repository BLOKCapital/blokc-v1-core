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
import { SwapInstruction, QuoteInstruction } from "src/interfaces/ISwapInstruction.sol";

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

    /// @inheritdoc IUniswapV3
    function uniswapV3Swap(SwapInstruction calldata instruction)
        external
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
    {
        _uniswapV3Swap(instruction);
    }

    // ========================================================================
    // External Functions (View)
    // ========================================================================

    /// @inheritdoc IUniswapV3
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

    /// @inheritdoc IUniswapV3
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
    function uniswapV3Quote(QuoteInstruction calldata instruction) external view returns (uint256 result) {
        return _uniswapV3Quote(instruction);
    }
}
