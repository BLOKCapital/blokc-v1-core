// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/*###############################################################################

    @title Aave Facet
    @author BLOK Capital DAO
    @notice Facet exposing Aave integration functions (lend / withdraw / reserve data lookup).
    @dev This facet wires the IAave interface to internal AaveBase implementations and
         registers the interface id during initialization.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import { IAave } from "src/interfaces/IAave.sol";
import { IPool } from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { DataTypes } from "@aave/aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

error AaveFacet_InvalidToken();
error AaveFacet_InvalidAmount();
error AaveFacet_InsufficientBalance();
error AaveFacet_ApprovalFailed();

contract AaveFacet is IAave {
    event AaveFacetTokensLent(address token, uint256 amount, address from);
    event AaveFacetTokensWithdrawn(address token, uint256 aTokenBalanceBefore, address to);

    /// @inheritdoc IAave
    function aaveReserveData(AaveReserveDataParams calldata params)
        external
        view
        override
        returns (DataTypes.ReserveData memory reserveData)
    {
        reserveData = IPool(params.poolAddress).getReserveData(params.tokenIn);
    }

    /// @inheritdoc IAave
    function lendToAave(AaveLendParams calldata params) external override {
        // create typed pool reference
        IPool pool = IPool(params.poolAddress);

        // input validation
        if (params.tokenIn == address(0)) revert AaveFacet_InvalidToken();
        if (params.amountIn == 0) revert AaveFacet_InvalidAmount();

        // ERC20 token instance for bookkeeping and approvals
        IERC20 token = IERC20(params.tokenIn);

        // ensure the contract has the tokens to supply
        if (token.balanceOf(address(this)) < params.amountIn) revert AaveFacet_InsufficientBalance();

        // Standard safe-approval pattern for non-standard ERC20 tokens:
        // - If current allowance > 0, first reset to 0 then set desired allowance.
        // This reduces risk with some tokens that require allowance to be set to 0 first.
        uint256 currentAllowance = token.allowance(address(this), address(pool));
        if (currentAllowance > 0) {
            // if token returns false on approve, revert
            if (!token.approve(address(pool), 0)) revert AaveFacet_ApprovalFailed();
        }

        // set exact approval needed for supply. Revert if approve returns false.
        if (!token.approve(address(pool), params.amountIn)) revert AaveFacet_ApprovalFailed();

        // perform supply to Aave pool (sender is this contract, beneficiary is this contract)
        pool.supply(params.tokenIn, params.amountIn, address(this), 0);

        // emit event for off-chain indexers and logs
        emit AaveFacetTokensLent(params.tokenIn, params.amountIn, address(this));
    }

    /// @inheritdoc IAave
    function withdrawFromAave(AaveWithdrawParams calldata params) external override {
        IPool pool = IPool(params.poolAddress);

        // read reserve data to discover the aToken address for the underlying token
        DataTypes.ReserveData memory reserve = pool.getReserveData(params.tokenIn);
        IERC20 aToken = IERC20(reserve.aTokenAddress);

        // ensure sufficient aToken balance for requested withdrawal
        uint256 aTokenBalance = aToken.balanceOf(address(this));
        if (aTokenBalance < params.amountToWithdraw) revert AaveFacet_InsufficientBalance();

        // withdraw underlying tokens to this contract
        pool.withdraw({ asset: params.tokenIn, amount: params.amountToWithdraw, to: address(this) });

        // emit event containing the aToken balance prior to withdrawal (useful info)
        emit AaveFacetTokensWithdrawn(params.tokenIn, aTokenBalance, address(this));
    }
}
