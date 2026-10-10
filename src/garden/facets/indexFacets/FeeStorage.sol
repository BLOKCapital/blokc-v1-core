// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { LibStorageSlot } from "../../libraries/LibStorageSlot.sol";

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▛▀▜▌▐▛▚▖     ▐▌   ▐▌ ▐▌▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

/**
 * @title FeeStorage
 * @author BLOK Capital DAO
 * @notice Garden-level fee session state: the fee-module registry wiring, the connection basis
 *         (entryUSDC), the locked fee schedule, and settlement audit fields. Tool-agnostic —
 *         any wealth-management module a garden hosts starts a fee session via _recordBasis and
 *         ends it via _settleFees (see FeeBase); the INDEX module is the first consumer.
 * @dev Uses the diamond storage pattern (EIP-7201-style derived slot, same as IndexStorage).
 *      Never reorder or retype existing fields — append only, and bump STORAGE_LAYOUT_VERSION.
 */
library FeeStorage {
    /// @notice Storage layout version — MUST be first field in Layout. Validated during upgrades.
    uint256 internal constant STORAGE_LAYOUT_VERSION = 1;

    /// @notice applyRateAt snapshot values (mirror of IFeeRegistry.ApplyRateAt)
    uint8 internal constant APPLY_RATE_CONNECT_LOCK = 0;
    uint8 internal constant APPLY_RATE_DISCONNECT_LIVE = 1;

    /// @notice The fee schedule snapshot locked at session start
    /// @param performanceFeeBps Performance fee in bps of realized profit
    /// @param protocolFeeBps Protocol fee in bps of realized profit
    /// @param onboarderShareBps Onboarder share OF the performance fee in bps
    /// @param applyRateAtMode FeeStorage APPLY_RATE_* snapshot
    struct FeeSchedule {
        uint16 performanceFeeBps;
        uint16 protocolFeeBps;
        uint16 onboarderShareBps;
        uint8 applyRateAtMode;
    }

    /// @notice Storage layout for the garden fee session
    struct Layout {
        /// @notice Storage layout version — MUST be first field. Validated during upgrades.
        uint256 _storageLayoutVersion;
        // ── Module configuration (configureFeeModule)
        // ─────────────────────────
        address feeRegistry;
        address treasuryRegistry;
        address onboarderRegistry;
        // ── Session basis (written at session start, cleared at exit) ─────────
        /// @notice Explicit flag: entryUSDC == 0 is a legal basis (fresh garden)
        bool basisRecorded;
        /// @notice USDC-denominated basis: connect NAV + recorded deposits (6 decimals)
        uint256 entryUSDC;
        /// @notice Audit: cumulative USDC value credited through deposit recording
        uint256 depositUSDC;
        uint64 connectedAtBlock;
        uint64 connectedAtTimestamp;
        /// @notice Bound onboarder for this session (address(0) = none)
        address onboarderAddress;
        /// @notice Schedule snapshot locked at session start
        FeeSchedule lockedSchedule;
        // ── Guards / audit history (survive sessions)
        // ──────────────────────────
        /// @notice Custom reentrancy flag for the unwind flow (self-calls DEX facets — never
        ///         wrap in OZ nonReentrant, same rationale as IndexStorage.rebalancing)
        bool unwinding;
        uint256 lastExitUSDC;
        int256 lastRealizedProfitUSDC; // negative = loss recorded
    }

    /// @notice Returns a pointer to the fee storage layout
    /// @dev Storage slot is derived from keccak256(bytes(type(FeeStorage).name))
    /// @return l Storage pointer to Layout struct
    function layout() internal pure returns (Layout storage l) {
        bytes32 position = LibStorageSlot.deriveStorageSlot(type(FeeStorage).name);

        assembly {
            l.slot := position
        }
    }
}
