// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Test } from "forge-std/Test.sol";

import { UniswapV3Base } from "src/garden/facets/utilityFacets/ethereum/uniswapV3/UniswapV3Base.sol";
import { IUniswapV3 } from "src/garden/facets/utilityFacets/ethereum/uniswapV3/IUniswapV3.sol";

/// @dev Exposes UniswapV3Base's internal path encoders for deterministic unit testing.
contract EthereumUniswapV3PathHarness is UniswapV3Base {
    function encodePath(IUniswapV3.TokenWithFee[] memory pathWithFees) external pure returns (bytes memory) {
        return _encodePath(pathWithFees);
    }

    function encodePathReversed(IUniswapV3.TokenWithFee[] memory pathWithFees) external pure returns (bytes memory) {
        return _encodePathReversed(pathWithFees);
    }
}

/// @title EthereumUniswapV3PathEncodingTest
/// @notice Deterministic tests for I04: Uniswap V3 exact-output paths must be encoded in
///         reverse order (tokenOut, fee, ..., tokenIn). No fork required.
contract EthereumUniswapV3PathEncodingTest is Test {
    address internal constant TOKEN_A = address(0xA11CE);
    address internal constant TOKEN_B = address(0xB0B);
    address internal constant TOKEN_C = address(0xCAFE);

    uint24 internal constant FEE_AB = 500;
    uint24 internal constant FEE_BC = 3000;

    EthereumUniswapV3PathHarness internal harness;

    function setUp() public {
        harness = new EthereumUniswapV3PathHarness();
    }

    function testExactInputPathEncodesForward() public view {
        assertEq(harness.encodePath(_threeTokenPath()), abi.encodePacked(TOKEN_A, FEE_AB, TOKEN_B, FEE_BC, TOKEN_C));
    }

    function testExactOutputPathEncodesReversedWithPerHopFees() public view {
        assertEq(
            harness.encodePathReversed(_threeTokenPath()), abi.encodePacked(TOKEN_C, FEE_BC, TOKEN_B, FEE_AB, TOKEN_A)
        );
    }

    function _threeTokenPath() internal pure returns (IUniswapV3.TokenWithFee[] memory pathWithFees) {
        pathWithFees = new IUniswapV3.TokenWithFee[](3);
        pathWithFees[0] = IUniswapV3.TokenWithFee({ token: TOKEN_A, fee: FEE_AB });
        pathWithFees[1] = IUniswapV3.TokenWithFee({ token: TOKEN_B, fee: FEE_BC });
        pathWithFees[2] = IUniswapV3.TokenWithFee({ token: TOKEN_C, fee: 0 });
    }
}
