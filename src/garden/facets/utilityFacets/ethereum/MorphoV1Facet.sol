// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################
 *
 *    @title MorphoFacet
 *    @author BLOK Capital DAO
 *    @notice Facet exposing Morpho Blue integration functions (supply / withdraw / borrow / repay)
 *    @dev Mirrors the structure of AaveV3Facet: a thin facet that delegates to
 *         MorphoBase and is gated by the shared Facet base (owner / index checks).
 *
 *##############################################################################*/

import { MarketParams } from "@morphoBlue/src/interfaces/IMorpho.sol";
import { IMorphoBlue } from "src/garden/facets/utilityFacets/ethereum/IMorphoV1.sol";
import { MorphoBlueBase } from "src/garden/facets/utilityFacets/ethereum/MorphoV1Base.sol";
import { Facet } from "src/garden/facets/Facet.sol";

contract MorphoBlueFacet is IMorphoBlue, MorphoBlueBase, Facet {
    // ========================================================================
    // External Functions (State-Changing)
    // ========================================================================

    /// @notice Supplies liquidity to a Morpho Blue market
    /// @param marketParams The market parameters (loanToken, collateralToken, oracle, irm, lltv)
    /// @param assets The amount of assets to supply (0 to use shares instead)
    /// @param shares The amount of shares to supply (0 to use assets instead)
    /// @param onBehalf The address to supply on behalf of
    /// @param data Additional data for the supply operation
    /// @return assetsSupplied The actual amount of assets supplied
    /// @return sharesSupplied The actual amount of shares supplied
    function morphoBlueSupply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external override onlyGardenOwner ifIndexNotConnected returns (uint256, uint256) {
        return _morphoBlueSupplyInternal(marketParams, assets, shares, onBehalf, data);
    }

    /// @notice Withdraws liquidity from a Morpho Blue market
    /// @param marketParams The market parameters (loanToken, collateralToken, oracle, irm, lltv)
    /// @param assets The amount of assets to withdraw (0 to use shares instead)
    /// @param shares The amount of shares to withdraw (0 to use assets instead)
    /// @param onBehalf The address to withdraw from
    /// @param receiver The address to receive the withdrawn assets
    /// @return assetsWithdrawn The actual amount of assets withdrawn
    /// @return sharesWithdrawn The actual amount of shares withdrawn
    function morphoBlueWithdraw(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external override onlyGardenOwner ifIndexNotConnected returns (uint256, uint256) {
        return _morphoBlueWithdrawInternal(marketParams, assets, shares, onBehalf, receiver);
    }

    /// @notice Borrows assets from a Morpho Blue market
    /// @param marketParams The market parameters (loanToken, collateralToken, oracle, irm, lltv)
    /// @param assets The amount of assets to borrow (0 to use shares instead)
    /// @param shares The amount of shares to borrow (0 to use assets instead)
    /// @param onBehalf The address to borrow on behalf of
    /// @param receiver The address to receive the borrowed assets
    /// @return assetsBorrowed The actual amount of assets borrowed
    /// @return sharesBorrowed The actual amount of shares borrowed
    function morphoBlueBorrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external override onlyGardenOwner ifIndexNotConnected returns (uint256, uint256) {
        return _morphoBlueBorrowInternal(marketParams, assets, shares, onBehalf, receiver);
    }

    /// @notice Repays a borrowed position in a Morpho Blue market
    /// @param marketParams The market parameters (loanToken, collateralToken, oracle, irm, lltv)
    /// @param assets The amount of assets to repay (0 to use shares instead)
    /// @param shares The amount of shares to repay (0 to use assets instead)
    /// @param onBehalf The address to repay on behalf of
    /// @return assetsRepaid The actual amount of assets repaid
    /// @return sharesRepaid The actual amount of shares repaid
    function morphoBlueRepay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf
    ) external override onlyGardenOwner ifIndexNotConnected returns (uint256, uint256) {
        return _morphoBlueRepayInternal(marketParams, assets, shares, onBehalf);
    }
}
