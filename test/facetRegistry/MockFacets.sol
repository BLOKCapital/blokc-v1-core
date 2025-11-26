// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.20;

/// @title Mock Facet for testing
contract MockFacet {
    function mockFunction1() external pure returns (uint256) {
        return 1;
    }

    function mockFunction2() external pure returns (uint256) {
        return 2;
    }

    function mockFunction3() external pure returns (uint256) {
        return 3;
    }

    function anotherMockFunction() external pure returns (string memory) {
        return "test";
    }
}

/// @title Mock Facet V2 for testing replacements
contract MockFacetV2 {
    function mockFunction1() external pure returns (uint256) {
        return 100; // Different implementation
    }

    function mockFunction2() external pure returns (uint256) {
        return 200;
    }

    function newFunction() external pure returns (bool) {
        return true;
    }
}
