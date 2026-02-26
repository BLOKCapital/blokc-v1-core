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
    address internal constant INDEX_FACTORY_ADDRESS = 0x822aC87bDf3f8Fb429B2465cf6AeD379509f8C95;

    /// @notice IndexComponentRegistry contract address
    address internal constant INDEX_COMPONENT_REGISTRY_ADDRESS = 0x5b1e9bc7253b2f9419b382E0B21D721A2B599070;

    // ========================================================================
    // Rebalancing Parameters
    // ========================================================================

    /// @notice Precision for calculations (1e18 = 100%)
    uint256 internal constant PRECISION = 1e18;

    /// @notice Balance threshold in basis points (1% = 100 bps)
    uint256 internal constant BALANCE_THRESHOLD_BPS = 100;

    /// @notice Minimum cooldown between consecutive rebalance executions (1 hour).
    uint256 internal constant REBALANCE_INTERVAL = 1 hours;

    /// @notice Maximum allowed total value loss during rebalance (0.5% = 50 bps)
    uint256 internal constant MAX_VALUE_LOSS_BPS = 50;

    /// @notice Intent expiry duration - intents become invalid after this period
    uint256 internal constant INTENT_EXPIRY = 10 minutes;

    /// @notice Module identifier for DEX facets; only selectors in this module are allowed during rebalance.
    bytes32 internal constant DEX_MODULE_ID = keccak256("DEX");

    /// @notice Storage layout for index-related state
    /// @param indexAddress Address of the connected Index contract
    /// @param lastRebalanceTimestamp Block timestamp of last rebalance
    /// @param rebalancing Reentrancy guard flag for rebalance execution (separate from OZ ReentrancyGuard)
    struct Layout {
        address indexAddress;
        // Timestamps
        uint256 lastRebalanceTimestamp;
        uint256 lastIntentTimestamp;
        // Reentrancy guard for rebalance (avoids conflict with OZ ReentrancyGuard on DEX facets)
        bool rebalancing;
        // Pending rebalance state
        PendingIntent pendingIntent;
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
