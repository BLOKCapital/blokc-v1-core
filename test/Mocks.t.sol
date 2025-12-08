// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/* ============================================================
                    ALL MOCKS IN ONE FILE
   ============================================================ */

/// @notice Simple ERC721 mock (optional)
contract MockERC721 {
    string public name;
    string public symbol;
    mapping(uint256 => address) internal _owner;
    mapping(address => uint256) internal _balance;
    uint256 public nextId;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function mint(address to) external returns (uint256) {
        require(to != address(0), "zero address");
        uint256 id = ++nextId;
        _owner[id] = to;
        _balance[to] += 1;
        return id;
    }

    function balanceOf(address owner) external view returns (uint256) {
        return _balance[owner];
    }

    function ownerOf(uint256 id) external view returns (address) {
        return _owner[id];
    }
}

/// @notice Minimal ENS resolver mock
contract MockENSResolver {
    mapping(bytes32 => address) public addrs;

    function setAddr(bytes32 node, address a) external {
        addrs[node] = a;
    }

    function addr(bytes32 node) external view returns (address) {
        return addrs[node];
    }
}

/// @notice Minimal ENS registry mock
contract MockENSRegistry {
    mapping(bytes32 => address) public resolvers;

    function setResolver(bytes32 node, address res) external {
        resolvers[node] = res;
    }

    function resolver(bytes32 node) external view returns (address) {
        return resolvers[node];
    }
}
