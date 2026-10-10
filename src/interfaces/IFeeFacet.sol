// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/// @notice Garden-level fee module: fee-module configuration, deposit recording into an active
///         fee session, and fee-session views. Tool-agnostic — the FEES module serves every
///         wealth-management module a garden hosts; the active tool supplies its own valuation.
interface IFeeFacet {
    /// @notice Wires the fee registries into this garden
    /// @param feeRegistry The DAO-controlled fee schedule registry
    /// @param treasuryRegistry The DAO-voted Treasury address registry
    /// @param onboarderRegistry The onboarder eligibility registry
    function configureFeeModule(address feeRegistry, address treasuryRegistry, address onboarderRegistry) external;

    /// @notice Records a USDC deposit into the active fee session (increases the basis; no fee
    ///         at deposit). Pulls from the caller — approve first.
    /// @param amount The USDC amount to deposit
    function depositUsdc(uint256 amount) external;

    /// @notice Records a component-token deposit into the active fee session (increases the
    ///         basis by the oracle USDC value). Pulls from the caller — approve first.
    /// @param symbol The component symbol the deposit belongs to
    /// @param amount The deposit amount
    function depositComponent(bytes32 symbol, uint256 amount) external;

    /// @notice Returns the full fee-session basis
    /// @return basisRecorded Whether an active session has a recorded basis
    /// @return entryUSDC The USDC-denominated basis
    /// @return depositUSDC Cumulative deposits credited to the basis
    /// @return connectedAtBlock Block number of session start
    /// @return connectedAtTimestamp Timestamp of session start
    /// @return onboarder The bound onboarder (address(0) = none)
    /// @return performanceFeeBps Locked performance fee bps
    /// @return protocolFeeBps Locked protocol fee bps
    /// @return onboarderShareBps Locked onboarder share bps (of the performance fee)
    /// @return applyRateAtMode 0 = ConnectLock (locked at connect), 1 = DisconnectLive
    function getFeeBasis()
        external
        view
        returns (
            bool basisRecorded,
            uint256 entryUSDC,
            uint256 depositUSDC,
            uint64 connectedAtBlock,
            uint64 connectedAtTimestamp,
            address onboarder,
            uint256 performanceFeeBps,
            uint256 protocolFeeBps,
            uint256 onboarderShareBps,
            uint8 applyRateAtMode
        );

    /// @notice Returns the configured fee registries
    function getFeeRegistries()
        external
        view
        returns (address feeRegistry, address treasuryRegistry, address onboarderRegistry);

    /// @notice Returns the last settlement's audit trail (survives sessions)
    /// @return lastExitUSDC The realized USDC balance at the last exit
    /// @return lastRealizedProfitUSDC The realized profit (negative = loss recorded)
    function getLastSettlement() external view returns (uint256 lastExitUSDC, int256 lastRealizedProfitUSDC);
}
