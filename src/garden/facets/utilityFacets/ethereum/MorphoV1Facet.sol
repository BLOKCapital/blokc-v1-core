// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################
 *
 *    @title MorphoFacet
 *    @author BLOK Capital DAO
 *    @notice Facet exposing Morpho Blue integration functions (supply / withdraw / borrow / repay / accrue / create market)
 *    @dev Mirrors the structure of AaveV3Facet: a thin facet that delegates to
 *         MorphoBase and is gated by the shared Facet base (owner / index checks).
 *
 *##############################################################################*/

import { MarketParams } from "@morphoBlue/src/interfaces/IMorpho.sol";
import { IMorphoV1 } from "src/garden/facets/utilityFacets/ethereum/IMorphoV1.sol";
import { MorphoV1Base } from "src/garden/facets/utilityFacets/ethereum/MorphoV1Base.sol";
import { Facet } from "src/garden/facets/Facet.sol";

contract MorphoV1Facet is IMorphoV1, MorphoV1Base, Facet {
    // ========================================================================
    // External Functions (State-Changing)
    // ========================================================================

    /// @inheritdoc IMorphoV1
    function supplyToMorphoV1(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external override onlyGardenOwner ifIndexNotConnected returns (uint256, uint256) {
        return _supplyToMorphoV1Internal(marketParams, assets, shares, onBehalf, data);
    }

    /// @inheritdoc IMorphoV1
    function withdrawFromMorphoV1(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external override onlyGardenOwner ifIndexNotConnected returns (uint256, uint256) {
        return _withdrawFromMorphoV1Internal(marketParams, assets, shares, onBehalf, receiver);
    }

    /// @inheritdoc IMorphoV1
    function borrowFromMorphoV1(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external override onlyGardenOwner ifIndexNotConnected returns (uint256, uint256) {
        return _borrowFromMorphoV1Internal(marketParams, assets, shares, onBehalf, receiver);
    }

    /// @inheritdoc IMorphoV1
    function repayToMorphoV1(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf
    ) external override onlyGardenOwner ifIndexNotConnected returns (uint256, uint256) {
        return _repayToMorphoV1Internal(marketParams, assets, shares, onBehalf);
    }

    /// @inheritdoc IMorphoV1
    function accrueInterestMorphoV1(MarketParams memory marketParams)
        external
        override
        onlyGardenOwner
        ifIndexNotConnected
    {
        _accrueInterestMorphoV1Internal(marketParams);
    }

    /// @inheritdoc IMorphoV1
    function createMarketForMorphoV1(MarketParams memory marketParams)
        external
        override
        onlyGardenOwner
        ifIndexNotConnected
    {
        _createMarketForMorphoV1Internal(marketParams);
    }
}
