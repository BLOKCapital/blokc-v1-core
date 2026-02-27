// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title IndexMath
/// @author BLOK Capital DAO
/// @notice Library for safe mathematical operations used in index calculations
library IndexMath {
    /// @notice Thrown when division by zero is attempted
    error IndexMath_DivisionByZero();

    /// @notice Thrown when an arithmetic overflow occurs
    error IndexMath_Overflow();

    /// @notice Thrown when a weight exceeds 100% or is otherwise invalid
    error IndexMath_InvalidWeight();

    /// @notice Precision constant (1e18 = 100%)
    uint256 internal constant PRECISION = 1e18;

    /// @notice Maximum weight value (100% in 18 decimals)
    uint256 internal constant MAX_WEIGHT = 1e18;

    /// @notice Minimum weight value (0.01% in 18 decimals)
    uint256 internal constant MIN_WEIGHT = 1e14;

    /// @notice Safely calculate weight as a percentage of total with proper rounding
    /// @param part Individual market cap or value
    /// @param total Total market cap or value
    /// @return weight Weight normalized to 1e18 (100%)
    function calculateWeight(uint256 part, uint256 total) internal pure returns (uint256 weight) {
        if (total == 0) revert IndexMath_DivisionByZero();
        if (part > total) revert IndexMath_Overflow();

        // Use Floor rounding for conservative weight calculation
        weight = Math.mulDiv(part, PRECISION, total, Math.Rounding.Floor);

        // Ensure weight doesn't exceed 100%
        if (weight > MAX_WEIGHT) revert IndexMath_InvalidWeight();

        return weight;
    }
}
