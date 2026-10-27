// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ApproveStorage } from "src/garden/facets/utilityFacets/ApproveStorage.sol";
import { Facet } from "src/garden/facets/Facet.sol";
import { FeeBase } from "src/garden/facets/feeBase/FeeBase.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { LibDiamond } from "src/garden/libraries/LibDiamond.sol";

/// @notice Thrown when approving the zero address as spender
error ApproveFacet_ZeroSpender();

/// @notice Thrown when approveTokens is attempted before the FacetRegistry has published the
///         canonical rebalancer (fail-closed)
error ApproveFacet_CanonicalRebalancerNotSet();

/// @notice Thrown when the spender is not the DAO's canonical rebalancer
/// @param provided The spender that was passed
/// @param canonical The canonical rebalancer it must match
error ApproveFacet_SpenderNotCanonicalRebalancer(address provided, address canonical);

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
 *
 *         Grants made here are tracked in ApproveStorage so they can be revoked explicitly
 *         (including after a rebalancer rotation) and are cleared automatically on ownership
 *         transfer. Legacy allowances granted by an older facet are not enumerable —
 *         revokeTokens is the migration sweep for those arbitrary spenders.
 */
contract ApproveFacet is Facet, FeeBase {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Grants max allowance for `tokens` to `spender` from the garden's balances.
    /// @param tokens Component token addresses (plus USDC when it is not a component of
    ///               the garden's index — the Rebalancer pulls it separately)
    /// @param spender The contract allowed to pull tokens — the DAO's canonical
    ///                CumulativeRebalancer (validated against the FacetRegistry)
    function approveTokens(address[] calldata tokens, address spender) external onlyGardenOwner {
        // Fee-session containment: no parallel value egress while a feeable session is live
        _revertIfFeeSessionActive();

        if (spender == address(0)) revert ApproveFacet_ZeroSpender();

        // Allowances exist solely for the canonical CumulativeRebalancer's pulls — any
        // other spender is a parallel value-egress rail. Fail-closed while unpublished.
        address canonical = IFacetRegistry(LibDiamond.layout().facetRegistry).getCanonicalRebalancer();
        if (canonical == address(0)) revert ApproveFacet_CanonicalRebalancerNotSet();
        if (spender != canonical) revert ApproveFacet_SpenderNotCanonicalRebalancer(spender, canonical);

        ApproveStorage.Layout storage approvals = ApproveStorage.layout();
        approvals._storageLayoutVersion = ApproveStorage.STORAGE_LAYOUT_VERSION;

        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            if (token == address(0)) revert ApproveFacet_ZeroToken();
            // forceApprove resets to 0 first, so re-running after a partial setup or a
            // future spender change cannot revert on a non-zero-to-non-zero allowance.
            IERC20(token).forceApprove(spender, type(uint256).max);

            // Track the pair so revokeTokens can enumerate it and ownership transfers can
            // clear it before the new owner takes over.
            approvals.approvedTokens.add(token);
            approvals.spendersByToken[token].add(spender);
        }
    }

    /// @notice Revokes `spender`'s allowance on `tokens` and clears the tracked entries.
    /// @dev Supports Rebalancer rotation (revoke the outgoing canonical spender before
    ///      granting the incoming one) and cleanup of legacy arbitrary-spender allowances
    ///      granted by an older facet. Any non-zero spender can be revoked — unlike
    ///      approveTokens, `spender` is not required to be the canonical rebalancer.
    ///      Revocation only reduces value-egress surface, so it is intentionally not blocked
    ///      during a fee session.
    /// @param tokens Token addresses whose allowance to `spender` is zeroed
    /// @param spender The allowance beneficiary to revoke
    function revokeTokens(address[] calldata tokens, address spender) external onlyGardenOwner {
        if (spender == address(0)) revert ApproveFacet_ZeroSpender();

        ApproveStorage.Layout storage approvals = ApproveStorage.layout();
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            if (token == address(0)) revert ApproveFacet_ZeroToken();

            // Unconditional zeroing also cleans up allowances that were never tracked
            // (legacy grants from a previous facet implementation).
            IERC20(token).forceApprove(spender, 0);

            EnumerableSet.AddressSet storage spenders = approvals.spendersByToken[token];
            spenders.remove(spender);
            if (spenders.length() == 0) {
                approvals.approvedTokens.remove(token);
            }
        }
    }
}
