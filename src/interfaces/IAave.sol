// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/*###############################################################################


    @title Aave Interface
    @author BLOK Capital DAO
    @notice Minimal interface used by the Aave facet to interact with Aave V3 pools and
            to structure input/output parameters in a typed manner.


    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import { DataTypes } from "@aave/aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";

interface IAave {
    /**
     * @notice Parameters required to fetch reserve data from an Aave pool.
     * @param poolAddress The address of the Aave pool (IPool).
     * @param tokenIn The underlying asset token address whose reserve data is requested.
     */
    struct AaveReserveDataParams {
        address poolAddress;
        address tokenIn;
    }

    /**
     * @notice Parameters required to withdraw an aToken from Aave.
     * @param poolAddress The address of the Aave pool (IPool).
     * @param tokenIn The underlying asset address (asset corresponding to the aToken).
     * @param amountToWithdraw Amount of underlying to withdraw (in token decimals).
     */
    struct AaveWithdrawParams {
        address poolAddress;
        address tokenIn;
        uint256 amountToWithdraw;
    }

    /**
     * @notice Parameters required to supply (lend) tokens into Aave.
     * @param poolAddress The address of the Aave pool (IPool).
     * @param tokenIn The ERC20 token address to supply.
     * @param amountIn Amount of token to supply.
     */
    struct AaveLendParams {
        address poolAddress;
        address tokenIn;
        uint256 amountIn;
    }

    /**
     * @notice Return reserve data from a given pool for a token.
     * @dev Returns the Aave core `ReserveData` struct (see Aave v3 DataTypes).
     * @param params AaveReserveData containing poolAddress and tokenIn.
     * @return DataTypes.ReserveData Reserve metadata (aToken address, strategy, etc).
     */
    function aaveReserveData(AaveReserveDataParams calldata params)
        external
        view
        returns (DataTypes.ReserveData memory);

    /**
     * @notice Supply tokens into Aave using the provided parameters.
     * @dev Caller must ensure tokens are present and approvals are handled by the facet.
     * @param params GardenLendParams containing poolAddress, tokenIn and amountIn.
     */
    function lendToAave(AaveLendParams calldata params) external;

    /**
     * @notice Withdraw underlying tokens from Aave back to this contract.
     * @param params WithdrawAToken containing poolAddress, tokenIn and amountToWithdraw.
     */
    function withdrawFromAave(AaveWithdrawParams calldata params) external;
}
