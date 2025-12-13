// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    @title AaveV3Facet
    @author BLOK Capital DAO
    @notice Facet exposing Aave V3 integration functions (lend / withdraw / reserve data lookup)
    @dev This facet provides integration with Aave V3 protocol for lending and withdrawing assets

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

// OpenZeppelin Contracts
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Aave Contracts
import { DataTypes } from "@aave/aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";

// Local Contracts
import { AaveV3Base } from "src/garden/facets/utilityFacets/arbitrumOne/aaveV3/AaveV3Base.sol";
import { Facet } from "src/garden/facets/Facet.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when token address is zero
error AaveV3Facet_InvalidToken();

/// @notice Thrown when amount is zero
error AaveV3Facet_InvalidAmount();

/// @notice Thrown when contract has insufficient token balance
error AaveV3Facet_InsufficientBalance();

/// @notice Thrown when token approval fails
error AaveV3Facet_ApprovalFailed();

/// @notice Thrown when pool address is zero or invalid
error AaveV3Facet_InvalidPoolAddress();

/// @notice Thrown when aToken address is zero (reserve not configured)
error AaveV3Facet_InvalidATokenAddress();

/// @notice Thrown when withdrawal amount exceeds aToken balance
error AaveV3Facet_InsufficientATokenBalance();

// ============================================================================
// AaveV3Facet
// ============================================================================

contract AaveV3Facet is AaveV3Base, Facet {
    using SafeERC20 for IERC20;

    // ========================================================================
    // External Functions (View)
    // ========================================================================

    /// @notice Gets reserve data from an Aave pool for a specific token
    /// @param tokenIn The underlying asset token address whose reserve data is requested
    /// @return reserveData The Aave ReserveData struct for the token
    function getReserveData(address tokenIn) external view returns (DataTypes.ReserveData memory reserveData) {
        return _getReserveData(tokenIn);
    }

    // ========================================================================
    // External Functions (State-Changing)
    // ========================================================================

    /// @notice Lends tokens to an Aave pool
    /// @param tokenIn The ERC20 token address to supply
    /// @param amountIn Amount of token to supply
    function lend(address tokenIn, uint256 amountIn) external onlyGardenOwner ifIndexNotConnected {
        _lend(tokenIn, amountIn);
    }

    /// @notice Withdraws tokens from an Aave pool
    /// @param tokenIn The underlying asset address (asset corresponding to the aToken)
    /// @param amountToWithdraw Amount of underlying to withdraw (in token decimals)
    function withdraw(address tokenIn, uint256 amountToWithdraw) external onlyGardenOwner ifIndexNotConnected {
        _withdraw(tokenIn, amountToWithdraw);
    }
}
