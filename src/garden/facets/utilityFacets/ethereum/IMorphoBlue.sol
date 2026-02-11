// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################
 *
 *    @title IMorphoBlue
 *    @author BLOK Capital DAO
 *    @notice Interface for Morpho Blue protocol integration
 *    @dev Minimal interface used by the Morpho facet to interact with Morpho Blue
 *         and to structure input/output parameters in a typed manner.
 *
 *    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
 *    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
 *    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
 *    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘
 *
 *##############################################################################*/

import { MarketParams } from "@morphoBlue/src/interfaces/IMorpho.sol";

interface IMorphoBlue {
    /// @notice Supply to a Morpho Blue market
    function supply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external returns (uint256, uint256);

    /// @notice Withdraw from a Morpho Blue market
    function withdraw(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);

    /// @notice Borrow from a Morpho Blue market
    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);

    /// @notice Repay a Morpho Blue position
    function repay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf
    ) external returns (uint256, uint256);

    /// @notice Accrue interest on a Morpho Blue market
    function accrueInterest(MarketParams memory marketParams) external;

    /// @notice Create a new Morpho Blue market
    function createMarket(MarketParams memory marketParams) external;
}


