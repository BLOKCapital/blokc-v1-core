// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/// @title MockENSResolver
/// @notice Minimal ENS resolver mock for ProtocolStatus tests.
///         Maps namehash -> address via setAddr().
contract MockENSResolver {
    mapping(bytes32 => address) private _addrs;

    function setAddr(bytes32 node, address addr) external {
        _addrs[node] = addr;
    }

    function addr(bytes32 node) external view returns (address) {
        return _addrs[node];
    }
}

/// @title MockENSRegistry
/// @notice Minimal ENS registry mock for ProtocolStatus tests.
///         Maps namehash -> resolver via setResolver(). Defaults to a single resolver for all nodes.
contract MockENSRegistry {
    mapping(bytes32 => address) private _resolvers;
    address private _defaultResolver;

    constructor(address defaultResolver) {
        _defaultResolver = defaultResolver;
    }

    function setResolver(bytes32 node, address resolverAddr) external {
        _resolvers[node] = resolverAddr;
    }

    function resolver(bytes32 node) external view returns (address) {
        address r = _resolvers[node];
        return r != address(0) ? r : _defaultResolver;
    }
}
