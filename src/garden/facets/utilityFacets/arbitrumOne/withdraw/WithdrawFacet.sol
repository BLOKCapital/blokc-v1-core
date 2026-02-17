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
import { WithdrawBase } from "src/garden/facets/utilityFacets/arbitrumOne/withdraw/WithdrawBase.sol";

import { Facet } from "src/garden/facets/Facet.sol";

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
 * @title WithdrawFacet
 * @notice Facet for USDC withdrawals on Arbitrum One, allowing the garden owner to withdraw USDC from the contract.
 * This contract implements the IWithdraw interface and inherits from WithdrawBase for shared logic. It provides an
 * external function for withdrawing USDC, which validates the amount, owner, and contract balance before executing
 * the transfer. The contract uses SafeERC20 for secure token operations and emits an event upon successful withdrawal.
 */
contract WithdrawFacet is WithdrawBase, Facet {
    using SafeERC20 for IERC20;

    /// @notice Withdraws USDC from the contract to the owner address
    /// @param amount The amount of USDC to withdraw (in USDC decimals, usually 6)
    /// @dev Validates amount is non-zero, owner is valid, and contract has
    ///      sufficient balance. Uses SafeERC20 for secure transfer.
    function withdrawUsdc(uint256 amount) external override onlyGardenOwner nonReentrant ifIndexNotConnected {
        _withdrawUsdc(amount);
    }
}
