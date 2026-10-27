// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { OwnershipStorage } from "./OwnershipStorage.sol";
import { ApproveStorage } from "src/garden/facets/utilityFacets/ApproveStorage.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";

/// @notice Thrown when attempting to transfer ownership to the zero address.
/// @dev The zero address would permanently lock all onlyGardenOwner functions
///      on the garden diamond (no recoverable owner), so it must be rejected.
error OwnershipBase_InvalidNewOwner(address newOwner);

/**
 * @title OwnershipBase
 * @notice Base contract that implements internal functions for ownership management according to the ERC-173 standard.
 * This contract is intended to be inherited by an OwnershipFacet that exposes the ownership functions with appropriate
 * access control.
 */
abstract contract OwnershipBase is IERC173 {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Transfers ownership of the contract to a new address
    /// @param _newOwner The address of the new owner
    /// @dev Reverts if `_newOwner` is the zero address — an ownerless garden would
    ///      permanently brick all onlyGardenOwner functions.
    ///
    ///      Every allowance tracked in ApproveStorage is cleared before the new owner is
    ///      written, closing the former owner's allowance rail for grants made through
    ///      ApproveFacet. The new owner must re-approve the canonical Rebalancer after the
    ///      handover. Legacy allowances granted by a facet that predates ApproveStorage are
    ///      not enumerable and must be swept with ApproveFacet.revokeTokens beforehand.
    function _transferOwnership(address _newOwner) internal {
        if (_newOwner == address(0)) revert OwnershipBase_InvalidNewOwner(_newOwner);

        _clearTrackedApprovals();

        OwnershipStorage.layout().owner = _newOwner;
        emit OwnershipTransferred(msg.sender, _newOwner);
    }

    /// @notice Clears every tracked allowance before ownership changes hands
    /// @dev Fail-closed: if a token's forceApprove(spender, 0) reverts, the whole transfer
    ///      reverts and the old owner must clean up (e.g. via revokeTokens) before handing over.
    function _clearTrackedApprovals() private {
        ApproveStorage.Layout storage approvals = ApproveStorage.layout();
        while (approvals.approvedTokens.length() > 0) {
            address token = approvals.approvedTokens.at(0);
            EnumerableSet.AddressSet storage spenders = approvals.spendersByToken[token];
            while (spenders.length() > 0) {
                address spender = spenders.at(0);
                IERC20(token).forceApprove(spender, 0);
                spenders.remove(spender);
            }
            approvals.approvedTokens.remove(token);
        }
    }

    /// @notice Retrieves the address of the current owner
    /// @return owner_ The address of the current owner, or address(0) if ownerless
    function _owner() internal view returns (address owner_) {
        owner_ = OwnershipStorage.layout().owner;
    }
}
