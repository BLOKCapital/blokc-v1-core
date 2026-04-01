// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { LibStorageSlot } from "../../libraries/LibStorageSlot.sol";

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

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
    address internal constant INDEX_FACTORY_ADDRESS = 0x37E983b2369BEE476C808696E5e9d64eA244A7A2;

    /// @notice IndexComponentRegistry contract address
    address internal constant INDEX_COMPONENT_REGISTRY_ADDRESS = 0xD8614dc6eE0230e21D591B3825a75A282EeaE2fB;

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

    /// @notice Module identifier for DEX facets; only selectors in this module are allowed during rebalance.
    bytes32 internal constant DEX_MODULE_ID = keccak256("DEX");

    /// @notice Storage layout for index-related state
    struct Layout {
        address indexAddress;
        uint256 lastRebalanceTimestamp;
        bool rebalancing;
    }

    /// @notice Returns a pointer to the index storage layout
    function layout() internal pure returns (Layout storage l) {
        bytes32 position = LibStorageSlot.deriveStorageSlot(type(IndexStorage).name);

        assembly {
            l.slot := position
        }
    }
}
