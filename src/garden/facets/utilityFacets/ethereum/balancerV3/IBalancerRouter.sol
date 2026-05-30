// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Minimal Balancer V3 Router interface used by the Garden swap facet.
interface IBalancerRouter {
    function swapSingleTokenExactIn(
        address pool,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 exactAmountIn,
        uint256 minAmountOut,
        uint256 deadline,
        bool wethIsEth,
        bytes calldata userData
    )
        external
        payable
        returns (uint256 amountOut);

    function swapSingleTokenExactOut(
        address pool,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 exactAmountOut,
        uint256 maxAmountIn,
        uint256 deadline,
        bool wethIsEth,
        bytes calldata userData
    )
        external
        payable
        returns (uint256 amountIn);
}
