// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

// OpenZeppelin Contracts
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Local Interfaces
import { IGmxV2 } from "src/garden/facets/utilityFacets/arbitrumOne/gmxV2/IGmxV2.sol";

// Local Libraries
import { GmxV2Storage } from "src/garden/facets/utilityFacets/arbitrumOne/gmxV2/GmxV2Storage.sol";

/// @title Order
/// @author BLOK Capital DAO
/// @notice Mirrors the enums in GMX V2 `contracts/order/Order.sol`.
/// @dev Member ordering is consensus-critical. Each value is encoded as its uint8 ordinal, so members
/// must never be reordered, renamed away from their ordinal meaning, or omitted — a wrong ordinal still
/// produces a valid selector and is therefore silently accepted by GMX as a different operation.
library Order {
    enum OrderType {
        MarketSwap,
        LimitSwap,
        MarketIncrease,
        LimitIncrease,
        MarketDecrease,
        LimitDecrease,
        StopLossDecrease,
        Liquidation,
        StopIncrease
    }

    enum DecreasePositionSwapType {
        NoSwap,
        SwapPnlTokenToCollateralToken,
        SwapCollateralTokenToPnlToken
    }
}

/// @title IExchangeRouter
/// @author BLOK Capital DAO
/// @notice Interface for GMX V2 ExchangeRouter contract
interface IExchangeRouter {
    /// @notice Parameters for creating an order on GMX V2
    /// @dev Layout must match GMX `IBaseOrderUtils.CreateOrderParams` exactly. The struct shape
    /// determines both the function selector (0xf59c48eb) and the calldata encoding.
    struct CreateOrderParams {
        CreateOrderParamsAddresses addresses;
        CreateOrderParamsNumbers numbers;
        Order.OrderType orderType;
        Order.DecreasePositionSwapType decreasePositionSwapType;
        bool isLong;
        bool shouldUnwrapNativeToken;
        bool autoCancel;
        bytes32 referralCode;
        bytes32[] dataList;
    }

    struct CreateOrderParamsAddresses {
        address receiver;
        address cancellationReceiver;
        address callbackContract;
        address uiFeeReceiver;
        address market;
        address initialCollateralToken;
        address[] swapPath;
    }

    struct CreateOrderParamsNumbers {
        uint256 sizeDeltaUsd;
        uint256 initialCollateralDeltaAmount;
        uint256 triggerPrice;
        uint256 acceptablePrice;
        uint256 executionFee;
        uint256 callbackGasLimit;
        uint256 minOutputAmount;
        uint256 validFromTime;
    }

    /// @notice Creates a new order on GMX V2
    /// @param params The order parameters
    /// @return The order key
    function createOrder(CreateOrderParams calldata params) external payable returns (bytes32);

    /// @notice Cancels an existing order
    /// @param key The order key to cancel
    function cancelOrder(bytes32 key) external;

    function sendWnt(address receiver, uint256 amount) external payable;
    //sendTokens implements hook pluginTransfer
    function sendTokens(address token, address receiver, uint256 amount) external payable;
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory);
}

/// @title IReader
/// @author BLOK Capital DAO
/// @notice Interface for GMX V2 Reader contract for querying position data
interface IReader {
    /// @notice Position data structure returned by the Reader
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

    /// @notice Gets position data from the data store
    /// @param dataStore The GMX data store address
    /// @param key The position key
    /// @return The position data
    function getPosition(address dataStore, bytes32 key) external view returns (Position memory);

    /// @notice Gets the PnL for a position in USD
    /// @param dataStore The GMX data store address
    /// @param market The market address
    /// @param indexToken The index token address
    /// @param isLong Whether the position is long
    /// @param sizeDeltaUsd The size delta in USD
    /// @return The PnL values
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

/**
 * @title GmxV2Base
 * @author BLOK Capital DAO
 * @notice Base contract that implements internal functions for managing short positions on GMX V2, including opening
 * and closing shorts, adding collateral, and querying position information. This contract is intended to be inherited
 * by a GmxV2Facet that exposes these functions with appropriate access control and user-facing error messages. It
 * includes the core logic for interacting with the GMX V2 ExchangeRouter to create orders for opening and closing
 * positions, as well as using the Reader to get position data and calculate PnL. The contract also manages position
 * state within the garden's storage layout.
 */
abstract contract GmxV2Base is IGmxV2 {
    using SafeERC20 for IERC20;

    /// @notice GMX V2 ExchangeRouter on Arbitrum Sepolia
    address private constant GMX_EXCHANGE_ROUTER = 0xEd50B2A1eF0C35DAaF08Da6486971180237909c3;

    //router address has to be made available at prod apart from just exchange router
    address private constant GMX_ROUTER = 0x0000000000000000000000000000000000000000;

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

    /// @notice Gas forwarded to this contract's order callbacks by GMX keepers
    /// @dev Must be non-zero or `afterOrderExecution` / `afterOrderCancellation` / `afterOrderFrozen` are
    /// never invoked, leaving position lifecycle state stale. Must also stay at or below GMX's configured
    /// MAX_CALLBACK_GAS_LIMIT, and the execution fee must be large enough to cover it.
    uint256 private constant CALLBACK_GAS_LIMIT = 200_000;

    /// @notice GMX referral code applied to orders originating from gardens
    /// @dev Protocol-level constant, never caller-supplied. Set to a registered BLOK code to earn GMX
    /// referral rebates on garden flow; bytes32(0) disables referral attribution.
    bytes32 private constant REFERRAL_CODE = bytes32(0);

    /// @notice Opens a new short position on GMX V2
    /// @param params Parameters for opening the short position
    /// @return positionKey The unique identifier for the opened position
    function _gmxV2OpenShort(GmxV2OpenShortParams calldata params) internal returns (bytes32 orderKey) {
        GmxV2Storage.Layout storage s = GmxV2Storage.layout();

        // Initialize config if not set
        if (s.maxLeverage == 0) {
            s.maxLeverage = DEFAULT_MAX_LEVERAGE;
            s.minCollateralUsd = DEFAULT_MIN_COLLATERAL_USD;
        }

        // Validate
        if (params.collateralAmount == 0) revert GmxV2Base_InsufficientCollateral();
        if (params.executionFee == 0) revert GmxV2Base_InsufficientExecutionFee();

        // Calculate leverage
        uint256 leverage = (params.sizeInUsd * 1e18) / (params.collateralAmount * 1e18);
        if (leverage > s.maxLeverage * 1e18) revert GmxV2Base_ExcessiveLeverage();

        // Transfer collateral from diamond to this contract
        IERC20 collateralToken = IERC20(params.collateralToken);
        uint256 balance = collateralToken.balanceOf(address(this));
        if (balance < params.collateralAmount) revert GmxV2Base_InsufficientBalance();

        // Build GMX order params
        IExchangeRouter.CreateOrderParams memory orderParams = _buildOpenOrderParams(params);

        bytes[] memory calls = new bytes[](3);
        uint256 i;
        calls[i++] = abi.encodeCall(IExchangeRouter.sendWnt, (GMX_ORDER_VAULT, executionFee));

        collateralToken.forceApprove(GMX_ROUTER, collateralAmount);
        calls[i++] =
            abi.encodeCall(IExchangeRouter.sendTokens, (address(collateralToken), GMX_ORDER_VAULT, collateralAmount));

        calls[i++] = abi.encodeCall(IExchangeRouter.createOrder, (orderParams));
        bytes[] memory results = IExchangeRouter(GMX_EXCHANGE_ROUTER).multicall{ value: executionFee }(calls);
        orderKey = abi.decode(results[2], (bytes32));

        /**
         * positionKey aspect yet to be reveiwed and implemented precisely
         */

        // Create order on GMX (send execution fee as msg.value)
        // // Store position info

        // s.positions[positionKey] = GmxV2Storage.PositionInfo({
        //     positionKey: positionKey,
        //     indexToken: params.indexToken,
        //     collateralToken: params.collateralToken,
        //     sizeInUsd: params.sizeInUsd,
        //     collateralAmount: params.collateralAmount,
        //     timestamp: block.timestamp,
        //     isShort: true,
        //     isActive: true
        // });

        // // Add to position keys array
        // s.positionKeys.push(positionKey);
        // s.activePositionCount++;
        // s.totalCollateralLocked += params.collateralAmount;
        // s.lastInteractionTimestamp = block.timestamp;

        emit GmxV2ShortPositionOpened(
            orderKey, params.indexToken, params.collateralToken, params.sizeInUsd, params.collateralAmount
        );

        return orderKey;
    }

    /// @notice Closes an existing short position on GMX V2
    /// @param params Parameters for closing the position
    function _gmxV2CloseShort(GmxV2CloseShortParams calldata params) internal {
        GmxV2Storage.Layout storage s = GmxV2Storage.layout();

        GmxV2Storage.PositionInfo storage position = s.positions[params.positionKey];
        if (!position.isActive) revert GmxV2Base_PositionNotActive();

        // Get current PnL
        int256 pnl = _gmxV2GetPositionPnL(params.positionKey);

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

        emit GmxV2ShortPositionClosed(params.positionKey, position.indexToken, sizeToClose, pnl);
    }

    /// @notice Adds collateral to an existing position
    /// @param positionKey The position to add collateral to
    /// @param collateralAmount Amount of collateral to add
    function _gmxV2AddCollateral(bytes32 positionKey, uint256 collateralAmount) internal {
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

        emit GmxV2CollateralAdded(positionKey, collateralAmount);
    }

    /// @notice Gets information about a specific position
    /// @param positionKey The position identifier
    /// @return position The position information struct
    function _gmxV2GetPosition(bytes32 positionKey) internal view returns (GmxV2Storage.PositionInfo memory position) {
        return GmxV2Storage.layout().positions[positionKey];
    }

    /// @notice Gets all active positions
    /// @return positions Array of all active position information
    function _gmxV2GetActivePositions() internal view returns (GmxV2Storage.PositionInfo[] memory positions) {
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
    function _gmxV2GetPositionPnL(bytes32 positionKey) internal view returns (int256 pnl) {
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
    function _gmxV2GetTotalCollateral() internal view returns (uint256 totalCollateral) {
        return GmxV2Storage.layout().totalCollateralLocked;
    }

    /// @notice Gets the number of active positions
    /// @return count Number of active positions
    function _gmxV2GetActivePositionCount() internal view returns (uint256 count) {
        return GmxV2Storage.layout().activePositionCount;
    }

    /// @notice Updates configuration parameters for leverage and collateral limits
    /// @param maxLeverage Maximum leverage allowed
    /// @param minCollateralUsd Minimum collateral required in USD
    function _gmxV2UpdateConfig(uint256 maxLeverage, uint256 minCollateralUsd) internal {
        if (maxLeverage == 0 || maxLeverage > 50) revert GmxV2Facet_InvalidParameters();
        if (minCollateralUsd == 0) revert GmxV2Facet_InvalidParameters();
        GmxV2Storage.Layout storage s = GmxV2Storage.layout();
        s.maxLeverage = maxLeverage;
        s.minCollateralUsd = minCollateralUsd;
    }

    /// @notice Gets current configuration parameters
    /// @return maxLeverage Maximum leverage allowed
    /// @return minCollateralUsd Minimum collateral required
    function _gmxV2GetConfig() internal view returns (uint256 maxLeverage, uint256 minCollateralUsd) {
        GmxV2Storage.Layout storage s = GmxV2Storage.layout();
        return (s.maxLeverage, s.minCollateralUsd);
    }

    /// @notice Builds GMX order parameters for opening a short position
    /// @param params The open short parameters
    /// @return The GMX CreateOrderParams struct
    function _buildOpenOrderParams(GmxV2OpenShortParams calldata params)
        private
        view
        returns (IExchangeRouter.CreateOrderParams memory)
    {
        IExchangeRouter.CreateOrderParamsAddresses memory addresses = IExchangeRouter.CreateOrderParamsAddresses({
            receiver: address(this),
            cancellationReceiver: address(this),
            callbackContract: address(this),
            uiFeeReceiver: address(0),
            market: params.market,
            initialCollateralToken: params.collateralToken,
            swapPath: new address[](0)
        });

        // `initialCollateralDeltaAmount` is ignored for increase orders — GMX overwrites it with
        // `orderVault.recordTransferIn(...)`, i.e. whatever collateral actually reached the OrderVault.
        // `triggerPrice` must be zero for market orders; a non-zero value makes it a trigger order.
        IExchangeRouter.CreateOrderParamsNumbers memory numbers = IExchangeRouter.CreateOrderParamsNumbers({
            sizeDeltaUsd: params.sizeInUsd,
            initialCollateralDeltaAmount: 0,
            triggerPrice: 0,
            acceptablePrice: params.acceptablePrice,
            executionFee: params.executionFee,
            callbackGasLimit: CALLBACK_GAS_LIMIT,
            minOutputAmount: 0,
            validFromTime: 0
        });

        return IExchangeRouter.CreateOrderParams({
            addresses: addresses,
            numbers: numbers,
            orderType: Order.OrderType.MarketIncrease,
            decreasePositionSwapType: Order.DecreasePositionSwapType.NoSwap,
            isLong: false,
            shouldUnwrapNativeToken: false,
            autoCancel: false,
            referralCode: REFERRAL_CODE,
            dataList: new bytes32[](0)
        });
    }

    /// @notice Builds GMX order parameters for closing a short position
    /// @param params The close short parameters
    /// @param position The current position information
    /// @return The GMX CreateOrderParams struct
    function _buildCloseOrderParams(
        GmxV2CloseShortParams calldata params,
        GmxV2Storage.PositionInfo storage position
    )
        private
        view
        returns (IExchangeRouter.CreateOrderParams memory)
    {
        uint256 sizeToClose = params.sizeInUsd == 0 ? position.sizeInUsd : params.sizeInUsd;

        IExchangeRouter.CreateOrderParamsAddresses memory addresses = IExchangeRouter.CreateOrderParamsAddresses({
            receiver: address(this),
            cancellationReceiver: address(this),
            callbackContract: address(this),
            uiFeeReceiver: address(0),
            market: params.market,
            initialCollateralToken: position.collateralToken,
            swapPath: new address[](0)
        });

        // Unlike the increase path, `initialCollateralDeltaAmount` IS read for decrease orders — it is the
        // amount of collateral to withdraw. Zero leaves collateral withdrawal to GMX, which returns the
        // remaining collateral on a full close.
        IExchangeRouter.CreateOrderParamsNumbers memory numbers = IExchangeRouter.CreateOrderParamsNumbers({
            sizeDeltaUsd: sizeToClose,
            initialCollateralDeltaAmount: 0,
            triggerPrice: 0,
            acceptablePrice: params.acceptablePrice,
            executionFee: params.executionFee,
            callbackGasLimit: CALLBACK_GAS_LIMIT,
            minOutputAmount: 0,
            validFromTime: 0
        });

        return IExchangeRouter.CreateOrderParams({
            addresses: addresses,
            numbers: numbers,
            orderType: Order.OrderType.MarketDecrease,
            decreasePositionSwapType: Order.DecreasePositionSwapType.NoSwap,
            isLong: false,
            shouldUnwrapNativeToken: false,
            autoCancel: false,
            referralCode: REFERRAL_CODE,
            dataList: new bytes32[](0)
        });
    }
}
