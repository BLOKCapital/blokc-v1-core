// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/// @notice What the fees are assessed on. V1: realized profit at disconnect.
enum AssessmentBase {
    ProfitAtDisconnect
}

/// @notice When the DAO's fee schedule applies to a garden session.
///         ConnectLock: rates are snapshotted into the garden at connect and used at
///         settlement regardless of later DAO changes (V1 default). DisconnectLive: the live
///         registry rates are read at settlement — applies only to sessions that connected
///         after the flip.
enum ApplyRateAt {
    ConnectLock,
    DisconnectLive
}

/// @notice The DAO-controlled fee schedule for Index Garden fee settlement.
interface IFeeRegistry {
    /// @notice Returns the active fee schedule.
    /// @return performanceFeeBps Performance fee in bps of realized profit (initial 1_000)
    /// @return protocolFeeBps Protocol fee in bps of realized profit (initial 200)
    /// @return onboarderShareBps Onboarder share OF the performance fee in bps (initial 5_000)
    /// @return assessmentBase The assessment base enum (uint8)
    /// @return applyRateAt The rate-application mode enum (uint8)
    function getFeeSchedule()
        external
        view
        returns (
            uint256 performanceFeeBps,
            uint256 protocolFeeBps,
            uint256 onboarderShareBps,
            uint8 assessmentBase,
            uint8 applyRateAt
        );

    /// @notice Returns the safety caps a DAO vote cannot exceed without changing the caps first.
    function getSafetyCaps()
        external
        view
        returns (uint256 maxPerformanceFeeBps, uint256 maxProtocolFeeBps, uint256 maxOnboarderShareBps);

    function getPerformanceFeeBps() external view returns (uint256);
    function getProtocolFeeBps() external view returns (uint256);
    function getOnboarderShareBps() external view returns (uint256);
    function getAssessmentBase() external view returns (uint8);
    function getApplyRateAt() external view returns (uint8);
}
