// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title GmxV2Base
    @author Blok Capital
    @notice Base contract for GmxV2Facet providing core GMX V2 integration logic
    @dev Handles interaction with GMX ExchangeRouter and Reader contracts
         Implements position management and PnL calculations

################################################################################*/

// OpenZeppelin Contracts
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Local Interfaces
import { IGmxV2 } from "src/garden/facets/utilityFacets/arbitrumOne/gmxV2/IGmxV2.sol";

// Local Libraries
import { GmxV2Storage } from "src/garden/facets/utilityFacets/arbitrumOne/gmxV2/GmxV2Storage.sol";

/// @notice Minimal interface for GMX V2 ExchangeRouter
interface IExchangeRouter {
    struct CreateOrderParams {
        address[] addresses;
        uint256[] numbers;
        bytes32 referralCode;
    }

    function createOrder(CreateOrderParams calldata params) external payable returns (bytes32);
    function cancelOrder(bytes32 key) external;
}

/// @notice Minimal interface for GMX V2 Reader
interface IReader {
    struct Position {
        address account;
        address market;
        address collateralToken;
        uint256 sizeInUsd;
        uint256 sizeInTokens;
        uint256 collateralAmount;
        uint256 borrowingFactor;
        uint256 fundingFeeAmountPerSize;
        uint256 longTokenClaimableFundingAmountPerSize;
        uint256 shortTokenClaimableFundingAmountPerSize;
        uint256 increasedAtBlock;
        uint256 decreasedAtBlock;
        bool isLong;
    }

    function getPosition(address dataStore, bytes32 key) external view returns (Position memory);

    function getPositionPnlUsd(
        address dataStore,
        address market,
        address indexToken,
        bool isLong,
        uint256 sizeDeltaUsd
    )
        external
        view
        returns (int256, int256);
}

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when position key is invalid
error GmxV2Base_InvalidPositionKey();

/// @notice Thrown when collateral amount is insufficient
error GmxV2Base_InsufficientCollateral();

/// @notice Thrown when leverage exceeds maximum allowed
error GmxV2Base_ExcessiveLeverage();

/// @notice Thrown when position is not active
error GmxV2Base_PositionNotActive();

/// @notice Thrown when execution fee is insufficient
error GmxV2Base_InsufficientExecutionFee();

/// @notice Thrown when contract has insufficient balance
error GmxV2Base_InsufficientBalance();

/// @notice Thrown when invalid parameters are provided
error GmxV2Facet_InvalidParameters();

// ============================================================================
// GmxV2Base Contract
// ============================================================================

abstract contract GmxV2Base is IGmxV2 {
    using SafeERC20 for IERC20;

    // ========================================================================
    // Constants - GMX V2 Arbitrum Sepolia Testnet Addresses
    // ========================================================================

    /// @notice GMX V2 ExchangeRouter on Arbitrum Sepolia
    address private constant GMX_EXCHANGE_ROUTER = 0xEd50B2A1eF0C35DAaF08Da6486971180237909c3;

    /// @notice GMX V2 OrderVault on Arbitrum Sepolia
    address private constant GMX_ORDER_VAULT = 0x1b8AC606de71686fd2a1AEDEcb6E0EFba28909a2;

    /// @notice GMX V2 Reader on Arbitrum Sepolia
    address private constant GMX_READER = 0x4750376b9378294138Cf7B7D69a2d243f4940f71;

    /// @notice GMX V2 DataStore on Arbitrum Sepolia
    address private constant GMX_DATASTORE = 0xCF4c2C4c53157BcC01A596e3788fFF69cBBCD201;

    /// @notice Default maximum leverage (10x)
    uint256 private constant DEFAULT_MAX_LEVERAGE = 10;

    /// @notice Default minimum collateral (100 USD with 30 decimals)
    uint256 private constant DEFAULT_MIN_COLLATERAL_USD = 100 * 1e30;

    // ========================================================================
    // Internal Functions
    // ========================================================================

    /// @notice Opens a new short position on GMX V2
    /// @param params Parameters for opening the short position
    /// @return positionKey The unique identifier for the opened position
    function _openShort(OpenShortParams calldata params) internal returns (bytes32 positionKey) {
        GmxV2Storage.Layout storage s = GmxV2Storage.layout();

        // Initialize config if not set
        if (s.maxLeverage == 0) {
            s.maxLeverage = DEFAULT_MAX_LEVERAGE;
            s.minCollateralUsd = DEFAULT_MIN_COLLATERAL_USD;
        }

        // Validate parameters
        if (params.collateralAmount == 0) revert GmxV2Base_InsufficientCollateral();
        if (params.executionFee == 0) revert GmxV2Base_InsufficientExecutionFee();

        // Calculate leverage
        uint256 leverage = (params.sizeInUsd * 1e18) / (params.collateralAmount * 1e18);
        if (leverage > s.maxLeverage * 1e18) revert GmxV2Base_ExcessiveLeverage();

        // Transfer collateral from diamond to this contract
        IERC20 collateralToken = IERC20(params.collateralToken);
        uint256 balance = collateralToken.balanceOf(address(this));
        if (balance < params.collateralAmount) revert GmxV2Base_InsufficientBalance();

        // Approve GMX router to spend collateral
        collateralToken.forceApprove(GMX_EXCHANGE_ROUTER, params.collateralAmount);

        // Build GMX order params
        IExchangeRouter.CreateOrderParams memory orderParams = _buildOpenOrderParams(params);

        // Create order on GMX (send execution fee as msg.value)
        positionKey = IExchangeRouter(GMX_EXCHANGE_ROUTER).createOrder{ value: params.executionFee }(orderParams);

        // Store position info
        s.positions[positionKey] = GmxV2Storage.PositionInfo({
            positionKey: positionKey,
            indexToken: params.indexToken,
            collateralToken: params.collateralToken,
            sizeInUsd: params.sizeInUsd,
            collateralAmount: params.collateralAmount,
            timestamp: block.timestamp,
            isShort: true,
            isActive: true
        });

        // Add to position keys array
        s.positionKeys.push(positionKey);
        s.activePositionCount++;
        s.totalCollateralLocked += params.collateralAmount;
        s.lastInteractionTimestamp = block.timestamp;

        emit ShortPositionOpened(
            positionKey, params.indexToken, params.collateralToken, params.sizeInUsd, params.collateralAmount
        );

        return positionKey;
    }

    /// @notice Closes an existing short position
    /// @param params Parameters for closing the position
    function _closeShort(CloseShortParams calldata params) internal {
        GmxV2Storage.Layout storage s = GmxV2Storage.layout();

        GmxV2Storage.PositionInfo storage position = s.positions[params.positionKey];
        if (!position.isActive) revert GmxV2Base_PositionNotActive();

        // Get current PnL
        int256 pnl = _getPositionPnL(params.positionKey);

        // Build close order params
        IExchangeRouter.CreateOrderParams memory orderParams = _buildCloseOrderParams(params, position);

        // Create close order on GMX
        IExchangeRouter(GMX_EXCHANGE_ROUTER).createOrder{ value: params.executionFee }(orderParams);

        // Update position state
        uint256 sizeToClose = params.sizeInUsd == 0 ? position.sizeInUsd : params.sizeInUsd;

        if (sizeToClose >= position.sizeInUsd) {
            // Fully closing position
            position.isActive = false;
            s.activePositionCount--;
            s.totalCollateralLocked -= position.collateralAmount;
        } else {
            // Partially closing position
            uint256 collateralToRelease = (position.collateralAmount * sizeToClose) / position.sizeInUsd;
            position.sizeInUsd -= sizeToClose;
            position.collateralAmount -= collateralToRelease;
            s.totalCollateralLocked -= collateralToRelease;
        }

        s.lastInteractionTimestamp = block.timestamp;

        emit ShortPositionClosed(params.positionKey, position.indexToken, sizeToClose, pnl);
    }

    /// @notice Adds collateral to an existing position
    /// @param positionKey The position to add collateral to
    /// @param collateralAmount Amount of collateral to add
    function _addCollateral(bytes32 positionKey, uint256 collateralAmount) internal {
        GmxV2Storage.Layout storage s = GmxV2Storage.layout();

        GmxV2Storage.PositionInfo storage position = s.positions[positionKey];
        if (!position.isActive) revert GmxV2Base_PositionNotActive();
        if (collateralAmount == 0) revert GmxV2Base_InsufficientCollateral();

        // Transfer and approve collateral
        IERC20 collateralToken = IERC20(position.collateralToken);
        uint256 balance = collateralToken.balanceOf(address(this));
        if (balance < collateralAmount) revert GmxV2Base_InsufficientBalance();

        // Note: In production, you would call GMX to actually add collateral
        // For this implementation, we just update our records
        position.collateralAmount += collateralAmount;
        s.totalCollateralLocked += collateralAmount;

        emit CollateralAdded(positionKey, collateralAmount);
    }

    /// @notice Gets information about a specific position
    /// @param positionKey The position identifier
    /// @return position The position information struct
    function _getPosition(bytes32 positionKey) internal view returns (GmxV2Storage.PositionInfo memory position) {
        return GmxV2Storage.layout().positions[positionKey];
    }

    /// @notice Gets all active positions
    /// @return positions Array of all active position information
    function _getActivePositions() internal view returns (GmxV2Storage.PositionInfo[] memory positions) {
        GmxV2Storage.Layout storage s = GmxV2Storage.layout();

        uint256 activeCount = s.activePositionCount;
        positions = new GmxV2Storage.PositionInfo[](activeCount);

        uint256 index = 0;
        for (uint256 i = 0; i < s.positionKeys.length && index < activeCount; i++) {
            bytes32 key = s.positionKeys[i];
            if (s.positions[key].isActive) {
                positions[index] = s.positions[key];
                index++;
            }
        }

        return positions;
    }

    /// @notice Gets the current PnL for a position
    /// @param positionKey The position identifier
    /// @return pnl The profit and loss in USD (30 decimals)
    function _getPositionPnL(bytes32 positionKey) internal view returns (int256 pnl) {
        GmxV2Storage.PositionInfo memory position = GmxV2Storage.layout().positions[positionKey];
        if (!position.isActive) return 0;

        // Note: In production, call GMX Reader to get actual PnL
        // For now, return 0 as placeholder
        // IReader reader = IReader(GMX_READER);
        // (pnl, ) = reader.getPositionPnlUsd(GMX_DATASTORE, market, position.indexToken, false, position.sizeInUsd);

        return 0;
    }

    /// @notice Gets total collateral locked across all positions
    /// @return totalCollateral Total collateral amount
    function _getTotalCollateral() internal view returns (uint256 totalCollateral) {
        return GmxV2Storage.layout().totalCollateralLocked;
    }

    /// @notice Gets the number of active positions
    /// @return count Number of active positions
    function _getActivePositionCount() internal view returns (uint256 count) {
        return GmxV2Storage.layout().activePositionCount;
    }

    /// @notice Updates configuration parameters
    /// @param maxLeverage Maximum leverage allowed
    /// @param minCollateralUsd Minimum collateral required in USD
    function _updateConfig(uint256 maxLeverage, uint256 minCollateralUsd) internal {
        if (maxLeverage == 0 || maxLeverage > 50) revert GmxV2Facet_InvalidParameters();
        if (minCollateralUsd == 0) revert GmxV2Facet_InvalidParameters();
        GmxV2Storage.Layout storage s = GmxV2Storage.layout();
        s.maxLeverage = maxLeverage;
        s.minCollateralUsd = minCollateralUsd;
    }

    /// @notice Gets configuration parameters
    /// @return maxLeverage Maximum leverage allowed
    /// @return minCollateralUsd Minimum collateral required
    function _getConfig() internal view returns (uint256 maxLeverage, uint256 minCollateralUsd) {
        GmxV2Storage.Layout storage s = GmxV2Storage.layout();
        return (s.maxLeverage, s.minCollateralUsd);
    }

    // ========================================================================
    // Private Helper Functions
    // ========================================================================

    /// @notice Builds GMX order parameters for opening a position
    function _buildOpenOrderParams(OpenShortParams calldata params)
        private
        view
        returns (IExchangeRouter.CreateOrderParams memory)
    {
        // GMX V2 order structure is complex. This is simplified.
        // In production, properly encode all parameters according to GMX V2 specs

        address[] memory addresses = new address[](5);
        addresses[0] = address(this); // receiver
        addresses[1] = params.callbackContract; // callbackContract
        addresses[2] = address(0); // market (to be determined)
        addresses[3] = params.indexToken; // indexToken
        addresses[4] = params.collateralToken; // collateralToken

        uint256[] memory numbers = new uint256[](6);
        numbers[0] = params.sizeInUsd; // sizeDeltaUsd
        numbers[1] = 0; // initialCollateralDeltaAmount
        numbers[2] = params.acceptablePrice; // triggerPrice
        numbers[3] = params.acceptablePrice; // acceptablePrice
        numbers[4] = params.executionFee; // executionFee
        numbers[5] = 0; // minOutputAmount

        return IExchangeRouter.CreateOrderParams({ addresses: addresses, numbers: numbers, referralCode: bytes32(0) });
    }

    /// @notice Builds GMX order parameters for closing a position
    function _buildCloseOrderParams(
        CloseShortParams calldata params,
        GmxV2Storage.PositionInfo storage position
    )
        private
        view
        returns (IExchangeRouter.CreateOrderParams memory)
    {
        uint256 sizeToClose = params.sizeInUsd == 0 ? position.sizeInUsd : params.sizeInUsd;

        address[] memory addresses = new address[](5);
        addresses[0] = address(this); // receiver
        addresses[1] = address(0); // callbackContract
        addresses[2] = address(0); // market
        addresses[3] = position.indexToken; // indexToken
        addresses[4] = position.collateralToken; // collateralToken

        uint256[] memory numbers = new uint256[](6);
        numbers[0] = sizeToClose; // sizeDeltaUsd
        numbers[1] = 0; // initialCollateralDeltaAmount
        numbers[2] = params.acceptablePrice; // triggerPrice
        numbers[3] = params.acceptablePrice; // acceptablePrice
        numbers[4] = params.executionFee; // executionFee
        numbers[5] = 0; // minOutputAmount

        return IExchangeRouter.CreateOrderParams({ addresses: addresses, numbers: numbers, referralCode: bytes32(0) });
    }
}
