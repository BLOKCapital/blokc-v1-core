// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title IWithdraw
    @author BLOK Capital DAO
    @notice Interface for withdrawing USDC from the diamond contract
    @dev This interface exposes the USDC withdrawal functionality provided by
         the WithdrawFacet. Withdrawals are restricted to the diamond owner.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

interface IWithdraw {
    /// @notice Withdraws USDC from the contract to the owner address
    /// @dev Withdrawals are restricted to the diamond owner only. The USDC is
    ///      transferred from the diamond contract to the current owner address.
    ///      Uses SafeERC20 for secure token transfers.
    /// @param amount The amount of USDC to withdraw (in USDC decimals, usually 6)
    function withdrawUSDC(uint256 amount) external;
}
