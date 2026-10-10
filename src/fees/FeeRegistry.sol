// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▛▀▜▌▐▛▚▖     ▐▌   ▐▌ ▐▌▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IFeeRegistry, AssessmentBase, ApplyRateAt } from "../interfaces/IFeeRegistry.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when a performance fee exceeds the safety cap
/// @param requested The requested bps
/// @param cap The current maximum allowed
error FeeRegistry_ExceedsMaxPerformanceFeeBps(uint256 requested, uint256 cap);

/// @notice Thrown when a protocol fee exceeds the safety cap
/// @param requested The requested bps
/// @param cap The current maximum allowed
error FeeRegistry_ExceedsMaxProtocolFeeBps(uint256 requested, uint256 cap);

/// @notice Thrown when an onboarder share exceeds the safety cap
/// @param requested The requested bps
/// @param cap The current maximum allowed
error FeeRegistry_ExceedsMaxOnboarderShareBps(uint256 requested, uint256 cap);

/// @notice Thrown when performance + protocol fees exceed 100% of profit (breaks the investor
///         invariant: investorUSDC >= entryUSDC when profit > 0)
/// @param performanceFeeBps The performance fee bps
/// @param protocolFeeBps The protocol fee bps
error FeeRegistry_FeeSumExceedsProfit(uint256 performanceFeeBps, uint256 protocolFeeBps);

/// @notice Thrown when an out-of-range enum value is passed
/// @param value The invalid value
error FeeRegistry_InvalidAssessmentBase(uint8 value);

/// @notice Thrown when an out-of-range enum value is passed
/// @param value The invalid value
error FeeRegistry_InvalidApplyRateAt(uint8 value);

/// @notice Thrown when a safety cap is lowered below the currently active rate
/// @param capName Which cap ("performance" | "protocol" | "onboarder")
/// @param cap The proposed cap
/// @param currentValue The active rate that would exceed the proposed cap
error FeeRegistry_CapBelowCurrentValue(string capName, uint256 cap, uint256 currentValue);

/// @notice Thrown when a safety cap value itself is invalid
/// @param cap The invalid cap value
error FeeRegistry_InvalidCap(uint256 cap);

/// @notice Thrown when renounceOwnership is called (disabled to prevent permanent lockout)
error FeeRegistry_CannotRenounceOwnership();

/**
 * @title FeeRegistry
 * @notice DAO-controlled fee schedule for Index Garden fee settlement: performance fee bps,
 *         protocol fee bps, onboarder share of the performance fee, the assessment base, the
 *         rate-application mode, and the safety caps a vote cannot exceed. Gardens snapshot this
 *         schedule at connect (applyRateAt = ConnectLock, the default) or read it live at
 *         settlement (DisconnectLive). Raises above a cap revert until the cap itself is changed
 *         in a separate vote.
 */
contract FeeRegistry is IFeeRegistry, Ownable {
    uint256 private _performanceFeeBps;
    uint256 private _protocolFeeBps;
    uint256 private _onboarderShareBps;
    AssessmentBase private _assessmentBase;
    ApplyRateAt private _applyRateAt;
    uint256 private _maxPerformanceFeeBps;
    uint256 private _maxProtocolFeeBps;
    uint256 private _maxOnboarderShareBps;

    event PerformanceFeeBpsUpdated(uint256 oldBps, uint256 newBps);
    event ProtocolFeeBpsUpdated(uint256 oldBps, uint256 newBps);
    event OnboarderShareBpsUpdated(uint256 oldBps, uint256 newBps);
    event AssessmentBaseUpdated(uint8 oldBase, uint8 newBase);
    event ApplyRateAtUpdated(uint8 oldMode, uint8 newMode);
    event SafetyCapsUpdated(uint256 maxPerformanceFeeBps, uint256 maxProtocolFeeBps, uint256 maxOnboarderShareBps);

    /// @notice Constructs the FeeRegistry with the spec's initial parameters
    /// @param initialOwner Address of the contract owner (the DAO control key)
    constructor(address initialOwner) Ownable(initialOwner) {
        _performanceFeeBps = 1000;
        _protocolFeeBps = 200;
        _onboarderShareBps = 5000;
        _assessmentBase = AssessmentBase.ProfitAtDisconnect;
        _applyRateAt = ApplyRateAt.ConnectLock;
        _maxPerformanceFeeBps = 3000;
        _maxProtocolFeeBps = 1000;
        _maxOnboarderShareBps = 10_000;
    }

    /// @notice Sets the performance fee in bps of realized profit
    function setPerformanceFeeBps(uint256 newPerformanceFeeBps) external onlyOwner {
        if (newPerformanceFeeBps > _maxPerformanceFeeBps) {
            revert FeeRegistry_ExceedsMaxPerformanceFeeBps(newPerformanceFeeBps, _maxPerformanceFeeBps);
        }
        if (newPerformanceFeeBps + _protocolFeeBps > 10_000) {
            revert FeeRegistry_FeeSumExceedsProfit(newPerformanceFeeBps, _protocolFeeBps);
        }
        uint256 old = _performanceFeeBps;
        _performanceFeeBps = newPerformanceFeeBps;
        emit PerformanceFeeBpsUpdated(old, newPerformanceFeeBps);
    }

    /// @notice Sets the protocol fee in bps of realized profit
    function setProtocolFeeBps(uint256 newProtocolFeeBps) external onlyOwner {
        if (newProtocolFeeBps > _maxProtocolFeeBps) {
            revert FeeRegistry_ExceedsMaxProtocolFeeBps(newProtocolFeeBps, _maxProtocolFeeBps);
        }
        if (_performanceFeeBps + newProtocolFeeBps > 10_000) {
            revert FeeRegistry_FeeSumExceedsProfit(_performanceFeeBps, newProtocolFeeBps);
        }
        uint256 old = _protocolFeeBps;
        _protocolFeeBps = newProtocolFeeBps;
        emit ProtocolFeeBpsUpdated(old, newProtocolFeeBps);
    }

    /// @notice Sets the onboarder share in bps OF the performance fee
    function setOnboarderShareBps(uint256 newOnboarderShareBps) external onlyOwner {
        if (newOnboarderShareBps > _maxOnboarderShareBps) {
            revert FeeRegistry_ExceedsMaxOnboarderShareBps(newOnboarderShareBps, _maxOnboarderShareBps);
        }
        uint256 old = _onboarderShareBps;
        _onboarderShareBps = newOnboarderShareBps;
        emit OnboarderShareBpsUpdated(old, newOnboarderShareBps);
    }

    /// @notice Sets the assessment base (V1: only ProfitAtDisconnect exists)
    function setAssessmentBase(uint8 newAssessmentBase) external onlyOwner {
        if (newAssessmentBase > uint8(type(AssessmentBase).max)) {
            revert FeeRegistry_InvalidAssessmentBase(newAssessmentBase);
        }
        uint8 old = uint8(_assessmentBase);
        _assessmentBase = AssessmentBase(newAssessmentBase);
        emit AssessmentBaseUpdated(old, newAssessmentBase);
    }

    /// @notice Sets the rate-application mode (ConnectLock default; DisconnectLive affects only
    ///         sessions that connect after the flip)
    function setApplyRateAt(uint8 newApplyRateAt) external onlyOwner {
        if (newApplyRateAt > uint8(type(ApplyRateAt).max)) {
            revert FeeRegistry_InvalidApplyRateAt(newApplyRateAt);
        }
        uint8 old = uint8(_applyRateAt);
        _applyRateAt = ApplyRateAt(newApplyRateAt);
        emit ApplyRateAtUpdated(old, newApplyRateAt);
    }

    /// @notice Sets the safety caps. Each cap must stay >= the currently active rate it bounds
    ///         (lower it only after lowering the rate itself), the onboarder cap is hard-bounded
    ///         at 10_000 bps, and the perf+proto caps must keep their sum within 10_000 bps.
    function setSafetyCaps(
        uint256 newMaxPerformanceFeeBps,
        uint256 newMaxProtocolFeeBps,
        uint256 newMaxOnboarderShareBps
    )
        external
        onlyOwner
    {
        if (newMaxPerformanceFeeBps + newMaxProtocolFeeBps > 10_000) {
            revert FeeRegistry_FeeSumExceedsProfit(newMaxPerformanceFeeBps, newMaxProtocolFeeBps);
        }
        if (newMaxOnboarderShareBps > 10_000) revert FeeRegistry_InvalidCap(newMaxOnboarderShareBps);
        if (newMaxPerformanceFeeBps < _performanceFeeBps) {
            revert FeeRegistry_CapBelowCurrentValue("performance", newMaxPerformanceFeeBps, _performanceFeeBps);
        }
        if (newMaxProtocolFeeBps < _protocolFeeBps) {
            revert FeeRegistry_CapBelowCurrentValue("protocol", newMaxProtocolFeeBps, _protocolFeeBps);
        }
        if (newMaxOnboarderShareBps < _onboarderShareBps) {
            revert FeeRegistry_CapBelowCurrentValue("onboarder", newMaxOnboarderShareBps, _onboarderShareBps);
        }
        _maxPerformanceFeeBps = newMaxPerformanceFeeBps;
        _maxProtocolFeeBps = newMaxProtocolFeeBps;
        _maxOnboarderShareBps = newMaxOnboarderShareBps;
        emit SafetyCapsUpdated(newMaxPerformanceFeeBps, newMaxProtocolFeeBps, newMaxOnboarderShareBps);
    }

    /// @notice Returns the active fee schedule
    function getFeeSchedule()
        external
        view
        returns (
            uint256 performanceFeeBps,
            uint256 protocolFeeBps,
            uint256 onboarderShareBps,
            uint8 assessmentBase,
            uint8 applyRateAt
        )
    {
        return (_performanceFeeBps, _protocolFeeBps, _onboarderShareBps, uint8(_assessmentBase), uint8(_applyRateAt));
    }

    /// @notice Returns the safety caps
    function getSafetyCaps()
        external
        view
        returns (uint256 maxPerformanceFeeBps, uint256 maxProtocolFeeBps, uint256 maxOnboarderShareBps)
    {
        return (_maxPerformanceFeeBps, _maxProtocolFeeBps, _maxOnboarderShareBps);
    }

    function getPerformanceFeeBps() external view returns (uint256) {
        return _performanceFeeBps;
    }

    function getProtocolFeeBps() external view returns (uint256) {
        return _protocolFeeBps;
    }

    function getOnboarderShareBps() external view returns (uint256) {
        return _onboarderShareBps;
    }

    function getAssessmentBase() external view returns (uint8) {
        return uint8(_assessmentBase);
    }

    function getApplyRateAt() external view returns (uint8) {
        return uint8(_applyRateAt);
    }

    /// @notice Renounce ownership is disabled to prevent permanent lockout
    /// @inheritdoc Ownable
    function renounceOwnership() public pure override {
        revert FeeRegistry_CannotRenounceOwnership();
    }
}
