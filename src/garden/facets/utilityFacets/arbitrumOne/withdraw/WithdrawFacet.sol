// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    @title WithdrawFacet
    @author BLOK Capital DAO
    @notice Facet providing USDC withdrawal functionality
    @dev This facet extends the WithdrawBase contract to provide the USDC withdrawal
         functionality. It allows the diamond owner to withdraw USDC tokens from the
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
import { IWithdraw } from "src/garden/facets/utilityFacets/arbitrumOne/withdraw/IWithdraw.sol";
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

contract WithdrawFacet is WithdrawBase, Facet {
    using SafeERC20 for IERC20;

    /// @notice Withdraws USDC from the contract to the owner address
    /// @param amount The amount of USDC to withdraw (in USDC decimals, usually 6)
    /// @dev Validates amount is non-zero, owner is valid, and contract has
    ///      sufficient balance. Uses SafeERC20 for secure transfer.
    function withdrawUSDC(uint256 amount) external override onlyGardenOwner ifIndexNotConnected {
        _withdrawUSDC(amount);
    }
}
