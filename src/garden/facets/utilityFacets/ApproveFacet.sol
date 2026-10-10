// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Facet } from "src/garden/facets/Facet.sol";
import { FeeBase } from "src/garden/facets/feeBase/FeeBase.sol";

/// @notice Thrown when approving the zero address as spender
error ApproveFacet_ZeroSpender();

/// @notice Thrown when a zero token address appears in the approval list
error ApproveFacet_ZeroToken();

/**
 * @title ApproveFacet
 * @notice Owner-callable ERC20 approval for the garden diamond.
 *
 *         The CumulativeRebalancer pulls component balances out of gardens via
 *         `safeTransferFrom(garden, rebalancer, balance)`, which requires the garden —
 *         as the token holder — to have granted allowance first. A diamond cannot call
 *         ERC20.approve on its own, so the garden owner sets (and can refresh) the
 *         allowances here.
 *
 *         Installed on INDEX gardens via the FacetRegistry's INDEX module (bumping the
 *         module version), then picked up by each garden's normal two-step upgrade.
 *
 *         A recorded fee session blocks approvals: with a basis recorded, the unwind is
 *         the only sanctioned value exit, and an unscoped max allowance would open a
 *         second, fee-free rail that drains the fee base before settlement. Grant (or
 *         refresh) allowances while the garden has no active fee session — rebalancer
 *         pulls during a rebalance use the already-granted allowances.
 */
contract ApproveFacet is Facet, FeeBase {
    using SafeERC20 for IERC20;

    /// @notice Grants max allowance for `tokens` to `spender` from the garden's balances.
    /// @param tokens Component token addresses (plus USDC when it is not a component of
    ///               the garden's index — the Rebalancer pulls it separately)
    /// @param spender The contract allowed to pull tokens — the CumulativeRebalancer
    function approveTokens(address[] calldata tokens, address spender) external onlyGardenOwner {
        // Fee-session containment: no parallel value egress while a feeable session is live
        _revertIfFeeSessionActive();

        if (spender == address(0)) revert ApproveFacet_ZeroSpender();

        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0)) revert ApproveFacet_ZeroToken();
            // forceApprove resets to 0 first, so re-running after a partial setup or a
            // future spender change cannot revert on a non-zero-to-non-zero allowance.
            IERC20(tokens[i]).forceApprove(spender, type(uint256).max);
        }
    }
}
