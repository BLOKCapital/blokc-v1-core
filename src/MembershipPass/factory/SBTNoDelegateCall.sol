// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/// @title Prevents delegatecall to a contract
/// @notice Protects critical functions from being called through proxy/delegatecall
abstract contract SBTNoDelegateCall {
    address private immutable ORIGINAL;

    constructor() {
        ORIGINAL = address(this);
    }

    function _checkNoDelegateCall() private view {
        require(address(this) == ORIGINAL, "Delegatecall not allowed");
    }

    modifier noDelegateCall() {
        _checkNoDelegateCall();
        _;
    }
}
