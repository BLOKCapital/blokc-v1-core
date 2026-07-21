// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { GmxV2Storage } from "src/garden/facets/utilityFacets/arbitrumOne/gmxV2/GmxV2Storage.sol";

/// @title IGmxV2
/// @author BLOK Capital DAO
/// @notice Interface for interacting with GMX V2 protocol, including opening and closing short positions, adding
/// collateral, and querying position information. This interface defines the core functions that a GmxV2Facet would
/// implement to allow garden owners to manage short positions on GMX V2, as well as events for tracking these
/// operations. The interface includes functions for opening shorts with specified parameters, closing shorts with PnL
/// realization, adding collateral to existing positions, and retrieving position information and PnL. It also includes
/// a function for updating configuration parameters such as maximum leverage and minimum collateral requirements.
interface IGmxV2 {
    /// @notice Parameters for opening a short position
    struct GmxV2OpenShortParams {
        address indexToken; // Token to short (e.g., WETH, WBTC)
        address collateralToken; // Collateral token (e.g., USDC, USDT)
        uint256 collateralAmount; // Amount of collateral to deposit
        uint256 sizeInUsd; // Position size in USD (30 decimals)
        uint256 acceptablePrice; // Maximum acceptable price for entry (30 decimals)
        uint256 executionFee; // Fee for keeper execution
        address market; // GMX market (per-pair address; cannot be derived from indexToken)
    }

    /// @notice Parameters for closing a short position
    struct GmxV2CloseShortParams {
        bytes32 positionKey; // Position identifier
        uint256 sizeInUsd; // Size to close in USD (0 = close entire position)
        uint256 acceptablePrice; // Minimum acceptable price for exit (30 decimals)
        uint256 executionFee; // Fee for keeper execution
        address market; // GMX market; move into PositionInfo during the storage-model rework
    }

    /// @notice Emitted when a short position is opened
    /// @param positionKey The unique identifier for the position
    /// @param indexToken The token being shorted
    /// @param collateralToken The token used as collateral
    /// @param sizeInUsd The position size in USD (30 decimals)
    /// @param collateralAmount The amount of collateral deposited
    event GmxV2ShortPositionOpened(
        bytes32 indexed positionKey,
        address indexed indexToken,
        address indexed collateralToken,
        uint256 sizeInUsd,
        uint256 collateralAmount
    );

    /// @notice Emitted when a short position is closed
    /// @param positionKey The unique identifier for the position
    /// @param indexToken The token that was shorted
    /// @param sizeInUsd The size closed in USD (30 decimals)
    /// @param pnl The profit and loss realized
    event GmxV2ShortPositionClosed(
        bytes32 indexed positionKey, address indexed indexToken, uint256 sizeInUsd, int256 pnl
    );

    /// @notice Emitted when collateral is added to a position
    /// @param positionKey The unique identifier for the position
    /// @param amount The amount of collateral added
    event GmxV2CollateralAdded(bytes32 indexed positionKey, uint256 amount);

    /// @notice Opens a new short position on GMX V2
    /// @param params Parameters for opening the short position
    /// @return positionKey The unique identifier for the opened position
    function gmxV2OpenShort(GmxV2OpenShortParams calldata params) external payable returns (bytes32 positionKey);

    /// @notice Closes an existing short position
    /// @param params Parameters for closing the position
    function gmxV2CloseShort(GmxV2CloseShortParams calldata params) external payable;

    /// @notice Adds collateral to an existing position
    /// @param positionKey The position to add collateral to
    /// @param collateralAmount Amount of collateral to add
    function gmxV2AddCollateral(bytes32 positionKey, uint256 collateralAmount) external;

    /// @notice Gets information about a specific position
    /// @param positionKey The position identifier
    /// @return position The position information struct
    function gmxV2GetPosition(bytes32 positionKey) external view returns (GmxV2Storage.PositionInfo memory position);

    /// @notice Gets all active positions
    /// @return positions Array of all active position information
    function gmxV2GetActivePositions() external view returns (GmxV2Storage.PositionInfo[] memory positions);

    /// @notice Gets the current PnL for a position
    /// @param positionKey The position identifier
    /// @return pnl The profit and loss in USD (30 decimals), negative for losses
    function gmxV2GetPositionPnL(bytes32 positionKey) external view returns (int256 pnl);

    /// @notice Gets total collateral locked across all positions
    /// @return totalCollateral Total collateral in USD
    function gmxV2GetTotalCollateral() external view returns (uint256 totalCollateral);

    /// @notice Gets the number of active positions
    /// @return count Number of active positions
    function gmxV2GetActivePositionCount() external view returns (uint256 count);

    /// @notice Updates configuration parameters
    /// @param maxLeverage Maximum leverage allowed
    /// @param minCollateralUsd Minimum collateral required in USD (30 decimals)
    function gmxV2UpdateConfig(uint256 maxLeverage, uint256 minCollateralUsd) external;
}
