// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    @title IGmxV2
    @author BLOK Capital DAO
    @notice Interface for GMX V2 protocol integration
    @dev Interface for GMX V2 protocol integration
         This interface provides the functions to open/close short positions.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import { GmxV2Storage } from "src/garden/facets/utilityFacets/arbitrumOne/gmxV2/GmxV2Storage.sol";

interface IGmxV2 {
    // ========================================================================
    // Structs
    // ========================================================================

    /// @notice Parameters for opening a short position
    struct OpenShortParams {
        address indexToken; // Token to short (e.g., WETH, WBTC)
        address collateralToken; // Collateral token (e.g., USDC, USDT)
        uint256 collateralAmount; // Amount of collateral to deposit
        uint256 sizeInUsd; // Position size in USD (30 decimals)
        uint256 acceptablePrice; // Maximum acceptable price for entry (30 decimals)
        uint256 executionFee; // Fee for keeper execution
        address callbackContract; // Optional callback contract
    }

    /// @notice Parameters for closing a short position
    struct CloseShortParams {
        bytes32 positionKey; // Position identifier
        uint256 sizeInUsd; // Size to close in USD (0 = close entire position)
        uint256 acceptablePrice; // Minimum acceptable price for exit (30 decimals)
        uint256 executionFee; // Fee for keeper execution
    }

    // ========================================================================
    // Events
    // ========================================================================

    /// @notice Emitted when a short position is opened
    event ShortPositionOpened(
        bytes32 indexed positionKey,
        address indexed indexToken,
        address indexed collateralToken,
        uint256 sizeInUsd,
        uint256 collateralAmount
    );

    /// @notice Emitted when a short position is closed
    event ShortPositionClosed(bytes32 indexed positionKey, address indexed indexToken, uint256 sizeInUsd, int256 pnl);

    /// @notice Emitted when collateral is added to a position
    event CollateralAdded(bytes32 indexed positionKey, uint256 amount);

    // ========================================================================
    // External Functions
    // ========================================================================

    /// @notice Opens a new short position on GMX V2
    /// @param params Parameters for opening the short position
    /// @return positionKey The unique identifier for the opened position
    function openShort(OpenShortParams calldata params) external payable returns (bytes32 positionKey);

    /// @notice Closes an existing short position
    /// @param params Parameters for closing the position
    function closeShort(CloseShortParams calldata params) external payable;

    /// @notice Adds collateral to an existing position
    /// @param positionKey The position to add collateral to
    /// @param collateralAmount Amount of collateral to add
    function addCollateral(bytes32 positionKey, uint256 collateralAmount) external;

    /// @notice Gets information about a specific position
    /// @param positionKey The position identifier
    /// @return position The position information struct
    function getPosition(bytes32 positionKey) external view returns (GmxV2Storage.PositionInfo memory position);

    /// @notice Gets all active positions
    /// @return positions Array of all active position information
    function getActivePositions() external view returns (GmxV2Storage.PositionInfo[] memory positions);

    /// @notice Gets the current PnL for a position
    /// @param positionKey The position identifier
    /// @return pnl The profit and loss in USD (30 decimals), negative for losses
    function getPositionPnL(bytes32 positionKey) external view returns (int256 pnl);

    /// @notice Gets total collateral locked across all positions
    /// @return totalCollateral Total collateral in USD
    function getTotalCollateral() external view returns (uint256 totalCollateral);

    /// @notice Gets the number of active positions
    /// @return count Number of active positions
    function getActivePositionCount() external view returns (uint256 count);

    /// @notice Updates configuration parameters
    /// @param maxLeverage Maximum leverage allowed
    /// @param minCollateralUsd Minimum collateral required in USD (30 decimals)
    function updateConfig(uint256 maxLeverage, uint256 minCollateralUsd) external;
}
