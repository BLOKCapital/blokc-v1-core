// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title AaveFacet
    @author BLOK Capital DAO
    @notice Facet exposing Aave integration functions (lend / withdraw / reserve data lookup)
    @dev This facet provides integration with Aave V3 protocol for lending and withdrawing assets.
         All operations are protected by owner-only access control.

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
import { IAave } from "src/interfaces/IAave.sol";

// Local Libraries
import { LibDiamond } from "src/diamond/libraries/LibDiamond.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when token address is zero
error AaveFacet_InvalidToken();

/// @notice Thrown when amount is zero
error AaveFacet_InvalidAmount();

/// @notice Thrown when contract has insufficient token balance
error AaveFacet_InsufficientBalance();

/// @notice Thrown when token approval fails
error AaveFacet_ApprovalFailed();

/// @notice Thrown when pool address is zero or invalid
error AaveFacet_InvalidPoolAddress();

/// @notice Thrown when aToken address is zero (reserve not configured)
error AaveFacet_InvalidATokenAddress();

/// @notice Thrown when withdrawal amount exceeds aToken balance
error AaveFacet_InsufficientATokenBalance();

// ============================================================================
// AaveFacet
// ============================================================================

/**
 * @title AaveFacet
 * @notice Facet providing Aave V3 protocol integration for lending and withdrawing assets
 * @dev This facet allows the diamond owner to:
 *      - Lend tokens to Aave pools and receive aTokens
 *      - Withdraw tokens from Aave pools by burning aTokens
 *      - Query reserve data for Aave pools
 *
 *      All operations are protected by owner-only access control. Uses SafeERC20 for
 *      secure token transfers and approvals.
 */
contract AaveFacet is IAave {
    using SafeERC20 for IERC20;

    // ========================================================================
    // Events
    // ========================================================================

    /// @notice Emitted when tokens are lent to Aave
    /// @param token The token address that was lent
    /// @param amount The amount of tokens lent
    /// @param from The address that initiated the operation (always the diamond)
    event AaveFacetTokensLent(address indexed token, uint256 amount, address from);

    /// @notice Emitted when tokens are withdrawn from Aave
    /// @param token The underlying token address that was withdrawn
    /// @param aTokenBalanceBefore The aToken balance before withdrawal
    /// @param to The recipient address (always the diamond)
    event AaveFacetTokensWithdrawn(address indexed token, uint256 aTokenBalanceBefore, address to);

    // ========================================================================
    // Modifiers
    // ========================================================================

    /// @notice Restricts function to diamond owner only
    modifier onlyDiamondOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    // ========================================================================
    // External Functions (View)
    // ========================================================================

    /**
     * @notice Gets reserve data from an Aave pool for a specific token
     * @dev Returns the complete ReserveData struct from Aave, including aToken address,
     *      interest rate strategy, and other reserve configuration.
     * @param params Parameters containing pool address and token address
     * @return reserveData The Aave ReserveData struct for the token
     */
    function aaveReserveData(AaveReserveDataParams calldata params)
        external
        view
        override
        returns (DataTypes.ReserveData memory reserveData)
    {
        if (params.poolAddress == address(0)) {
            revert AaveFacet_InvalidPoolAddress();
        }
        if (params.tokenIn == address(0)) {
            revert AaveFacet_InvalidToken();
        }
        reserveData = IPool(params.poolAddress).getReserveData(params.tokenIn);
    }

    // ========================================================================
    // External Functions (State-Changing)
    // ========================================================================

    /**
     * @notice Lends tokens to an Aave pool
     * @dev Transfers tokens from the diamond to the Aave pool and receives aTokens.
     *      Uses SafeERC20 for secure token handling. Implements the safe approval pattern
     *      (reset to 0, then set desired amount) to handle non-standard ERC20 tokens.
     * @param params Parameters containing pool address, token address, and amount
     */
    function lendToAave(AaveLendParams calldata params) external override onlyDiamondOwner {
        // Input validation
        if (params.poolAddress == address(0)) {
            revert AaveFacet_InvalidPoolAddress();
        }
        if (params.tokenIn == address(0)) {
            revert AaveFacet_InvalidToken();
        }
        if (params.amountIn == 0) {
            revert AaveFacet_InvalidAmount();
        }

        // Create typed references
        IPool pool = IPool(params.poolAddress);
        IERC20 token = IERC20(params.tokenIn);

        // Ensure the contract has sufficient token balance
        if (token.balanceOf(address(this)) < params.amountIn) {
            revert AaveFacet_InsufficientBalance();
        }

        // Safe approval pattern: use forceApprove which handles non-standard ERC20 tokens
        // that require resetting allowance to 0 before setting a new value
        token.forceApprove(address(pool), params.amountIn);

        // Supply tokens to Aave pool (recipient is this contract, referral code is 0)
        pool.supply(params.tokenIn, params.amountIn, address(this), 0);

        // Emit event for off-chain tracking
        emit AaveFacetTokensLent(params.tokenIn, params.amountIn, address(this));
    }

    /**
     * @notice Withdraws tokens from an Aave pool
     * @dev Burns aTokens and receives underlying tokens. Queries the pool for the
     *      aToken address, then checks balance before withdrawal.
     * @param params Parameters containing pool address, token address, and withdrawal amount
     */
    function withdrawFromAave(AaveWithdrawParams calldata params) external override onlyDiamondOwner {
        // Input validation
        if (params.poolAddress == address(0)) {
            revert AaveFacet_InvalidPoolAddress();
        }
        if (params.tokenIn == address(0)) {
            revert AaveFacet_InvalidToken();
        }
        if (params.amountToWithdraw == 0) {
            revert AaveFacet_InvalidAmount();
        }

        IPool pool = IPool(params.poolAddress);

        // Get reserve data to discover the aToken address
        DataTypes.ReserveData memory reserve = pool.getReserveData(params.tokenIn);
        if (reserve.aTokenAddress == address(0)) {
            revert AaveFacet_InvalidATokenAddress();
        }

        IERC20 aToken = IERC20(reserve.aTokenAddress);

        // Ensure sufficient aToken balance for requested withdrawal
        uint256 aTokenBalance = aToken.balanceOf(address(this));
        if (aTokenBalance < params.amountToWithdraw) {
            revert AaveFacet_InsufficientATokenBalance();
        }

        // Withdraw underlying tokens to this contract
        pool.withdraw({ asset: params.tokenIn, amount: params.amountToWithdraw, to: address(this) });

        // Emit event with aToken balance before withdrawal (useful for tracking)
        emit AaveFacetTokensWithdrawn(params.tokenIn, aTokenBalance, address(this));
    }
}
