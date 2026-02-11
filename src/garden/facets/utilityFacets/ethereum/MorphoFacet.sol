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
import { MorphoBase } from "src/garden/facets/utilityFacets/ethereum/MorphoBase.sol";
import { Facet } from "src/garden/facets/Facet.sol";

contract MorphoFacet is MorphoBase, Facet {
    // ========================================================================
    // External Functions (State-Changing)
    // ========================================================================

    /// @notice Supply to a Morpho Blue market
    function supply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external onlyGardenOwner ifIndexNotConnected returns (uint256, uint256) {
        return _supplyMorpho(marketParams, assets, shares, onBehalf, data);
    }

    /// @notice Withdraw from a Morpho Blue market
    function withdraw(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external onlyGardenOwner ifIndexNotConnected returns (uint256, uint256) {
        return _withdrawMorpho(marketParams, assets, shares, onBehalf, receiver);
    }

    /// @notice Borrow from a Morpho Blue market
    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external onlyGardenOwner ifIndexNotConnected returns (uint256, uint256) {
        return _borrowMorpho(marketParams, assets, shares, onBehalf, receiver);
    }

    /// @notice Repay a Morpho Blue position
    function repay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf
    ) external onlyGardenOwner ifIndexNotConnected returns (uint256, uint256) {
        return _repayMorpho(marketParams, assets, shares, onBehalf);
    }

    /// @notice Accrue interest on a Morpho Blue market
    function accrueInterest(MarketParams memory marketParams)
        external
        onlyGardenOwner
        ifIndexNotConnected
    {
        _accrueInterestMorpho(marketParams);
    }

    /// @notice Create a new Morpho Blue market
    function createMarket(MarketParams memory marketParams)
        external
        onlyGardenOwner
        ifIndexNotConnected
    {
        _createMarketMorpho(marketParams);
    }
}
