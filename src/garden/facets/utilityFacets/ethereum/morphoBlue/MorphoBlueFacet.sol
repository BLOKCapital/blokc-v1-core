// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################
 *
 *    @title MorphoFacet
 *    @author BLOK Capital DAO
 *    @notice Facet exposing Morpho Blue integration functions (supply / withdraw)
 *    @dev Mirrors the structure of AaveV3Facet: a thin facet that delegates to
 *         MorphoBase and is gated by the shared Facet base (owner / index checks).
 *
 *##############################################################################*/

import { MarketParams } from "@morphoBlue/src/interfaces/IMorpho.sol";
import { IMorphoBlue } from "src/garden/facets/utilityFacets/ethereum/morphoBlue/IMorphoBlue.sol";
import { MorphoBlueBase } from "src/garden/facets/utilityFacets/ethereum/morphoBlue/MorphoBlueBase.sol";
import { Facet } from "src/garden/facets/Facet.sol";

contract MorphoBlueFacet is IMorphoBlue, MorphoBlueBase, Facet {
    // ========================================================================
    // External Functions (State-Changing)
    // ========================================================================

    /// @notice Supplies liquidity to a Morpho Blue market on behalf of the garden itself
    /// @param marketParams The market parameters (loanToken, collateralToken, oracle, irm, lltv)
    /// @param assets The amount of assets to supply
    /// @param shares Must be 0 — supply is only supported by assets
    /// @param data Additional data for the supply operation
    /// @return assetsSupplied The actual amount of assets supplied
    /// @return sharesSupplied The actual amount of shares supplied
    function morphoBlueSupply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        bytes calldata data
    )
        external
        override
        onlyGardenOwner
        ifIndexNotConnected
        nonReentrant
        returns (uint256, uint256)
    {
        return _morphoBlueSupplyInternal(marketParams, assets, shares, data);
    }

    /// @notice Withdraws liquidity from the garden's own position in a Morpho Blue market
    /// @param marketParams The market parameters (loanToken, collateralToken, oracle, irm, lltv)
    /// @param assets The amount of assets to withdraw (0 to use shares instead)
    /// @param shares The amount of shares to withdraw (0 to use assets instead)
    /// @return assetsWithdrawn The actual amount of assets withdrawn
    /// @return sharesWithdrawn The actual amount of shares withdrawn
    function morphoBlueWithdraw(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares
    )
        external
        override
        onlyGardenOwner
        ifIndexNotConnected
        nonReentrant
        returns (uint256, uint256)
    {
        return _morphoBlueWithdrawInternal(marketParams, assets, shares);
    }
}
