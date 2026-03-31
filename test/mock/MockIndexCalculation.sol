// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { IIndexCalculation } from "src/interfaces/IIndexCalculation.sol";

/// @title MockIndexCalculation
/// @notice Returns pre-set weights for testing index weight calculations.
///         Call setWeights() before use; getWeights() returns them verbatim.
contract MockIndexCalculation is IIndexCalculation {
    uint256[] private _weights;
    bool private _shouldRevert;
    string private _revertReason;

    /// @notice Set the weights to return from getWeights()
    function setWeights(uint256[] memory weights_) external {
        _weights = weights_;
    }

    /// @notice Configure getWeights() to revert (for negative testing)
    function setShouldRevert(bool shouldRevert_, string memory reason) external {
        _shouldRevert = shouldRevert_;
        _revertReason = reason;
    }

    function getWeights(string[] memory /* symbols */ ) external view override returns (uint256[] memory) {
        if (_shouldRevert) revert(_revertReason);
        return _weights;
    }
}
