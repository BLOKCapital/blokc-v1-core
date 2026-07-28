// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

// Local Contracts
import { Facet } from "src/garden/facets/Facet.sol";
import { GmxV2Base } from "src/garden/facets/utilityFacets/arbitrumOne/gmxV2/GmxV2Base.sol";

// Local Interfaces
import { IGmxV2 } from "src/garden/facets/utilityFacets/arbitrumOne/gmxV2/IGmxV2.sol";
import {
    IOrderCallbackReceiver,
    GmxEventUtils
} from "src/garden/facets/utilityFacets/arbitrumOne/gmxV2/IGmxV2Callback.sol";

// Local Libraries
import { GmxV2Storage } from "src/garden/facets/utilityFacets/arbitrumOne/gmxV2/GmxV2Storage.sol";

/**
 * @title GmxV2Facet
 * @author BLOK Capital DAO
 * @notice Facet that implements the IGmxV2 interface to allow garden owners to manage short positions on GMX V2
 * protocol. This facet provides external functions for opening and closing short positions, adding collateral, and
 * querying position information and PnL. It inherits from GmxV2Base which contains the internal logic for interacting
 * with GMX V2, while GmxV2Facet itself provides the external interface for these operations with appropriate access
 * control and user-facing error messages.
 */
contract GmxV2Facet is Facet, GmxV2Base, IOrderCallbackReceiver {
    /// @inheritdoc IGmxV2
    function gmxV2OpenShort(GmxV2OpenShortParams calldata params)
        external
        payable
        override
        onlyGardenOwner
        nonReentrant
        ifIndexNotConnected
        returns (bytes32 orderKey)
    {
        return _gmxV2OpenShort(params);
    }

    /// @inheritdoc IGmxV2
    function gmxV2CloseShort(GmxV2CloseShortParams calldata params)
        external
        payable
        override
        onlyGardenOwner
        nonReentrant
        ifIndexNotConnected
        returns (bytes32 orderKey)
    {
        return _gmxV2CloseShort(params);
    }

    /// @inheritdoc IGmxV2
    function gmxV2AddCollateral(GmxV2AddCollateralParams calldata params)
        external
        payable
        override
        onlyGardenOwner
        nonReentrant
        ifIndexNotConnected
        returns (bytes32 orderKey)
    {
        return _gmxV2AddCollateral(params);
    }

    /// @notice GMX keeper callback fired after an order executes successfully
    /// @dev Only callable by a GMX handler (CONTROLLER role). Promotes/updates the target position.
    /// The event payloads are ignored; work is correlated by the order key alone.
    function afterOrderExecution(
        bytes32 key,
        GmxEventUtils.EventLogData memory orderData,
        GmxEventUtils.EventLogData memory eventData
    )
        external
        override
        nonReentrant
    {
        _validateGmxCallback();
        _handleOrderExecution(key, orderData, eventData);
    }

    /// @notice GMX keeper callback fired after an order is cancelled
    /// @dev Only callable by a GMX handler. Clears the pending order; collateral was refunded by GMX.
    function afterOrderCancellation(
        bytes32 key,
        GmxEventUtils.EventLogData memory,
        GmxEventUtils.EventLogData memory
    )
        external
        override
        nonReentrant
    {
        _validateGmxCallback();
        _handleOrderCancellation(key);
    }

    /// @notice GMX keeper callback fired after an order is frozen
    /// @dev Only callable by a GMX handler. Clears the pending order; funds remain in the vault pending retry.
    function afterOrderFrozen(
        bytes32 key,
        GmxEventUtils.EventLogData memory,
        GmxEventUtils.EventLogData memory
    )
        external
        override
        nonReentrant
    {
        _validateGmxCallback();
        _handleOrderCancellation(key);
    }

    /// @inheritdoc IGmxV2
    /// @dev `ifIndexNotConnected` matches the other state-changing functions on this facet: an
    /// index-connected garden must not have its leverage or collateral risk parameters altered.
    function gmxV2UpdateConfig(
        uint256 maxLeverage,
        uint256 minCollateralUsd
    )
        external
        override
        onlyGardenOwner
        ifIndexNotConnected
    {
        _gmxV2UpdateConfig(maxLeverage, minCollateralUsd);
    }

    /// @inheritdoc IGmxV2
    function gmxV2CancelOrder(bytes32 orderKey)
        external
        payable
        override
        onlyGardenOwner
        nonReentrant
        ifIndexNotConnected
    {
        _gmxV2CancelOrder(orderKey);
    }

    /// @notice Registers this facet as the GMX callback for a market, so liquidation/ADL orders call back
    /// @dev MUST be called once per market before (or alongside) the first short on that market. Until it
    /// is, GMX-initiated orders — liquidations and ADLs — are not reported back and stored position state
    /// silently diverges from the on-chain position. Idempotent; re-calling rewrites the same record.
    /// See `GmxV2Base._gmxV2SetSavedCallback` for the full limitation note and the planned automatic
    /// ("lazy") registration that would remove this manual step.
    /// @param market The GMX market to register for
    function gmxV2RegisterCallback(address market) external onlyGardenOwner nonReentrant ifIndexNotConnected {
        _gmxV2SetSavedCallback(market);
    }

    /// @inheritdoc IGmxV2
    function gmxV2GetPosition(bytes32 positionKey)
        external
        view
        override
        returns (GmxV2Storage.PositionInfo memory position)
    {
        return _gmxV2GetPosition(positionKey);
    }

    /// @inheritdoc IGmxV2
    function gmxV2GetActivePositions() external view override returns (GmxV2Storage.PositionInfo[] memory positions) {
        return _gmxV2GetActivePositions();
    }

    /// @inheritdoc IGmxV2
    function gmxV2GetPositionPnL(bytes32 positionKey) external view override returns (int256 pnl) {
        return _gmxV2GetPositionPnL(positionKey);
    }

    /// @inheritdoc IGmxV2
    function gmxV2GetTotalCollateral() external view override returns (uint256 totalCollateral) {
        return _gmxV2GetTotalCollateral();
    }

    /// @inheritdoc IGmxV2
    function gmxV2GetActivePositionCount() external view override returns (uint256 count) {
        return _gmxV2GetActivePositionCount();
    }

    /// @notice Gets current configuration parameters
    /// @return maxLeverage Maximum leverage allowed
    /// @return minCollateralUsd Minimum collateral required
    function gmxV2GetConfig() external view returns (uint256 maxLeverage, uint256 minCollateralUsd) {
        return _gmxV2GetConfig();
    }
}
