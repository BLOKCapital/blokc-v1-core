// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/// @title SBTNoDelegateCall
/// @author BLOK Capital DAO
/// @notice Prevents delegatecall to a contract by comparing execution address to deployment address
/// @dev Stores the original deployment address as an immutable and checks it in the modifier.
///      Used by SBTMembershipFactory to protect critical state-changing functions.
abstract contract SBTNoDelegateCall {
    /// @notice The original deployment address of this contract
    address private immutable ORIGINAL;

    /// @notice Stores the deployment address for delegatecall detection
    constructor() {
        ORIGINAL = address(this);
    }

    /// @dev Reverts if the current execution context is a delegatecall
    function _checkNoDelegateCall() private view {
        require(address(this) == ORIGINAL, "Delegatecall not allowed");
    }

    /// @notice Prevents the decorated function from being called via delegatecall
    modifier noDelegateCall() {
        _checkNoDelegateCall();
        _;
    }
}
