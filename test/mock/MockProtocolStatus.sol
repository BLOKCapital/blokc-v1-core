// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";

/// @title MockProtocolStatus
/// @notice Lightweight mock for IProtocolStatus — exposes getProtocolStatus() and setStatus().
///         Shared across all test bases that need a controllable protocol state.
contract MockProtocolStatus {
    IProtocolStatus.State private _status;

    constructor() {
        _status = IProtocolStatus.State.ACTIVE;
    }

    function getProtocolStatus() external view returns (IProtocolStatus.State) {
        return _status;
    }

    function setStatus(IProtocolStatus.State newStatus) external {
        _status = newStatus;
    }
}
