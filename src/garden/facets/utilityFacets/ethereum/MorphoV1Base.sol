// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################
 *
 *    @title MorphoBase
 *    @author BLOK Capital DAO
 *    @notice Base contract for MorphoFacet exposing Morpho Blue integration functions
 *            (supply / withdraw / borrow / repay / accrue / create market)
 *    @dev This base contract provides common functionality for MorphoFacet. It keeps
 *         the Morpho Blue core address as a compile-time constant and exposes
 *         thin internal wrappers around the protocol.
 *
 *    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
 *    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
 *    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
 *    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘
 *
 *##############################################################################*/

import { IMorphoBase, MarketParams, Id } from "@morphoBlue/src/interfaces/IMorpho.sol";

abstract contract MorphoV1Base {
    /// @notice Hardcoded Morpho Blue core contract address on Ethereum mainnet
    /// @dev Kept as an immutable compile-time constant (no dedicated storage)
    address internal constant MORPHO_BLUE_CORE = 0x33333aea097c193e66081E930c33020272b33333;

    /// @notice Internal helper to get the Morpho Blue core interface
    function _morpho() internal pure returns (IMorphoBase) {
        return IMorphoBase(MORPHO_BLUE_CORE);
    }

    /// @notice Internal helper to supply liquidity to a Morpho Blue v1 market
    function _supplyToMorphoV1Internal(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) internal returns (uint256, uint256) {
        return _morpho().supply(marketParams, assets, shares, onBehalf, data);
    }

    /// @notice Internal helper to withdraw liquidity from a Morpho Blue v1 market
    function _withdrawFromMorphoV1Internal(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) internal returns (uint256, uint256) {
        return _morpho().withdraw(marketParams, assets, shares, onBehalf, receiver);
    }

    /// @notice Internal helper to borrow from a Morpho Blue v1 market
    function _borrowFromMorphoV1Internal(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) internal returns (uint256, uint256) {
        return _morpho().borrow(marketParams, assets, shares, onBehalf, receiver);
    }

    /// @notice Internal helper to repay a Morpho Blue v1 position
    function _repayToMorphoV1Internal(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf
    ) internal returns (uint256, uint256) {
        return _morpho().repay(marketParams, assets, shares, onBehalf, "");
    }

    /// @notice Internal helper to accrue interest on a Morpho Blue v1 market
    function _accrueInterestMorphoV1Internal(MarketParams memory marketParams) internal {
        _morpho().accrueInterest(marketParams);
    }

    /// @notice Internal helper to create a new Morpho Blue v1 market
    function _createMarketForMorphoV1Internal(MarketParams memory marketParams) internal {
        _morpho().createMarket(marketParams);
    }
}


