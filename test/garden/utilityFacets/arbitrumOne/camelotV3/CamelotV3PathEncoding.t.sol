// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Test } from "forge-std/Test.sol";

import { ICamelotRouterV3 } from "src/interfaces/ICamelotRouterV3.sol";
import { CamelotV3Base } from "src/garden/facets/utilityFacets/arbitrumOne/camelotV3/CamelotV3Base.sol";

/// @dev Exposes CamelotV3Base's internal path encoders for deterministic unit testing.
contract CamelotV3PathHarness is CamelotV3Base {
    function encodePath(address[] memory path) external pure returns (bytes memory) {
        return _encodePath(path);
    }

    function encodePathReversed(address[] memory path) external pure returns (bytes memory) {
        return _encodePathReversed(path);
    }
}

/// @title CamelotV3PathEncodingTest
/// @notice Deterministic tests for I03: Camelot V3 exact-output ABI (fee field) and reverse
///         multi-hop path ordering. No fork required.
contract CamelotV3PathEncodingTest is Test {
    address internal constant TOKEN_A = address(0xA11CE);
    address internal constant TOKEN_B = address(0xB0B);
    address internal constant TOKEN_C = address(0xCAFE);

    CamelotV3PathHarness internal harness;

    function setUp() public {
        harness = new CamelotV3PathHarness();
    }

    /// @notice Camelot V3 (Algebra) exactOutputSingle takes the 8-field struct with `fee`.
    function testExactOutputSingleSelectorMatchesAlgebraRouter() public pure {
        assertEq(ICamelotRouterV3.exactOutputSingle.selector, bytes4(0xdb3e2198));
    }

    /// @notice `fee` sits between `tokenOut` and `recipient` in the exact-output ABI.
    function testExactOutputSingleStructFieldOrderIncludesFee() public pure {
        ICamelotRouterV3.ExactOutputSingleParams memory params = ICamelotRouterV3.ExactOutputSingleParams({
            tokenIn: TOKEN_A,
            tokenOut: TOKEN_B,
            fee: 3000,
            recipient: address(0xBEEF),
            deadline: 1_700_000_000,
            amountOut: 2e18,
            amountInMaximum: 3e18,
            limitSqrtPrice: 0
        });

        bytes memory encoded = abi.encode(params);
        bytes memory expected = abi.encode(
            params.tokenIn,
            params.tokenOut,
            params.fee,
            params.recipient,
            params.deadline,
            params.amountOut,
            params.amountInMaximum,
            params.limitSqrtPrice
        );
        assertEq(encoded, expected);

        // Static tuple layout: the third word (offset 64 in the data area) is `fee`.
        uint256 feeWord;
        assembly {
            feeWord := mload(add(encoded, 96))
        }
        assertEq(feeWord, 3000);
    }

    function testExactInputPathEncodesForward() public view {
        address[] memory path = _threeTokenPath();
        assertEq(harness.encodePath(path), abi.encodePacked(TOKEN_A, TOKEN_B, TOKEN_C));
    }

    function testExactOutputPathEncodesReversed() public view {
        address[] memory path = _threeTokenPath();
        assertEq(harness.encodePathReversed(path), abi.encodePacked(TOKEN_C, TOKEN_B, TOKEN_A));
    }

    function _threeTokenPath() internal pure returns (address[] memory path) {
        path = new address[](3);
        path[0] = TOKEN_A;
        path[1] = TOKEN_B;
        path[2] = TOKEN_C;
    }
}
