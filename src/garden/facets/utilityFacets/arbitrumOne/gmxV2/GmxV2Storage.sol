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
    /// @notice Position information for tracking shorts
    struct PositionInfo {
        bytes32 positionKey; // Unique position identifier from GMX
        address indexToken; // The token being shorted (e.g., WETH, WBTC)
        address collateralToken; // Token used as collateral (e.g., USDC)
        uint256 sizeInUsd; // Position size in USD (30 decimals)
        uint256 collateralAmount; // Amount of collateral deposited
        uint256 timestamp; // When position was opened
        bool isShort; // True for short positions
        bool isActive; // Whether position is currently open
    }

    /// @notice Diamond storage layout for GMX V2 facet state
    struct Layout {
        /// @notice Mapping from position key to position info
        mapping(bytes32 => PositionInfo) positions;
        /// @notice Array of all position keys for enumeration
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
