// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { LibStorageSlot } from "../../../../libraries/LibStorageSlot.sol";

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

/// @title GmxV2Storage
/// @author BLOK Capital DAO
/// @notice Diamond storage library for GMX V2 short position tracking and configuration
library GmxV2Storage {
    /// @notice Kind of order a pending GMX request represents
    /// @dev Determines how the execution callback mutates the target position.
    enum OrderKind {
        Increase, // open a new short or add size/collateral (MarketIncrease)
        Decrease // reduce or fully close a short (MarketDecrease)
    }

    /// @notice A GMX order that has been submitted but not yet executed by a keeper
    /// @dev Keyed by the GMX *order* key (a global nonce). Transient: created on submission, deleted
    /// by the execution/cancellation/frozen callback. This is the correlation handle between the order
    /// key GMX returns from `createOrder` and the position key the order ultimately affects.
    struct PendingOrder {
        bytes32 positionKey; // the position this order will create or mutate
        OrderKind kind; // increase vs decrease
        uint256 sizeDeltaUsd; // size change requested (30 decimals)
        uint256 collateralDelta; // collateral sent in (increase) — informational; GMX is authoritative
        address market; // GMX market for this order
        address indexToken; // token being shorted
        address collateralToken; // collateral token
        bool exists; // presence flag (mappings have no null)
    }

    /// @notice Durable record of a live short position
    /// @dev Keyed by the GMX *position* key = keccak256(account, market, collateralToken, isLong). One
    /// entry per position for its whole life, regardless of how many orders act on it. Size/collateral
    /// are best-effort mirrors updated on callbacks; GMX (via Reader) remains authoritative because
    /// funding, borrowing and ADL mutate them without notifying this contract.
    struct PositionInfo {
        bytes32 positionKey; // GMX position key (identity hash)
        address market; // GMX market (needed for Reader queries and key derivation)
        address indexToken; // token being shorted
        address collateralToken; // collateral token
        uint256 sizeInUsd; // mirrored size in USD (30 decimals) — best effort
        uint256 collateralAmount; // mirrored collateral — best effort
        uint256 timestamp; // when the position first became active
        bool isShort; // always true for this facet
        bool isActive; // whether a live position currently exists
    }

    /// @notice Diamond storage layout for GMX V2 facet state
    /// @dev Bumped from 1 → 2: added `pendingOrders` mapping and reshaped `PositionInfo`
    /// (added `market`) to support the two-key, two-phase order lifecycle.
    uint256 internal constant STORAGE_LAYOUT_VERSION = 2;

    struct Layout {
        /// @notice Storage layout version — MUST be first field. Validated during upgrades.
        uint256 _storageLayoutVersion;
        /// @notice Mapping from position key to durable position info
        mapping(bytes32 => PositionInfo) positions;
        /// @notice Mapping from GMX order key to the transient pending order it represents
        mapping(bytes32 => PendingOrder) pendingOrders;
        /// @notice Array of all position keys ever seen, for enumeration (deduplicated on insert)
        bytes32[] positionKeys;
        /// @notice Total number of active positions
        uint256 activePositionCount;
        /// @notice Total collateral locked in all positions
        uint256 totalCollateralLocked;
        /// @notice Last interaction timestamp
        uint256 lastInteractionTimestamp;
        /// @notice Maximum leverage allowed (e.g., 10 = 10x leverage)
        uint256 maxLeverage;
        /// @notice Minimum collateral required (in USD, 30 decimals)
        uint256 minCollateralUsd;
    }

    /// @notice Returns a pointer to the GMX V2 storage layout
    /// @return l Storage pointer to the GmxV2Storage Layout struct
    function layout() internal pure returns (Layout storage l) {
        bytes32 position = LibStorageSlot.deriveStorageSlot(type(GmxV2Storage).name);
        assembly {
            l.slot := position
        }
    }
}
