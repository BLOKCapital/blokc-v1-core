// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

interface IPermit2AllowanceTransfer {
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;
}
