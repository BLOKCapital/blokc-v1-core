// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################
 *
 *    @title MorphoBlueBase
 *    @author BLOK Capital DAO
 *    @notice Base contract for MorphoFacet exposing Morpho Blue integration functions
 *            (supply / withdraw / borrow / repay)
 *    @dev This base contract provides common functionality for MorphoFacet. It keeps
 *         the Morpho Blue core address as a compile-time constant and exposes
 *         thin internal wrappers around the protocol.
 *    @dev IMPORTANT: Morpho Blue is the standalone lending primitive, NOT the
 *         legacy Morpho V1 Optimizer. Blue uses isolated permissionless markets
 *         with a singleton core contract pattern.
 *
 *    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
 *    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
 *    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
 *    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘
 *
 *##############################################################################*/

import { IMorphoBase, MarketParams, Id } from "@morphoBlue/src/interfaces/IMorpho.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when market parameters are invalid
error MorphoBlueFacet_InvalidMarketParams();

/// @notice Thrown when onBehalf address is zero
error MorphoBlueFacet_InvalidOnBehalfAddress();

/// @notice Thrown when receiver address is zero
error MorphoBlueFacet_InvalidReceiverAddress();

abstract contract MorphoBlueBase {
    /// @notice Hardcoded Morpho Blue core contract address on Ethereum mainnet
    /// @dev Kept as an immutable compile-time constant (no dedicated storage)
    /// @dev Official Morpho Blue singleton address from: https://docs.morpho.org/get-started/resources/addresses/
    /// @dev Morpho Blue uses a singleton pattern - same address across all EVM chains
    /// @dev For other chains, check: https://docs.morpho.org/get-started/resources/addresses/
    /// @dev NOTE: This is Morpho Blue, the standalone lending primitive, NOT the legacy
    ///      Morpho V1 Optimizer. Blue features isolated permissionless markets.
    address internal constant MORPHO_BLUE_CORE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    /// @notice Internal helper to get the Morpho Blue core interface
    /// @dev Morpho Blue uses isolated markets identified by MarketParams (loanToken, collateralToken,
    ///      oracle, irm, lltv). Each unique combination creates a separate market with isolated risk.
    /// @dev RECOMMENDATION: For production, validate market IDs against a whitelist stored in your
    ///      protocol storage rather than hardcoding markets. This allows governance to add/remove
    ///      supported markets and validate oracle/LLTV before listing.
    function _morpho() internal pure returns (IMorphoBase) {
        return IMorphoBase(MORPHO_BLUE_CORE);
    }

    /// @notice Internal helper to supply liquidity to a Morpho Blue market
    function _morphoBlueSupplyInternal(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) internal returns (uint256, uint256) {
        if (onBehalf == address(0)) revert MorphoBlueFacet_InvalidOnBehalfAddress();
        if (marketParams.loanToken == address(0) || marketParams.collateralToken == address(0)) {
            revert MorphoBlueFacet_InvalidMarketParams();
        }
        return _morpho().supply(marketParams, assets, shares, onBehalf, data);
    }

    /// @notice Internal helper to withdraw liquidity from a Morpho Blue market
    function _morphoBlueWithdrawInternal(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) internal returns (uint256, uint256) {
        if (onBehalf == address(0)) revert MorphoBlueFacet_InvalidOnBehalfAddress();
        if (receiver == address(0)) revert MorphoBlueFacet_InvalidReceiverAddress();
        if (marketParams.loanToken == address(0) || marketParams.collateralToken == address(0)) {
            revert MorphoBlueFacet_InvalidMarketParams();
        }
        return _morpho().withdraw(marketParams, assets, shares, onBehalf, receiver);
    }

    /// @notice Internal helper to borrow from a Morpho Blue market
    function _morphoBlueBorrowInternal(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) internal returns (uint256, uint256) {
        if (onBehalf == address(0)) revert MorphoBlueFacet_InvalidOnBehalfAddress();
        if (receiver == address(0)) revert MorphoBlueFacet_InvalidReceiverAddress();
        if (marketParams.loanToken == address(0) || marketParams.collateralToken == address(0)) {
            revert MorphoBlueFacet_InvalidMarketParams();
        }
        return _morpho().borrow(marketParams, assets, shares, onBehalf, receiver);
    }

    /// @notice Internal helper to repay a Morpho Blue position
    function _morphoBlueRepayInternal(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf
    ) internal returns (uint256, uint256) {
        if (onBehalf == address(0)) revert MorphoBlueFacet_InvalidOnBehalfAddress();
        if (marketParams.loanToken == address(0) || marketParams.collateralToken == address(0)) {
            revert MorphoBlueFacet_InvalidMarketParams();
        }
        return _morpho().repay(marketParams, assets, shares, onBehalf, "");
    }
}


