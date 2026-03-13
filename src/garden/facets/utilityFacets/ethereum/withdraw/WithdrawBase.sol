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
import { IWithdraw } from "src/garden/facets/utilityFacets/arbitrumOne/withdraw/IWithdraw.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when withdrawal amount is zero
error WithdrawFacet_WithdrawZeroAmount();

/// @notice Thrown when owner address is zero
error WithdrawFacet_InvalidOwner();

/// @notice Thrown when requested amount exceeds contract balance
/// @param requested The amount requested for withdrawal
/// @param available The amount available in the contract
error WithdrawFacet_InsufficientUSDCBalance(uint256 requested, uint256 available);

/**
 * @title WithdrawBase
 * @notice Base contract for USDC withdrawals on Arbitrum One, providing shared logic for validating and executing
 * withdrawals. This abstract contract is inherited by the WithdrawFacet which implements the external function. It
 * includes an internal function for withdrawing USDC to the owner address, validating the amount, owner, and
 * contract balance. The contract uses SafeERC20 for secure token transfers and emits an event upon successful
 * withdrawal.
 */
abstract contract WithdrawBase is IWithdraw {
    using SafeERC20 for IERC20;

    // ========================================================================
    // Constants
    // ========================================================================

    /// @notice USDC token address on Arbitrum One
    address internal constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // ========================================================================
    // Events
    // ========================================================================

    /// @notice Emitted when USDC is withdrawn from the contract
    /// @param to The recipient address (owner)
    /// @param amount The amount of USDC withdrawn
    event WithdrawFacetUsdcWithdrawn(address indexed to, uint256 amount);

    /// @notice Withdraws USDC from the contract to the owner address
    /// @dev Validates amount is non-zero, owner is valid, and contract has
    ///      sufficient balance. Uses SafeERC20 for secure transfer.
    /// @param amount The amount of USDC to withdraw (in USDC decimals, usually 6)
    function _withdrawUsdc(uint256 amount) internal {
        if (amount == 0) {
            revert WithdrawFacet_WithdrawZeroAmount();
        }

        // Get owner address (diamond owner)
        address to = IERC173(address(this)).owner();
        if (to == address(0)) {
            revert WithdrawFacet_InvalidOwner();
        }

        IERC20 usdc = IERC20(USDC_ADDRESS);
        uint256 contractBalance = usdc.balanceOf(address(this));

        if (amount > contractBalance) {
            revert WithdrawFacet_InsufficientUSDCBalance(amount, contractBalance);
        }

        // Safe transfer to owner
        usdc.safeTransfer(to, amount);

        emit WithdrawFacetUsdcWithdrawn(to, amount);
    }
}
