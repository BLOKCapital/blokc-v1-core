// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/*###############################################################################

    @title WithdrawFacet
    @author BLOK Capital DAO
    @notice Facet providing USDC withdrawal functionality.
    @dev Inherits from WithdrawBase for core logic and IWithdraw for interface compliance.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import { IWithdraw } from "src/interfaces/IWithdraw.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

error WithdrawFacet_WithdrawZeroAmount();
error WithdrawFacet_InvalidOwner();
error WithdrawFacet_InsufficientUSDCBalance(uint256 requested, uint256 available);

contract WithdrawFacet is IWithdraw {
    using SafeERC20 for IERC20;

    address internal constant USDC_ADDRESS = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    event WithdrawFacetUSDCWithdrawn(address to, uint256 amount);

    /**
     * @notice Withdraw ETH from the contract to a specified address.
     * @param amount The amount of ETH to withdraw (in wei).
     */
    function withdrawUSDC(uint256 amount) external override {
        if (amount == 0) revert WithdrawFacet_WithdrawZeroAmount();
        address to = IERC173(address(this)).owner();
        if (to == address(0)) revert WithdrawFacet_InvalidOwner();
        IERC20 usdc = IERC20(USDC_ADDRESS);
        uint256 contractBalance = usdc.balanceOf(address(this));
        if (amount > contractBalance) revert WithdrawFacet_InsufficientUSDCBalance(amount, contractBalance);

        usdc.safeTransfer(to, amount);
        emit WithdrawFacetUSDCWithdrawn(to, amount);
    }
}
