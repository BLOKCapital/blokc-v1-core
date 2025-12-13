// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IENSResolver {
    function addr(bytes32 node) external view returns (address);
}

/// @notice Minimal ENS Registry compatible with ProtocolStatus
contract ENSRegistry is Ownable {
    mapping(bytes32 => address) private _resolvers;

    event ResolverSet(bytes32 indexed node, address indexed resolver);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function setResolver(bytes32 node, address newResolver) external onlyOwner {
        _resolvers[node] = newResolver;
        emit ResolverSet(node, newResolver);
    }

    function resolver(bytes32 node) external view returns (address) {
        return _resolvers[node];
    }
}
