// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title AaveFacet
    @author BLOK Capital DAO
    @notice Facet exposing Aave integration functions (lend / withdraw / reserve data lookup)

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

// OpenZeppelin Contracts
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Aave Contracts
import { IPool } from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";
import { DataTypes } from "@aave/aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";

// Local Interfaces
import { IAaveV3 } from "src/diamond/facets/utilityFacets/arbitrumOne/aaveV3/IAaveV3.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when contract has insufficient token balance
error AaveV3Facet_InsufficientBalance();

/// @notice Thrown when token approval fails
error AaveV3Facet_ApprovalFailed();

/// @notice Thrown when pool address is zero or invalid
error AaveV3Facet_InvalidPoolAddress();

/// @notice Thrown when aToken address is zero (reserve not configured)
error AaveV3Facet_InvalidATokenAddress();

/// @notice Thrown when withdrawal amount exceeds aToken balance
error AaveV3Facet_InsufficientATokenBalance();

// ============================================================================
// AaveV3Base
// ============================================================================

/**
 * @title AaveV3Base
 * @notice Facet providing Aave V3 protocol integration for lending and withdrawing assets
 * @dev This facet allows the diamond owner to:
 *      - Lend tokens to Aave pools and receive aTokens
 *      - Withdraw tokens from Aave pools by burning aTokens
 *      - Query reserve data for Aave pools
 *
 *      All operations are protected by owner-only access control. Uses SafeERC20 for
 *      secure token transfers and approvals.
 */
abstract contract AaveV3Base is IAaveV3 {
    using SafeERC20 for IERC20;

    address private constant AAVE_V3_POOL_ADDRESS = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;

    // ========================================================================
    // Events
    // ========================================================================

    /// @notice Emitted when tokens are lent to Aave
    /// @param token The token address that was lent
    /// @param amount The amount of tokens lent
    /// @param from The address that initiated the operation (always the diamond)
    event AaveV3FacetTokensLent(address indexed token, uint256 amount, address from);

    /// @notice Emitted when tokens are withdrawn from Aave
    /// @param token The underlying token address that was withdrawn
    /// @param aTokenBalanceBefore The aToken balance before withdrawal
    /// @param to The recipient address (always the diamond)
    event AaveV3FacetTokensWithdrawn(address indexed token, uint256 aTokenBalanceBefore, address to);

    // ========================================================================
    // Internal Functions
    // ========================================================================

    /**
     * @notice Gets reserve data from an Aave pool for a specific token
     * @dev Returns the complete ReserveData struct from Aave, including aToken address,
     *      interest rate strategy, and other reserve configuration.
     * @param tokenIn The underlying asset token address whose reserve data is requested
     * @return reserveData The Aave ReserveData struct for the token
     */
    function _getReserveData(address tokenIn) internal view returns (DataTypes.ReserveData memory reserveData) {
        reserveData = IPool(AAVE_V3_POOL_ADDRESS).getReserveData(tokenIn);
    }

    /**
     * @notice Lends tokens to an Aave pool
     * @dev Transfers tokens from the diamond to the Aave pool and receives aTokens.
     *      Uses SafeERC20 for secure token handling. Implements the safe approval pattern
     *      (reset to 0, then set desired amount) to handle non-standard ERC20 tokens.
     * @param tokenIn The ERC20 token address to supply
     * @param amountIn Amount of token to supply
     */
    function _lend(address tokenIn, uint256 amountIn) internal {
        // Create typed references
        IPool pool = IPool(AAVE_V3_POOL_ADDRESS);
        IERC20 token = IERC20(tokenIn);

        // Ensure the contract has sufficient token balance
        if (token.balanceOf(address(this)) < amountIn) {
            revert AaveV3Facet_InsufficientBalance();
        }

        uint256 currentAllowance = token.allowance(address(this), address(pool));
        if (currentAllowance > 0) {
            // if token returns false on approve, revert
            if (!token.approve(address(pool), 0)) revert AaveV3Facet_ApprovalFailed();
        }

        // Supply tokens to Aave pool (recipient is this contract, referral code is 0)
        pool.supply(tokenIn, amountIn, address(this), 0);

        // Emit event for off-chain tracking
        emit AaveV3FacetTokensLent(tokenIn, amountIn, address(this));
    }

    /**
     * @notice Withdraws tokens from an Aave pool
     * @dev Burns aTokens and receives underlying tokens. Queries the pool for the
     *      aToken address, then checks balance before withdrawal.
     * @param tokenIn The underlying asset address (asset corresponding to the aToken)
     * @param amountToWithdraw Amount of underlying to withdraw (in token decimals)
     */
    function _withdraw(address tokenIn, uint256 amountToWithdraw) internal {
        IPool pool = IPool(AAVE_V3_POOL_ADDRESS);

        // Get reserve data to discover the aToken address
        DataTypes.ReserveData memory reserve = pool.getReserveData(tokenIn);
        if (reserve.aTokenAddress == address(0)) {
            revert AaveV3Facet_InvalidATokenAddress();
        }

        IERC20 aToken = IERC20(reserve.aTokenAddress);

        // Ensure sufficient aToken balance for requested withdrawal
        uint256 aTokenBalance = aToken.balanceOf(address(this));
        if (aTokenBalance < amountToWithdraw) {
            revert AaveV3Facet_InsufficientATokenBalance();
        }

        // Withdraw underlying tokens to this contract
        pool.withdraw({ asset: tokenIn, amount: amountToWithdraw, to: address(this) });

        // Emit event with aToken balance before withdrawal (useful for tracking)
        emit AaveV3FacetTokensWithdrawn(tokenIn, aTokenBalance, address(this));
    }
}
