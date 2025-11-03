// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title IAave
    @author BLOK Capital DAO
    @notice Interface for Aave V3 protocol integration
    @dev Minimal interface used by the Aave facet to interact with Aave V3 pools
         and to structure input/output parameters in a typed manner.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

// Aave Contracts
import { DataTypes } from "@aave/aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";

interface IAave {
    // ========================================================================
    // Structs
    // ========================================================================

    /**
     * @notice Parameters required to fetch reserve data from an Aave pool
     * @param poolAddress The address of the Aave pool (IPool)
     * @param tokenIn The underlying asset token address whose reserve data is requested
     */
    struct AaveReserveDataParams {
        address poolAddress;
        address tokenIn;
    }

    /**
     * @notice Parameters required to withdraw tokens from Aave
     * @param poolAddress The address of the Aave pool (IPool)
     * @param tokenIn The underlying asset address (asset corresponding to the aToken)
     * @param amountToWithdraw Amount of underlying to withdraw (in token decimals)
     */
    struct AaveWithdrawParams {
        address poolAddress;
        address tokenIn;
        uint256 amountToWithdraw;
    }

    /**
     * @notice Parameters required to supply (lend) tokens into Aave
     * @param poolAddress The address of the Aave pool (IPool)
     * @param tokenIn The ERC20 token address to supply
     * @param amountIn Amount of token to supply
     */
    struct AaveLendParams {
        address poolAddress;
        address tokenIn;
        uint256 amountIn;
    }

    // ========================================================================
    // Functions
    // ========================================================================

    /**
     * @notice Returns reserve data from a given pool for a token
     * @dev Returns the Aave core ReserveData struct, including aToken address,
     *      interest rate strategy, and other reserve configuration.
     * @param params AaveReserveDataParams containing poolAddress and tokenIn
     * @return reserveData The Aave ReserveData struct for the token
     */
    function aaveReserveData(AaveReserveDataParams calldata params)
        external
        view
        returns (DataTypes.ReserveData memory reserveData);

    /**
     * @notice Supplies tokens into Aave using the provided parameters
     * @dev Tokens must be present in the diamond contract. Approvals are handled
     *      by the facet using SafeERC20. The diamond receives aTokens as receipt.
     * @param params AaveLendParams containing poolAddress, tokenIn and amountIn
     */
    function lendToAave(AaveLendParams calldata params) external;

    /**
     * @notice Withdraws underlying tokens from Aave back to the diamond contract
     * @dev Burns aTokens and receives underlying tokens. The facet queries the pool
     *      for the aToken address and validates balance before withdrawal.
     * @param params AaveWithdrawParams containing poolAddress, tokenIn and amountToWithdraw
     */
    function withdrawFromAave(AaveWithdrawParams calldata params) external;
}
