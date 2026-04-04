// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/// @title MockGardenFactory
/// @notice Minimal mock for IGardenFactory used by Index.connectGardenToIndex().
///         Allows tests to register gardens with specific types.
contract MockGardenFactory {
    mapping(address => bytes32) private _gardenTypes;
    mapping(address => bool) private _registered;

    function setGardenType(address garden, bytes32 gardenType) external {
        _gardenTypes[garden] = gardenType;
        _registered[garden] = true;
    }

    function getGardenType(address garden) external view returns (bytes32) {
        return _gardenTypes[garden];
    }

    function isGardenRegistered(address garden) external view returns (bool) {
        return _registered[garden];
    }

    function getGardenOwner(
        address /* garden */
    )
        external
        pure
        returns (address)
    {
        return address(0);
    }
}
