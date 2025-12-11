// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/// @title Prevents delegatecall to a contract
/// @notice Protects critical functions from being called through proxy/delegatecall
abstract contract SBTNoDelegateCall {
    address private immutable original;

    constructor() {
        original = address(this);
    }

    function _checkNoDelegateCall() private view {
        require(address(this) == original, "Delegatecall not allowed");
    }

    modifier noDelegateCall() {
        _checkNoDelegateCall();
        _;
    }
}
