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
contract GmxV2Facet is Facet, GmxV2Base {
    /// @inheritdoc IGmxV2
    function gmxV2OpenShort(GmxV2OpenShortParams calldata params)
        external
        payable
        override
        onlyGardenOwner
        nonReentrant
        ifIndexNotConnected
        returns (bytes32 positionKey)
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
    {
        _gmxV2CloseShort(params);
    }

    /// @inheritdoc IGmxV2
    function gmxV2AddCollateral(
        bytes32 positionKey,
        uint256 collateralAmount
    )
        external
        override
        onlyGardenOwner
        nonReentrant
        ifIndexNotConnected
    {
        _gmxV2AddCollateral(positionKey, collateralAmount);
    }

    /// @inheritdoc IGmxV2
    function gmxV2UpdateConfig(uint256 maxLeverage, uint256 minCollateralUsd) external override onlyGardenOwner {
        _gmxV2UpdateConfig(maxLeverage, minCollateralUsd);
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
