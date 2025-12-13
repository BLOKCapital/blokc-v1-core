// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.31;

/*###############################################################################

    @title IndexStorage
    @author BLOK Capital DAO
    @notice Storage layout and constants for Index-related facets
    @dev Uses diamond storage pattern with a fixed storage slot to ensure 
         compatibility across diamond upgrades. Contains Arbitrum One mainnet
         addresses for tokens, oracles, and registries.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

library IndexStorage {
    /// @notice Fixed storage slot for index-related persistent state
    /// @dev Uses keccak256 hash to generate unique storage position
    bytes32 internal constant INDEX_STORAGE_POSITION = keccak256("index.storage");

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
    address internal constant INDEX_FACTORY_ADDRESS = 0x320873b52432573384682054981277673E577014;

    /// @notice IndexComponentRegistry contract address
    address internal constant INDEX_COMPONENT_REGISTRY_ADDRESS = 0x5692577D77b886977946e755928349797843264b;

    // ========================================================================
    // Rebalancing Parameters
    // ========================================================================

    /// @notice Rebalance threshold in basis points (0.01%)
    uint256 internal constant REBALANCE_THRESHOLD = 0.0001e18;

    /// @notice WETH token decimals
    uint256 internal constant WETH_DECIMALS = 18;

    /// @notice Precision for calculations (1e18 = 100%)
    uint256 internal constant PRECISION = 1e18;

    /// @notice Minimum USDC amount to trigger swap (100 USDC with 6 decimals)
    uint256 internal constant MIN_SWAP_AMOUNT = 10 ** 5;

    /// @notice Minimum WETH value for rebalance operations (0.01 WETH)
    uint256 internal constant MIN_REBALANCE_VALUE_WETH = 0.01e18;

    /// @notice Maximum slippage tolerance in basis points (5% = 500 bps)
    uint256 internal constant MAX_SLIPPAGE_BPS = 500;

    /// @notice Swap deadline in seconds (30 minutes)
    uint256 internal constant SWAP_DEADLINE_SECONDS = 1800;

    /// @notice Maximum number of assets allowed in an index
    uint256 internal constant MAX_ASSETS = 30;

    /// @notice Storage layout for index-related state
    /// @param indexAddress Address of the connected Index contract
    /// @param lastRebalanceTimestamp Block timestamp of last rebalance
    struct Layout {
        address indexAddress;
        uint256 lastRebalanceTimestamp;
    }

    /// @notice Returns a pointer to the index storage layout
    /// @return l Storage pointer to Layout struct
    function layout() internal pure returns (Layout storage l) {
        bytes32 position = INDEX_STORAGE_POSITION;

        assembly {
            l.slot := position
        }
    }
}
