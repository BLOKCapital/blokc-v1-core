// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################
 *
 *    @title MorphoBlueBase
 *    @author BLOK Capital DAO
 *    @notice Base contract for MorphoFacet exposing Morpho Blue integration functions
 *            (supply / withdraw)
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

import { IMorphoBase, MarketParams } from "@morphoBlue/src/interfaces/IMorpho.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when market parameters are invalid
error MorphoBlueFacet_InvalidMarketParams();

abstract contract MorphoBlueBase {
    using SafeERC20 for IERC20;
    /// @notice Hardcoded Morpho Blue core contract address on Ethereum mainnet
    /// @dev Kept as an immutable compile-time constant (no dedicated storage)
    /// @dev Official Morpho Blue address from: https://docs.morpho.org/get-started/resources/addresses/
    /// @dev For other chains, check: https://docs.morpho.org/get-started/resources/addresses/
    /// @dev NOTE: This is Morpho Blue, the standalone lending primitive, NOT the legacy
    ///      Morpho V1 Optimizer. Blue features isolated permissionless markets.
    address internal constant MORPHO_BLUE_CORE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    /// @notice Internal helper to get the Morpho Blue core interface
    /// @dev Morpho Blue uses isolated markets identified by MarketParams (loanToken, collateralToken,
    ///      oracle, irm, lltv). Each unique combination creates a separate market with isolated risk.
    /// @dev RECOMMENDATION: For production, validation for market IDs against a whitelist stored in the
    ///      storage rather than hardcoding markets is more secure and healthy,allows governance to add/remove
    ///      supported markets and validate oracle/LLTV before listing any market
    function _morpho() internal pure returns (IMorphoBase) {
        return IMorphoBase(MORPHO_BLUE_CORE);
    }

    /// @notice Internal helper to supply liquidity to a Morpho Blue market
    function _morphoBlueSupplyInternal(
        MarketParams memory marketParams,
        uint256 assets
    )
        internal
        returns (uint256, uint256)
    {
        IERC20 loantoken = IERC20(marketParams.loanToken);

        //the collateral check is lame and post deprication shall need dao owned market whitelisting to escape this lame
        // route
        if (marketParams.loanToken == address(0) || marketParams.collateralToken == address(0)) {
            revert MorphoBlueFacet_InvalidMarketParams();
        }

        loantoken.forceApprove(MORPHO_BLUE_CORE, assets);
        //at protocol level we prefer asset penetration only (not shares), therefore 0 shares
        //empty callback data ("") — the garden pre-approves and holds tokens, so no supply callback is used

        return _morpho().supply(marketParams, assets, 0, address(this), "");
    }

    /// @notice Internal helper to withdraw liquidity from a Morpho Blue market
    /// @dev onBehalf and receiver are hardcoded to the garden (address(this)) so the
    ///      garden only ever withdraws its own position back to itself.
    function _morphoBlueWithdrawInternal(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares
    )
        internal
        returns (uint256, uint256)
    {
        if (marketParams.loanToken == address(0) || marketParams.collateralToken == address(0)) {
            revert MorphoBlueFacet_InvalidMarketParams();
        }

        return _morpho().withdraw(marketParams, assets, shares, address(this), address(this));
    }
}

