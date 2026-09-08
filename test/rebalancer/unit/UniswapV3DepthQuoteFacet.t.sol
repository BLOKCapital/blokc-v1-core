// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Test } from "forge-std/Test.sol";

import {
    UniswapV3DepthQuoteFacet
} from "../../../src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3DepthQuoteFacet.sol";
import {
    UniswapV3DepthQuote_ZeroLiquidity,
    UniswapV3DepthQuote_InsufficientDepth
} from "../../../src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3DepthQuoteFacet.sol";
import {
    UniswapV3Facet_InvalidPath,
    UniswapV3Facet_UnregisteredPool
} from "../../../src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3Base.sol";
import { QuoteInstruction } from "../../../src/interfaces/ISwapInstruction.sol";
import { TickMath } from "../../../src/garden/libraries/TickMath.sol";
import { ArbitrumOneAddresses } from "../../../src/garden/libraries/ArbitrumOneAddresses.sol";

// ═══════════════════════════════════════════════════════════════════════
//                                  Mocks
// ═══════════════════════════════════════════════════════════════════════

/// @dev Minimal ERC20 with a settable balance for one holder (depth checks only need balanceOf)
contract MockDepthToken {
    string public name;
    uint8 public decimals;
    mapping(address => uint256) public balanceOf;

    constructor(string memory _name, uint8 _decimals) {
        name = _name;
        decimals = _decimals;
    }

    function setBalance(address who, uint256 amount) external {
        balanceOf[who] = amount;
    }
}

/// @dev Minimal UniV3 pool: fixed tick (price), settable liquidity, fee; observe() feeds the
///      TWAP path with a constant tick so _getSqrtTwapX96 resolves to TickMath at that tick.
contract MockV3Pool {
    address public token0;
    address public token1;
    uint24 public fee;
    uint128 public liquidity;
    int24 public tick;

    constructor(address _token0, address _token1, uint24 _fee, uint128 _liquidity, int24 _tick) {
        token0 = _token0;
        token1 = _token1;
        fee = _fee;
        liquidity = _liquidity;
        tick = _tick;
    }

    function setLiquidity(uint128 _liquidity) external {
        liquidity = _liquidity;
    }

    function slot0() external view returns (uint160, int24, uint16, uint16, uint8, bool, bool) {
        return (TickMath.getSqrtRatioAtTick(tick), tick, 0, 0, 0, false, false);
    }

    /// @notice Constant tick across the window → TWAP average equals the spot tick
    function observe(uint32[] calldata) external view returns (int56[] memory, uint160[] memory, bool) {
        int56[] memory ticks = new int56[](2);
        ticks[0] = int56(tick);
        ticks[1] = int56(tick);
        uint160[] memory secondsPerLiquidity = new uint160[](2);
        return (ticks, secondsPerLiquidity, false);
    }
}

/// @dev Storage-free pool registries vm.etch-ed at the compile-time constant address
contract AlwaysRegisteredPoolRegistry {
    function isPoolRegistered(address) external pure returns (bool) {
        return true;
    }
}

contract NeverRegisteredPoolRegistry {
    function isPoolRegistered(address) external pure returns (bool) {
        return false;
    }
}

// ═══════════════════════════════════════════════════════════════════════
//                                  Tests
// ═══════════════════════════════════════════════════════════════════════

contract UniswapV3DepthQuoteFacetTest is Test {
    UniswapV3DepthQuoteFacet internal facet;

    MockDepthToken internal usdc; // token0, 6 decimals
    MockDepthToken internal link; // token1, 18 decimals
    MockV3Pool internal pool;

    uint24 internal constant FEE = 3000; // 0.3%
    uint128 internal constant POOL_LIQUIDITY = 5_000_000e18;
    int24 internal constant TICK = 0; // price = 1.0 raw token1/token0

    function setUp() public {
        // The facet validates pools against the compile-time registry constant; etch a
        // storage-free always-registered registry at that address for unit testing.
        address registryConstant = ArbitrumOneAddresses.POOL_REGISTRY_ADDRESS;
        vm.etch(registryConstant, address(new AlwaysRegisteredPoolRegistry()).code);

        usdc = new MockDepthToken("USDC", 6);
        link = new MockDepthToken("LINK", 18);
        pool = new MockV3Pool(address(usdc), address(link), FEE, POOL_LIQUIDITY, TICK);
        facet = new UniswapV3DepthQuoteFacet();
    }

    function _quoteInput(uint256 amountIn) internal view returns (QuoteInstruction memory) {
        address[] memory tokens = new address[](2);
        tokens[0] = address(usdc);
        tokens[1] = address(link);
        address[] memory pools = new address[](1);
        pools[0] = address(pool);
        return QuoteInstruction({ amount: amountIn, tokens: tokens, pools: pools, exactOutput: false });
    }

    /// @dev Base quote math at tick 0: out = in × sqrtP²/2¹⁹² × (1e6 − fee)/1e6 = in × 0.997
    function _expectedOut(uint256 amountIn) internal pure returns (uint256) {
        return amountIn * (1e6 - FEE) / 1e6;
    }

    function test_selectorMatchesUniswapV3Facet() external view {
        assertEq(
            UniswapV3DepthQuoteFacet.uniswapV3Quote.selector,
            bytes4(0xc86f92af),
            "selector must match the registry-stored quote selector"
        );
    }

    function test_deepPool_quotesIdenticalToBaseMath() public {
        // Pool holds plenty of LINK: 1000 USDC worth of output is trivially covered
        link.setBalance(address(pool), 1_000_000e18);

        uint256 amountIn = 1000e6;
        uint256 out = facet.uniswapV3Quote(_quoteInput(amountIn));
        assertEq(out, _expectedOut(amountIn));
    }

    function test_zeroLiquidityPool_reverts() public {
        link.setBalance(address(pool), 1_000_000e18);
        pool.setLiquidity(0);

        vm.expectRevert(abi.encodeWithSelector(UniswapV3DepthQuote_ZeroLiquidity.selector, address(pool)));
        facet.uniswapV3Quote(_quoteInput(1000e6));
    }

    function test_dustPool_revertsInsufficientDepth_incidentShape() public {
        // The production incident in miniature: a pool whose output-token holdings are just
        // under 4x the quoted output cannot feasibly fill the trade at a sane price. Its spot
        // price (and 30s TWAP) look perfectly normal, so a price-only quote would happily
        // select it and the router would revert "Too little received" at execution time.
        uint256 amountIn = 349e6;
        uint256 quotedOut = _expectedOut(amountIn);
        uint256 dustBalance = quotedOut * 4 - 1; // one wei short of full 4x coverage

        link.setBalance(address(pool), dustBalance);
        assertGt(quotedOut, dustBalance / 4, "test setup: quote must exceed 25% coverage");

        vm.expectRevert(
            abi.encodeWithSelector(
                UniswapV3DepthQuote_InsufficientDepth.selector, address(pool), quotedOut, dustBalance / 4
            )
        );
        facet.uniswapV3Quote(_quoteInput(amountIn));
    }

    function test_exactlyAtCoverageBoundary_passes() public {
        // quotedOut == balance/4 exactly is allowed (strict > in the check)
        uint256 amountIn = 1000e6;
        uint256 quotedOut = _expectedOut(amountIn);
        link.setBalance(address(pool), quotedOut * 4);

        uint256 out = facet.uniswapV3Quote(_quoteInput(amountIn));
        assertEq(out, quotedOut);
    }

    function test_exactOutput_depthChecksDesiredOutput() public {
        link.setBalance(address(pool), 1_000_000e18);

        address[] memory tokens = new address[](2);
        tokens[0] = address(usdc);
        tokens[1] = address(link);
        address[] memory pools = new address[](1);
        pools[0] = address(pool);
        QuoteInstruction memory inst =
            QuoteInstruction({ amount: 1000e6, tokens: tokens, pools: pools, exactOutput: true });

        // Desired output above the pool's LINK balance / 4 → depth revert on the reverse path
        link.setBalance(address(pool), 3e9); // maxAllowed = 750_000_000 < desired 1e9
        vm.expectRevert(
            abi.encodeWithSelector(UniswapV3DepthQuote_InsufficientDepth.selector, address(pool), 1000e6, 750_000_000)
        );
        facet.uniswapV3Quote(inst);
    }

    function test_unregisteredPool_reverts_viaRegistryConstant() public {
        vm.etch(ArbitrumOneAddresses.POOL_REGISTRY_ADDRESS, address(new NeverRegisteredPoolRegistry()).code);
        link.setBalance(address(pool), 1_000_000e18);

        vm.expectRevert(UniswapV3Facet_UnregisteredPool.selector);
        facet.uniswapV3Quote(_quoteInput(1000e6));
    }

    function test_invalidPath_reverts() public {
        address[] memory tokens = new address[](1); // must be hops + 1
        tokens[0] = address(usdc);
        address[] memory pools = new address[](1);
        pools[0] = address(pool);
        QuoteInstruction memory inst =
            QuoteInstruction({ amount: 1000e6, tokens: tokens, pools: pools, exactOutput: false });

        vm.expectRevert(UniswapV3Facet_InvalidPath.selector);
        facet.uniswapV3Quote(inst);
    }
}
