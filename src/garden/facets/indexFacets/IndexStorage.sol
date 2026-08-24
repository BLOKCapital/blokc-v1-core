// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { LibStorageSlot } from "../../libraries/LibStorageSlot.sol";

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { PendingIntent } from "src/garden/facets/indexFacets/IIndex.sol";

/**
 * @title IndexStorage
 * @author BLOK Capital DAO
 * @notice Storage layout and constants for Index-related facets
 * @dev Uses diamond storage pattern with a fixed storage slot to ensure
 *      compatibility across diamond upgrades. Contains Arbitrum One mainnet
 *      addresses for tokens, oracles, and registries.
 */
library IndexStorage {
    // ========================================================================
    // Token Addresses (Arbitrum One Mainnet)
    // ========================================================================

    /// @notice WETH address on Arbitrum One - used as base asset for rebalancing
    address internal constant WETH_ADDRESS = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    /// @notice USDC address on Arbitrum One
    address internal constant USDC_ADDRESS = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    /// @notice Chainlink ETH/USD price feed address on Arbitrum One
    address internal constant WETH_PRICE_FEED_ADDRESS = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;

    // ========================================================================
    // Rebalancing Parameters
    // ========================================================================

    /// @notice Precision for calculations (1e18 = 100%)
    uint256 internal constant PRECISION = 1e18;

    /// @notice Balance threshold in basis points (2% = 200 bps)
    /// @dev 2% accommodates multi-hop swap fees (~0.6% per 2-hop route), price
    ///      movement between intent creation and execution, and rounding on small
    ///      allocations. Industry standard for multi-token index rebalancing.
    uint256 internal constant BALANCE_THRESHOLD_BPS = 200;

    /// @notice Minimum cooldown between consecutive rebalance executions (24 hours).
    /// @dev Rate-limits permissionless rebalance triggering: with MAX_VALUE_LOSS_BPS capping
    ///      loss per execution at 0.5%, a daily interval bounds worst-case extraction.
    uint256 internal constant REBALANCE_INTERVAL = 1 days;

    /// @notice Maximum allowed total value loss during rebalance (0.5% = 50 bps)
    uint256 internal constant MAX_VALUE_LOSS_BPS = 50;

    /// @notice Intent expiry duration - intents become invalid after this period
    uint256 internal constant INTENT_EXPIRY = 10 minutes;
    /// @notice Minimum interval between intent creations (11 minutes).
    /// @dev MUST be strictly greater than INTENT_EXPIRY. Using the expiry duration as the
    ///      creation cooldown would allow a new intent to overwrite a still-valid pending
    ///      intent at the exact `lastIntentTimestamp + INTENT_EXPIRY` boundary (off-by-one),
    ///      enabling front-running/griefing of in-flight rebalances. By requiring a strictly
    ///      longer interval, a live intent can never be overwritten before it expires.
    uint256 internal constant INTENT_INTERVAL = 11 minutes;

    /// @notice Minimum block delay between intent creation and rebalance execution
    /// @dev Prevents flash loan attacks where intent + rebalance occur in the same block
    uint256 internal constant MIN_INTENT_DELAY = 1;

    /// @notice Module identifier for DEX facets; only selectors in this module are allowed during rebalance.
    bytes32 internal constant DEX_MODULE_ID = keccak256("DEX");

    uint256 internal constant STORAGE_LAYOUT_VERSION = 2;

    /// @notice Storage layout for index-related state
    struct Layout {
        /// @notice Storage layout version — MUST be first field. Validated during upgrades.
        uint256 _storageLayoutVersion;
        address indexAddress;
        // Timestamps
        uint256 lastRebalanceTimestamp;
        uint256 lastIntentTimestamp;
        // Reentrancy guard for rebalance (avoids conflict with OZ ReentrancyGuard on DEX facets)
        bool rebalancing;
        // Pending rebalance state
        PendingIntent pendingIntent;
        // Flash loan protection: block number when intent was created (appended for storage safety)
        uint256 lastIntentBlock;
        // Own-protocol registry addresses (appended in v2). Deployer-configured at install via
        // configureIndexModule — not compile-time constants, so redeploying the protocol
        // components does not require recompiling or re-cutting the facets.
        address indexFactory;
        address indexComponentRegistry;
        address poolRegistry;
    }

    /// @notice Returns a pointer to the index storage layout
    /// @dev Storage slot is derived from keccak256(bytes(type(IndexStorage).name))
    /// @return l Storage pointer to Layout struct
    function layout() internal pure returns (Layout storage l) {
        bytes32 position = LibStorageSlot.deriveStorageSlot(type(IndexStorage).name);

        assembly {
            l.slot := position
        }
    }
}
