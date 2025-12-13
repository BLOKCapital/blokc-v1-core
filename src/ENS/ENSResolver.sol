// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Minimal ENS Resolver compatible with ProtocolStatus
contract ENSResolver is Ownable {
    mapping(bytes32 => address) private _addrs;

    event AddrChanged(bytes32 indexed node, address indexed a);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function setAddr(bytes32 node, address a) external onlyOwner {
        _addrs[node] = a;
        emit AddrChanged(node, a);
    }

    function addr(bytes32 node) external view returns (address) {
        return _addrs[node];
    }
}
