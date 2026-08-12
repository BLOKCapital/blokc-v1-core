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
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// Local Interfaces
import { IGmxV2 } from "src/garden/facets/utilityFacets/arbitrumOne/gmxV2/IGmxV2.sol";
import { IndexComponentRegistry } from "src/indices/IndexComponentRegistry.sol";
import { IndexStorage } from "src/garden/facets/indexFacets/IndexStorage.sol";

/// @title IGmxRoleStore
/// @notice Minimal view into GMX's RoleStore, used to authenticate order callbacks.
interface IGmxRoleStore {
    function hasRole(address account, bytes32 roleKey) external view returns (bool);
}

// Local Libraries
import { GmxV2Storage } from "src/garden/facets/utilityFacets/arbitrumOne/gmxV2/GmxV2Storage.sol";
import { GmxEventUtils } from "src/garden/facets/utilityFacets/arbitrumOne/gmxV2/IGmxV2Callback.sol";

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
    //for gmx side control surfaces like ADL
    function setSavedCallbackContract(address market, address callbackContract) external payable;
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

/// @notice Thrown when an order callback is not from an authorized GMX handler
error GmxV2Base_UnauthorizedCallback();

/// @notice Thrown when an expected field is absent from a GMX callback payload
error GmxV2Base_CallbackFieldNotFound();

/// @notice Thrown when the collateral token has no registered price feed, so risk rails cannot be applied
error GmxV2Base_CollateralNotPriceable();

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

    /// @notice GMX V2 ExchangeRouter on Arbitrum One
    /// @dev GMX redeploys the ExchangeRouter periodically; re-verify against
    /// gmx-synthetics/deployments/arbitrum/ExchangeRouter.json before each deployment.
    address internal constant GMX_EXCHANGE_ROUTER = 0x1C3fa76e6E1088bCE750f23a5BFcffa1efEF6A41;

    /// @notice GMX V2 Router on Arbitrum One — the token-approval target
    /// @dev Distinct from the ExchangeRouter. `sendTokens` executes `router.pluginTransfer`, so ERC20
    /// allowances for collateral must be granted to this address, not the ExchangeRouter.
    address internal constant GMX_ROUTER = 0x7452c558d45f8afC8c83dAe62C3f8A5BE19c71f6;

    /// @notice GMX V2 OrderVault on Arbitrum One — where collateral and execution fee are deposited
    address internal constant GMX_ORDER_VAULT = 0x31eF83a530Fde1B38EE9A18093A333D8Bbbc40D5;

    /// @notice GMX V2 Reader on Arbitrum One
    address internal constant GMX_READER = 0x470fbC46bcC0f16532691Df360A07d8Bf5ee0789;

    /// @notice GMX V2 DataStore on Arbitrum One
    address internal constant GMX_DATASTORE = 0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8;

    /// @notice GMX V2 RoleStore on Arbitrum One — authority for validating order callbacks
    address internal constant GMX_ROLE_STORE = 0x3c3d99FD298f679DBC2CEcd132b4eC4d0F5e6e72;

    /// @notice GMX CONTROLLER role key. Order execution callbacks originate from GMX handler contracts
    /// which hold this role; validating the caller against it prevents forged position-state updates.
    bytes32 internal constant GMX_CONTROLLER = keccak256(abi.encode("CONTROLLER"));

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

    /// @notice Submits a GMX order via the mandatory sendWnt → sendTokens → createOrder multicall
    /// @dev Both transfers must precede createOrder in the same transaction: GMX credits the order by the
    /// OrderVault's balance delta (StrictBank.recordTransferIn), so any gap lets another caller claim the
    /// funds. `collateralAmount == 0` (decrease orders) omits the sendTokens leg.
    /// @return orderKey The GMX order key returned by createOrder
    function _submitOrder(
        IExchangeRouter.CreateOrderParams memory orderParams,
        address collateralToken,
        uint256 collateralAmount,
        uint256 executionFee
    )
        private
        returns (bytes32 orderKey)
    {
        uint256 n = collateralAmount > 0 ? 3 : 2;
        bytes[] memory calls = new bytes[](n);
        uint256 i;

        calls[i++] = abi.encodeCall(IExchangeRouter.sendWnt, (GMX_ORDER_VAULT, executionFee));
        if (collateralAmount > 0) {
            IERC20(collateralToken).forceApprove(GMX_ROUTER, collateralAmount);
            calls[i++] =
                abi.encodeCall(IExchangeRouter.sendTokens, (collateralToken, GMX_ORDER_VAULT, collateralAmount));
        }
        calls[i++] = abi.encodeCall(IExchangeRouter.createOrder, (orderParams));

        bytes[] memory results = IExchangeRouter(GMX_EXCHANGE_ROUTER).multicall{ value: executionFee }(calls);
        orderKey = abi.decode(results[n - 1], (bytes32));
    }

    /// @notice Converts a collateral token amount into GMX-scale USD (30 decimals)
    /// @dev Uses the protocol's Chainlink-backed IndexComponentRegistry, matching the pricing path already
    /// used by IndexBase and Rebalancer, rather than assuming a $1 peg (the hardcoded-peg pattern was
    /// flagged as a finding elsewhere in this codebase). The registry returns an 8-decimal USD price, so
    /// the value is scaled by 1e22 to reach GMX's 30-decimal USD convention.
    ///
    /// Reverts if the collateral token is not registered in the component registry: silently skipping the
    /// conversion would disable the leverage and minimum-collateral rails rather than surface the gap.
    ///
    /// NOTE: `fetchPrice` caches per block and is therefore state-mutating, so this cannot be `view`.
    /// @param collateralToken The collateral token address
    /// @param collateralAmount The amount in the token's own decimals
    /// @param collateralSymbol The registry symbol for the collateral token
    /// @return collateralUsd The value in USD with 30 decimals
    function _collateralValueUsd30(
        address collateralToken,
        uint256 collateralAmount,
        bytes32 collateralSymbol
    )
        private
        returns (uint256 collateralUsd)
    {
        IndexComponentRegistry registry = IndexComponentRegistry(IndexStorage.INDEX_COMPONENT_REGISTRY_ADDRESS);
        if (!registry.isComponentRegistered(collateralSymbol)) revert GmxV2Base_CollateralNotPriceable();

        uint256 price = registry.fetchPrice(collateralSymbol);
        uint8 tokenDecimals = IERC20Metadata(collateralToken).decimals();

        // price is 8-decimal USD; result of mulDiv is 8-decimal USD; 1e22 lifts it to GMX's 30 decimals.
        uint256 usd8 = Math.mulDiv(collateralAmount, price, 10 ** tokenDecimals, Math.Rounding.Floor);
        collateralUsd = usd8 * 1e22;
    }

    /// @notice Derives the GMX position key for a short held by this contract
    /// @dev Matches GMX Position.getPositionKey: keccak256(account, market, collateralToken, isLong).
    /// account is this diamond; isLong is always false (shorts only).
    function _positionKey(address market, address collateralToken) private view returns (bytes32) {
        return keccak256(abi.encode(address(this), market, collateralToken, false));
    }

    /// @notice Appends a position key for enumeration if not already present
    function _addPositionKey(GmxV2Storage.Layout storage s, bytes32 key) private {
        uint256 len = s.positionKeys.length;
        for (uint256 i; i < len; i++) {
            if (s.positionKeys[i] == key) return;
        }
        s.positionKeys.push(key);
    }

    /// @notice Opens a new short position on GMX V2 (submits a MarketIncrease order)
    /// @dev The position does not exist until a keeper executes the order; this records a pending order and
    /// mutates no position state. Promotion to an active position happens in the execution callback.
    /// @param params Parameters for opening the short position
    /// @return orderKey The GMX order key for the submitted increase order
    function _gmxV2OpenShort(GmxV2OpenShortParams calldata params) internal returns (bytes32 orderKey) {
        GmxV2Storage.Layout storage s = GmxV2Storage.layout();

        if (s.maxLeverage == 0) {
            s.maxLeverage = DEFAULT_MAX_LEVERAGE;
            s.minCollateralUsd = DEFAULT_MIN_COLLATERAL_USD;
        }

        if (params.collateralAmount == 0) revert GmxV2Base_InsufficientCollateral();
        if (params.executionFee == 0) revert GmxV2Base_InsufficientExecutionFee();
        if (msg.value < params.executionFee) revert GmxV2Base_InsufficientExecutionFee();

        // mentioning the audit findings below temperorily
        // Risk rails. `sizeInUsd` is GMX-scale USD (30 decimals) while `collateralAmount` is in the token's
        // own decimals, so the collateral must be priced into the same scale before either can be compared
        // against it. Comparing the two directly (as the previous implementation did) mixes scales and
        // overstates leverage by orders of magnitude.
        uint256 collateralUsd =
            _collateralValueUsd30(params.collateralToken, params.collateralAmount, params.collateralSymbol);
        if (collateralUsd == 0) revert GmxV2Base_InsufficientCollateral();
        if (collateralUsd < s.minCollateralUsd) revert GmxV2Base_InsufficientCollateral();

        // maxLeverage is a plain multiplier (e.g. 10 == 10x). Multiplying avoids a division and the
        // precision loss that comes with it.
        if (params.sizeInUsd > collateralUsd * s.maxLeverage) revert GmxV2Base_ExcessiveLeverage();

        if (IERC20(params.collateralToken).balanceOf(address(this)) < params.collateralAmount) {
            revert GmxV2Base_InsufficientBalance();
        }

        IExchangeRouter.CreateOrderParams memory orderParams = _buildOpenOrderParams(params);
        orderKey = _submitOrder(orderParams, params.collateralToken, params.collateralAmount, params.executionFee);

        s.pendingOrders[orderKey] = GmxV2Storage.PendingOrder({
            positionKey: _positionKey(params.market, params.collateralToken),
            kind: GmxV2Storage.OrderKind.Increase,
            sizeDeltaUsd: params.sizeInUsd,
            collateralDelta: params.collateralAmount,
            market: params.market,
            indexToken: params.indexToken,
            collateralToken: params.collateralToken,
            exists: true
        });

        s.lastInteractionTimestamp = block.timestamp;
    }

    /// @notice Closes or reduces an existing short position on GMX V2 (submits a MarketDecrease order)
    /// @dev Records a pending decrease order; the position mirror is updated only when a keeper executes it.
    /// @param params Parameters for closing the position
    /// @return orderKey The GMX order key for the submitted decrease order
    function _gmxV2CloseShort(GmxV2CloseShortParams calldata params) internal returns (bytes32 orderKey) {
        GmxV2Storage.Layout storage s = GmxV2Storage.layout();

        GmxV2Storage.PositionInfo storage position = s.positions[params.positionKey];
        if (!position.isActive) revert GmxV2Base_PositionNotActive();
        if (params.executionFee == 0) revert GmxV2Base_InsufficientExecutionFee();
        if (msg.value < params.executionFee) revert GmxV2Base_InsufficientExecutionFee();

        uint256 sizeToClose = params.sizeInUsd == 0 ? position.sizeInUsd : params.sizeInUsd;

        IExchangeRouter.CreateOrderParams memory orderParams = _buildCloseOrderParams(params, position);
        // Decrease orders send no collateral in — only the execution fee.
        orderKey = _submitOrder(orderParams, address(0), 0, params.executionFee);

        s.pendingOrders[orderKey] = GmxV2Storage.PendingOrder({
            positionKey: params.positionKey,
            kind: GmxV2Storage.OrderKind.Decrease,
            sizeDeltaUsd: sizeToClose,
            collateralDelta: 0,
            market: position.market,
            indexToken: position.indexToken,
            collateralToken: position.collateralToken,
            exists: true
        });

        s.lastInteractionTimestamp = block.timestamp;
    }

    /// @notice Adds collateral to an existing position (submits a MarketIncrease order with zero size delta)
    /// @dev Same order path as opening, with sizeDeltaUsd = 0. Mirror updated on the execution callback.
    /// @param params Parameters identifying the position and collateral to add
    /// @return orderKey The GMX order key for the submitted increase order
    function _gmxV2AddCollateral(GmxV2AddCollateralParams calldata params) internal returns (bytes32 orderKey) {
        GmxV2Storage.Layout storage s = GmxV2Storage.layout();

        GmxV2Storage.PositionInfo storage position = s.positions[params.positionKey];
        if (!position.isActive) revert GmxV2Base_PositionNotActive();
        if (params.collateralAmount == 0) revert GmxV2Base_InsufficientCollateral();
        if (params.executionFee == 0) revert GmxV2Base_InsufficientExecutionFee();
        if (msg.value < params.executionFee) revert GmxV2Base_InsufficientExecutionFee();

        if (IERC20(position.collateralToken).balanceOf(address(this)) < params.collateralAmount) {
            revert GmxV2Base_InsufficientBalance();
        }

        IExchangeRouter.CreateOrderParams memory orderParams = _buildAddCollateralOrderParams(position, params);
        orderKey = _submitOrder(orderParams, position.collateralToken, params.collateralAmount, params.executionFee);

        s.pendingOrders[orderKey] = GmxV2Storage.PendingOrder({
            positionKey: params.positionKey,
            kind: GmxV2Storage.OrderKind.Increase,
            sizeDeltaUsd: 0,
            collateralDelta: params.collateralAmount,
            market: position.market,
            indexToken: position.indexToken,
            collateralToken: position.collateralToken,
            exists: true
        });

        s.lastInteractionTimestamp = block.timestamp;
    }

    // Collector helpers for _settleExternalDecrease: GMX packs order fields into a generic key-value bag
    // (EventLogData), so each field is fetched by looping the relevant bucket and matching the key string.
    // Strings cannot be compared with ==, so keys are compared by keccak256 hash.

    /// @notice Reads an address field from a GMX EventLogData bag by key
    function _getAddress(GmxEventUtils.EventLogData memory d, string memory k) private pure returns (address) {
        bytes32 want = keccak256(bytes(k));
        uint256 len = d.addressItems.items.length;
        for (uint256 i; i < len; i++) {
            if (keccak256(bytes(d.addressItems.items[i].key)) == want) {
                return d.addressItems.items[i].value;
            }
        }
        revert GmxV2Base_CallbackFieldNotFound();
    }

    /// @notice Reads a uint field from a GMX EventLogData bag by key
    function _getUint(GmxEventUtils.EventLogData memory d, string memory k) private pure returns (uint256) {
        bytes32 want = keccak256(bytes(k));
        uint256 len = d.uintItems.items.length;
        for (uint256 i; i < len; i++) {
            if (keccak256(bytes(d.uintItems.items[i].key)) == want) {
                return d.uintItems.items[i].value;
            }
        }
        revert GmxV2Base_CallbackFieldNotFound();
    }

    /// @notice Reads a bool field from a GMX EventLogData bag by key
    function _getBool(GmxEventUtils.EventLogData memory d, string memory k) private pure returns (bool) {
        bytes32 want = keccak256(bytes(k));
        uint256 len = d.boolItems.items.length;
        for (uint256 i; i < len; i++) {
            if (keccak256(bytes(d.boolItems.items[i].key)) == want) {
                return d.boolItems.items[i].value;
            }
        }
        revert GmxV2Base_CallbackFieldNotFound();
    }

    /// @notice Applies a size reduction to a known position (shared by garden closes and liquidation/ADL)
    /// @dev No-op if the position is already inactive, so a duplicate or late callback cannot underflow.
    /// @param positionKey The position to reduce
    /// @param sizeDelta The size reduction in USD (30 decimals); clamped to the position's current size
    function _settleDecrease(bytes32 positionKey, uint256 sizeDelta) private {
        GmxV2Storage.Layout storage s = GmxV2Storage.layout();
        GmxV2Storage.PositionInfo storage position = s.positions[positionKey];
        if (!position.isActive) return;

        uint256 sizeReduced = sizeDelta >= position.sizeInUsd ? position.sizeInUsd : sizeDelta;
        if (sizeReduced >= position.sizeInUsd) {
            s.totalCollateralLocked -= position.collateralAmount;
            s.activePositionCount--;
            position.sizeInUsd = 0;
            position.collateralAmount = 0;
            position.isActive = false;
        } else {
            uint256 released = (position.collateralAmount * sizeReduced) / position.sizeInUsd;
            position.sizeInUsd -= sizeReduced;
            position.collateralAmount -= released;
            s.totalCollateralLocked -= released;
        }
        // PnL is reported as 0 until Reader integration (#11); realized PnL is not tracked on-chain here.
        emit GmxV2ShortPositionClosed(positionKey, position.indexToken, sizeReduced, int256(0));
    }

    /// @notice Settles a GMX-initiated decrease (liquidation / ADL) that has no pending order record
    /// @dev Reconstructs the position key from the order fields in the callback payload. Guards that the
    /// order belongs to this contract before mutating any state.
    function _settleExternalDecrease(GmxEventUtils.EventLogData memory orderData) private {
        if (_getAddress(orderData, "account") != address(this)) return;

        address market = _getAddress(orderData, "market");
        address collateralToken = _getAddress(orderData, "initialCollateralToken");
        bool isLong = _getBool(orderData, "isLong");
        uint256 sizeDelta = _getUint(orderData, "sizeDeltaUsd");

        bytes32 positionKey = keccak256(abi.encode(address(this), market, collateralToken, isLong));
        _settleDecrease(positionKey, sizeDelta);
    }

    /// @notice Handles a GMX order-execution callback: promotes or updates the target position
    /// @dev An unknown or already-cleared order key is a no-op so the keeper's execution is never blocked.
    /// Size/collateral are best-effort mirrors; GMX (via Reader) is authoritative for exact values.
    function _handleOrderExecution(
        bytes32 orderKey,
        GmxEventUtils.EventLogData memory orderData,
        GmxEventUtils.EventLogData memory eventData
    )
        internal
    {
        GmxV2Storage.Layout storage s = GmxV2Storage.layout();
        GmxV2Storage.PendingOrder memory po = s.pendingOrders[orderKey];

        // No pending record → GMX-initiated order (liquidation / ADL). Reconstruct the position from the
        // order fields carried in the callback payload, settle it, then stop — there is nothing else to do.
        if (!po.exists) {
            _settleExternalDecrease(orderData);
            return;
        }
        delete s.pendingOrders[orderKey];

        if (po.kind == GmxV2Storage.OrderKind.Increase) {
            GmxV2Storage.PositionInfo storage position = s.positions[po.positionKey];
            if (!position.isActive) {
                position.positionKey = po.positionKey;
                position.market = po.market;
                position.indexToken = po.indexToken;
                position.collateralToken = po.collateralToken;
                position.timestamp = block.timestamp;
                position.isShort = true;
                position.isActive = true;
                _addPositionKey(s, po.positionKey);
                s.activePositionCount++;
                emit GmxV2ShortPositionOpened(
                    po.positionKey, po.indexToken, po.collateralToken, po.sizeDeltaUsd, po.collateralDelta
                );
            }
            position.sizeInUsd += po.sizeDeltaUsd;
            position.collateralAmount += po.collateralDelta;
            s.totalCollateralLocked += po.collateralDelta;
        } else {
            _settleDecrease(po.positionKey, po.sizeDeltaUsd);
        }
    }

    /// @notice Handles a GMX order cancellation/frozen callback: clears the pending order
    /// @dev No position mutation — a cancelled increase already had its collateral refunded by GMX to the
    /// cancellationReceiver (this contract); a frozen order's funds remain in the vault pending retry.
    function _handleOrderCancellation(bytes32 orderKey) internal {
        GmxV2Storage.Layout storage s = GmxV2Storage.layout();
        if (s.pendingOrders[orderKey].exists) delete s.pendingOrders[orderKey];
    }

    /// @notice Cancels a pending GMX order that a keeper has not yet executed
    /// @dev Clears the local pending record so a later cancellation callback is a no-op. GMX returns any
    /// collateral held for the order to the cancellationReceiver, which this facet sets to itself.
    /// Reverts if the order is not one this contract submitted.
    /// @param orderKey The GMX order key to cancel
    function _gmxV2CancelOrder(bytes32 orderKey) internal {
        GmxV2Storage.Layout storage s = GmxV2Storage.layout();
        if (!s.pendingOrders[orderKey].exists) revert GmxV2Base_InvalidPositionKey();

        delete s.pendingOrders[orderKey];
        IExchangeRouter(GMX_EXCHANGE_ROUTER).cancelOrder(orderKey);

        s.lastInteractionTimestamp = block.timestamp;
    }

    /// @notice Registers this contract as the saved callback for a (garden, market) pair on GMX
    /// @dev Required for GMX-initiated orders (liquidation / ADL) to invoke our callbacks — those orders
    /// carry no callbackContract we set. msg.sender at GMX is this diamond, so the record is keyed to it.
    /// The record is written once per market into GMX's DataStore and persists; re-calling only rewrites
    /// the same value.
    ///
    /// LIMITATION — registration is currently MANUAL and is the known gap in this integration.
    /// Coverage depends on the garden owner calling `gmxV2RegisterCallback(market)` once per market. If
    /// that call is never made for a market, GMX has no callback address for orders it creates itself, so
    /// liquidations and ADLs on that market are never reported back: `_settleExternalDecrease` is never
    /// invoked and the stored PositionInfo continues to report `isActive == true` for a position GMX has
    /// already closed or reduced. Orders the garden submits are unaffected — those carry
    /// `callbackContract = address(this)` per order and always call back.
    ///
    /// FUTURE WORK : make registration automatic so it cannot be skipped: add a
    /// `mapping(address market => bool) callbackRegistered` to GmxV2Storage and, in `_gmxV2OpenShort`,
    /// call this function when the flag is unset before submitting the order, then set it. That guarantees
    /// a position can never exist without liquidation/ADL visibility.
    ///Note this is a storage-layout change
    /// (bump STORAGE_LAYOUT_VERSION) and the call must stay a separate transaction step — it must not be
    /// folded into the createOrder multicall, since the saved record is keyed by msg.sender. Retain this
    /// manual entry point regardless, as the escape hatch for positions opened before that change and for
    /// re-registering if GMX redeploys.
    /// @param market The GMX market to register for
    function _gmxV2SetSavedCallback(address market) internal {
        IExchangeRouter(GMX_EXCHANGE_ROUTER).setSavedCallbackContract(market, address(this));
    }

    /// @notice Validates that a callback originates from a GMX handler (holder of the CONTROLLER role)
    function _validateGmxCallback() internal view {
        if (!IGmxRoleStore(GMX_ROLE_STORE).hasRole(msg.sender, GMX_CONTROLLER)) {
            revert GmxV2Base_UnauthorizedCallback();
        }
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
            market: position.market,
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

    /// @notice Builds GMX order parameters for adding collateral to an existing short
    /// @dev A MarketIncrease with sizeDeltaUsd = 0. Market, index and collateral come from stored position
    /// state, not the caller, so collateral can only ever be added to a position this contract already holds.
    /// @param position The current position information
    /// @param params The add-collateral parameters
    /// @return The GMX CreateOrderParams struct
    function _buildAddCollateralOrderParams(
        GmxV2Storage.PositionInfo storage position,
        GmxV2AddCollateralParams calldata params
    )
        private
        view
        returns (IExchangeRouter.CreateOrderParams memory)
    {
        IExchangeRouter.CreateOrderParamsAddresses memory addresses = IExchangeRouter.CreateOrderParamsAddresses({
            receiver: address(this),
            cancellationReceiver: address(this),
            callbackContract: address(this),
            uiFeeReceiver: address(0),
            market: position.market,
            initialCollateralToken: position.collateralToken,
            swapPath: new address[](0)
        });

        IExchangeRouter.CreateOrderParamsNumbers memory numbers = IExchangeRouter.CreateOrderParamsNumbers({
            sizeDeltaUsd: 0,
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
}
