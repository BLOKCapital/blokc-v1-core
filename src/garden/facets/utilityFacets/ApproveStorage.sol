// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { LibStorageSlot } from "../../libraries/LibStorageSlot.sol";

/// @title ApproveStorage
/// @author BLOK Capital DAO
/// @notice Diamond storage for allowances granted through ApproveFacet
/// @dev Tracks every token/spender pair so revokeTokens can enumerate grants and ownership
///      transfers can clear them. Never reorder or retype existing fields — append only, and
///      bump STORAGE_LAYOUT_VERSION.
library ApproveStorage {
    /// @notice Layout for the ApproveStorage
    uint256 internal constant STORAGE_LAYOUT_VERSION = 1;

    struct Layout {
        /// @notice Storage layout version — MUST be first field. Validated during upgrades.
        uint256 _storageLayoutVersion;
        /// @notice Tokens with at least one tracked spender
        EnumerableSet.AddressSet approvedTokens;
        /// @notice Tracked spenders per token
        mapping(address token => EnumerableSet.AddressSet spenders) spendersByToken;
    }

    /// @notice Returns the storage pointer to the Approve layout
    /// @dev Storage slot is derived from keccak256(bytes(type(ApproveStorage).name))
    /// @return l Storage reference to Layout
    function layout() internal pure returns (Layout storage l) {
        bytes32 position = LibStorageSlot.deriveStorageSlot(type(ApproveStorage).name);

        assembly {
            l.slot := position
        }
    }
}
