// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

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

// local Interfaces
import { IAaveV3 } from "src/garden/facets/utilityFacets/arbitrumOne/aaveV3/IAaveV3.sol";

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

/**
 * @title AaveV3Facet
 * @author BLOK Capital DAO
 * @notice Facet that implements the IAaveV3 interface to allow lending and withdrawing tokens from Aave V3 on Arbitrum
 * One. This facet provides external functions for garden owners to lend tokens to Aave and withdraw tokens from Aave,
 * with appropriate access control and user-facing error messages. It inherits from AaveV3Base which contains the
 * internal logic for interacting with Aave, while AaveV3Facet itself provides the external interface for these
 * operations.
 */
contract AaveV3Facet is IAaveV3, AaveV3Base, Facet {
    using SafeERC20 for IERC20;

    // ========================================================================
    // External Functions (View)
    // ========================================================================

    /// @inheritdoc IAaveV3
    function aaveV3GetReserveData(address tokenIn) external view returns (DataTypes.ReserveData memory reserveData) {
        return _aaveV3GetReserveData(tokenIn);
    }

    // ========================================================================
    // External Functions (State-Changing)
    // ========================================================================

    /// @inheritdoc IAaveV3
    function aaveV3Lend(address tokenIn, uint256 amountIn) external onlyGardenOwner nonReentrant ifIndexNotConnected {
        _aaveV3Lend(tokenIn, amountIn);
    }

    /// @inheritdoc IAaveV3
    function aaveV3Withdraw(
        address tokenIn,
        uint256 amountToWithdraw
    )
        external
        onlyGardenOwner
        nonReentrant
        ifIndexNotConnected
    {
        _aaveV3Withdraw(tokenIn, amountToWithdraw);
    }
}
