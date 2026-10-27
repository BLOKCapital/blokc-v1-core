// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Test } from "forge-std/Test.sol";

import { ICamelotRouterV3 } from "src/interfaces/ICamelotRouterV3.sol";
import { CamelotV3Base } from "src/garden/facets/utilityFacets/arbitrumOne/camelotV3/CamelotV3Base.sol";

/// @dev Minimal Algebra-style pool used to prove the facet reads fee/TWAP through
///      globalState()/getTimepoints() rather than the Uniswap fee()/observe() methods.
contract MockAlgebraPool {
    uint160 internal immutable _price;
    uint16 internal immutable _fee;

    constructor(uint160 price_, uint16 fee_) {
        _price = price_;
        _fee = fee_;
    }

    function globalState() external view returns (uint160, int24, uint16, uint16, uint16, uint16, uint256, bool) {
        return (_price, int24(0), _fee, 0, 0, 0, 0, true);
    }

    function getTimepoints(uint32[] calldata)
        external
        view
        returns (int56[] memory, uint160[] memory, uint112[] memory, uint256[] memory)
    {
        int56[] memory tickCumulatives = new int56[](2);
        uint160[] memory secondsPerLiquidityCumulatives = new uint160[](2);
        uint112[] memory volatilityCumulatives = new uint112[](2);
        uint256[] memory volumePerAvgLiquidityCumulatives = new uint256[](2);
        return
            (tickCumulatives, secondsPerLiquidityCumulatives, volatilityCumulatives, volumePerAvgLiquidityCumulatives);
    }
}

/// @dev Exposes CamelotV3Base's internal path encoders for deterministic unit testing.
contract CamelotV3PathHarness is CamelotV3Base {
    function encodePath(address[] memory path) external pure returns (bytes memory) {
        return _encodePath(path);
    }

    function encodePathReversed(address[] memory path) external pure returns (bytes memory) {
        return _encodePathReversed(path);
    }

    function fee(address pool) external view returns (uint24) {
        return _camelotV3Fee(pool);
    }

    function sqrtTwapX96(address pool, uint32 twapInterval) external view returns (uint160) {
        (uint160 sqrtPriceX96,) = _camelotV3GetSqrtTwapX96(pool, twapInterval);
        return sqrtPriceX96;
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

    /// @notice The dynamic fee comes from Algebra globalState(), not the nonexistent fee().
    function testFeeReadsAlgebraGlobalState() public {
        MockAlgebraPool pool = new MockAlgebraPool(1 << 96, 100);
        assertEq(harness.fee(address(pool)), 100);
    }

    /// @notice Spot and TWAP prices come from globalState()/getTimepoints(), not observe().
    function testSqrtPriceReadsAlgebraPoolState() public {
        MockAlgebraPool pool = new MockAlgebraPool(1 << 96, 100);
        assertEq(harness.sqrtTwapX96(address(pool), 0), 1 << 96);
        assertEq(harness.sqrtTwapX96(address(pool), 30), 1 << 96);
    }

    function _threeTokenPath() internal pure returns (address[] memory path) {
        path = new address[](3);
        path[0] = TOKEN_A;
        path[1] = TOKEN_B;
        path[2] = TOKEN_C;
    }
}
