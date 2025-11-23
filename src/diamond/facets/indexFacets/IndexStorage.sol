// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.20;

/*###############################################################################

    @title Diamond Cut Storage
    @author BLOK Capital DAO
    @notice Storage layout used by the Diamond Cut facet and helpers.
    @dev Uses a fixed storage slot to ensure compatibility across diamond upgrades.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

library IndexStorage {
    /// @notice Fixed storage slot for index related persistent state.
    bytes32 internal constant INDEX_STORAGE_POSITION = keccak256("index.storage");

    //WETH is used as the base asset for the index on Arbitrum One
    address internal constant WETH_ADDRESS = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant USDC_ADDRESS = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // USDC on Arbitrum
    address internal constant WETH_PRICE_FEED_ADDRESS = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612; // ETH/USD on

    address internal constant INDEX_FACTORY_ADDRESS = 0x320873b52432573384682054981277673E577014;
    address internal constant INDEX_COMPONENT_REGISTRY_ADDRESS = 0x5692577D77b886977946e755928349797843264b;

    uint256 internal constant REBALANCE_THRESHOLD = 0.0001e18; // 0.01% threshold
    uint256 internal constant WETH_DECIMALS = 18;
    uint256 internal constant PRECISION = 1e18;
    uint256 internal constant MIN_SWAP_AMOUNT = 10 ** 5; // Minimum amount for swap (100 USDC with 6 decimals)
    uint256 internal constant MIN_REBALANCE_VALUE_WETH = 0.01e18; // 0.01 WETH minimum rebalance value (~$30 at $3000
        // ETH)
    uint256 internal constant MAX_SLIPPAGE_BPS = 500; // 5% max slippage in basis points
    uint256 internal constant SWAP_DEADLINE_SECONDS = 1800; // 30 minutes
    uint256 internal constant MAX_ASSETS = 30; // Maximum number of assets in an index

    struct Layout {
        address indexAddress;
        uint256 lastRebalanceTimestamp;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 position = INDEX_STORAGE_POSITION;

        assembly {
            l.slot := position
        }
    }
}
