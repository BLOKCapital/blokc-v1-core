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

interface IAaveV3 {
    /// @notice Returns reserve data from a given pool for a token
    /// @param tokenIn The underlying asset token address whose reserve data is requested
    /// @return reserveData The Aave ReserveData struct for the token
    function getReserveData(address tokenIn) external view returns (DataTypes.ReserveData memory reserveData);

    /// @notice Supplies tokens into Aave using the provided parameters
    /// @param tokenIn The ERC20 token address to supply
    /// @param amountIn Amount of token to supply
    function lend(address tokenIn, uint256 amountIn) external;

    /// @notice Withdraws underlying tokens from Aave back to the diamond contract
    /// @param tokenIn The underlying asset address (asset corresponding to the aToken)
    /// @param amountToWithdraw Amount of underlying to withdraw (in token decimals)
    function withdraw(address tokenIn, uint256 amountToWithdraw) external;
}
