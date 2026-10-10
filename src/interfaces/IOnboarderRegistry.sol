// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/// @notice The DAO-voted allowlist of addresses eligible to be bound as onboarders of an
///         Index Garden. Prevents arbitrary addresses being recorded as onboarder.
interface IOnboarderRegistry {
    /// @notice Returns true if `onboarder` may be bound as the onboarder of a garden session.
    function isOnboarderEligible(address onboarder) external view returns (bool);
}
