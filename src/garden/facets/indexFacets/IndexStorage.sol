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
    // Registry Addresses (Arbitrum One)
    // ========================================================================

    /// @notice IndexFactory contract address
    address internal constant INDEX_FACTORY_ADDRESS = 0x91da26BF1a4adDa42355B80502785d3F026d7074;

    /// @notice IndexComponentRegistry contract address
    address internal constant INDEX_COMPONENT_REGISTRY_ADDRESS = 0x3F8291D2Fb3f5C4391DDbc36C4Ee0B1F48274977;

    /// @notice LiquidityPoolRegistry contract address (for DEX selector resolution)
    address internal constant POOL_REGISTRY_ADDRESS = 0xA3178280c191dD46c551b91c651F337E47594d85;

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

    /// @notice Minimum cooldown between consecutive rebalance executions (1 hour).
    uint256 internal constant REBALANCE_INTERVAL = 1 hours;

    /// @notice Maximum allowed total value loss during rebalance (0.5% = 50 bps)
    uint256 internal constant MAX_VALUE_LOSS_BPS = 50;

    /// @notice Intent expiry duration - intents become invalid after this period
    uint256 internal constant INTENT_EXPIRY = 10 minutes;

    /// @notice Minimum block delay between intent creation and rebalance execution
    /// @dev Prevents flash loan attacks where intent + rebalance occur in the same block
    uint256 internal constant MIN_INTENT_DELAY = 1;

    /// @notice Module identifier for DEX facets; only selectors in this module are allowed during rebalance.
    bytes32 internal constant DEX_MODULE_ID = keccak256("DEX");

    uint256 internal constant STORAGE_LAYOUT_VERSION = 1;

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
