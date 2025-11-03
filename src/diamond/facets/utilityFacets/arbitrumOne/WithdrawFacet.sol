// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title WithdrawFacet
    @author BLOK Capital DAO
    @notice Facet providing USDC withdrawal functionality
    @dev This facet allows the diamond owner to withdraw USDC tokens from the
         diamond contract to the owner address.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

// OpenZeppelin Contracts
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Local Interfaces
import { IWithdraw } from "src/interfaces/IWithdraw.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";

// Local Libraries
import { LibDiamond } from "src/diamond/libraries/LibDiamond.sol";

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

// ============================================================================
// WithdrawFacet
// ============================================================================

/**
 * @title WithdrawFacet
 * @notice Facet providing USDC withdrawal functionality
 * @dev This facet allows the diamond owner to withdraw USDC tokens from the
 *      diamond contract. USDC is transferred to the current owner address.
 *      All operations are protected by owner-only access control.
 *
 *      Uses SafeERC20 for secure token transfers and validates all inputs
 *      before execution.
 */
contract WithdrawFacet is IWithdraw {
    using SafeERC20 for IERC20;

    // ========================================================================
    // Constants
    // ========================================================================

    /// @notice USDC token address on Arbitrum One
    address internal constant USDC_ADDRESS = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    // ========================================================================
    // Events
    // ========================================================================

    /// @notice Emitted when USDC is withdrawn from the contract
    /// @param to The recipient address (owner)
    /// @param amount The amount of USDC withdrawn
    event WithdrawFacetUSDCWithdrawn(address indexed to, uint256 amount);

    // ========================================================================
    // Modifiers
    // ========================================================================

    /// @notice Restricts function to diamond owner only
    modifier onlyDiamondOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    // ========================================================================
    // External Functions
    // ========================================================================

    /**
     * @notice Withdraws USDC from the contract to the owner address
     * @dev Validates amount is non-zero, owner is valid, and contract has
     *      sufficient balance. Uses SafeERC20 for secure transfer.
     * @param amount The amount of USDC to withdraw (in USDC decimals, usually 6)
     */
    function withdrawUSDC(uint256 amount) external override onlyDiamondOwner {
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

        emit WithdrawFacetUSDCWithdrawn(to, amount);
    }
}
