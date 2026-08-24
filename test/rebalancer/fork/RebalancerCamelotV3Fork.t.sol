// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import { Rebalancer } from "src/rebalancer/Rebalancer.sol";
import { QuoteInstruction } from "src/interfaces/ISwapInstruction.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { MockIndex, MockIndexFactory, MockComponentRegistry, MockPoolRegistry } from "../unit/RebalancerTest.t.sol";

/**
 * @title RebalancerCamelotV3ForkTest
 * @notice Deploy-gate verification for the Rebalancer's CamelotV3 swap encoding.
 *         Exercises the production Rebalancer._swapV3Style path end-to-end against
 *         the REAL CamelotV3 router on a live Arbitrum One fork:
 *           - the 7-param exactInputSingle struct (selector 0xbc651188) must decode
 *             on the real router (an 8-param UniV3 struct would revert — this test
 *             is the regression gate for that exact bug),
 *           - the real WETH/USDC CamelotV3 pool must execute the swap and produce
 *             output to the rebalancer,
 *           - the bought tokens must be distributed back to the garden.
 *
 *         Only the real CamelotV3 pool is registered for the pair, so the route
 *         cannot fall back to another DEX.
 *
 *         Run with: RPC_URL_ARBITRUM=<url> forge test --match-contract RebalancerCamelotV3ForkTest -vv
 */
contract RebalancerCamelotV3ForkTest is Test {
    // ========================================================================
    // Arbitrum One real addresses
    // ========================================================================
    address internal constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    /// @notice Canonical CamelotV3 WETH/USDC pool (token0=WETH, token1=USDC)
    address internal constant CAMELOT_V3_POOL = 0xB1026b8e7276e7AC75410F1fcbbe21796e8f7526;
    /// @notice CamelotV3 router (same address wired by DeployRebalancer.s.sol)
    address internal constant CAMELOT_V3_ROUTER = 0x1F721E2E82F6676FCE4eA07A5958cF098D339e18;
    /// @notice exactInputSingle((address,address,address,uint256,uint256,uint256,uint160))
    bytes4 internal constant CAMELOT_V3_EXACT_INPUT_SELECTOR = 0xbc651188;

    bytes32 internal constant DEX_CAMELOT_V3 = keccak256("CAMELOT_V3");
    bytes32 internal constant INDEX_TYPE = keccak256("BLOKC2");

    // ========================================================================
    // State
    // ========================================================================
    address internal owner;
    address internal alice;
    Rebalancer internal rebalancer;
    MockPoolRegistry internal poolRegistry;
    MockComponentRegistry internal compRegistry;
    MockIndexFactory internal indexFactory;
    MockIndex internal idx;
    ForkCamelotV3Quote internal quote;

    function setUp() public {
        // Skip when no Arbitrum RPC is configured (keeps plain `forge test` green)
        string memory rpcUrl = vm.envOr("RPC_URL_ARBITRUM", string(""));
        if (bytes(rpcUrl).length == 0) {
            vm.skip(true, "RPC_URL_ARBITRUM not set - set an Arbitrum RPC to run fork tests");
        }
        uint256 forkBlock = vm.envOr("ARBITRUM_FORK_BLOCK", uint256(0));
        if (forkBlock == 0) {
            vm.createSelectFork(rpcUrl);
        } else {
            vm.createSelectFork(rpcUrl, forkBlock);
        }

        owner = makeAddr("owner");
        alice = makeAddr("alice");

        // -- Mocks (production Rebalancer contract, mock registries) --
        poolRegistry = new MockPoolRegistry();
        compRegistry = new MockComponentRegistry();
        indexFactory = new MockIndexFactory();
        idx = new MockIndex();

        compRegistry.setComponent(bytes32("WETH"), WETH);
        compRegistry.setPrice(WETH, 3000e8);
        compRegistry.setComponent(bytes32("USDC"), USDC);
        compRegistry.setPrice(USDC, 1e8);

        // 100/0 WETH/USDC index: the entire USDC balance is excess → the full
        // balance must be swapped to WETH (exact, deterministic assertions).
        bytes32[] memory symbols = new bytes32[](2);
        symbols[0] = bytes32("WETH");
        symbols[1] = bytes32("USDC");
        uint256[] memory weights = new uint256[](2);
        weights[0] = 1e18;
        weights[1] = 0;
        idx.setWeights(symbols, weights);
        address[] memory gardens = new address[](1);
        gardens[0] = alice;
        idx.setGardens(gardens);
        indexFactory.setRegistered(address(idx), true);

        // -- Pool registry: ONLY the real CamelotV3 WETH/USDC pool (no fallback DEX) --
        address t0 = IAlgebraPoolLike(CAMELOT_V3_POOL).token0();
        address t1 = IAlgebraPoolLike(CAMELOT_V3_POOL).token1();
        poolRegistry.setDexRegistered(DEX_CAMELOT_V3, true);
        poolRegistry.setDexActive(DEX_CAMELOT_V3, true);
        poolRegistry.setQuoteSelector(DEX_CAMELOT_V3, ForkCamelotV3Quote.quoteOut.selector);
        poolRegistry.addPool(CAMELOT_V3_POOL, DEX_CAMELOT_V3, "WETH/USDC", t0, t1);

        // -- Real Rebalancer, wired exactly like DeployRebalancer.s.sol --
        rebalancer = new Rebalancer(
            owner,
            address(indexFactory),
            address(compRegistry),
            address(poolRegistry),
            address(1), // facetRegistry — not exercised by the swap path
            USDC
        );
        quote = new ForkCamelotV3Quote();
        vm.startPrank(owner);
        rebalancer.setDexConfig(
            DEX_CAMELOT_V3,
            CAMELOT_V3_ROUTER,
            address(quote),
            CAMELOT_V3_EXACT_INPUT_SELECTOR,
            Rebalancer.DexType.V3_CONCENTRATED
        );
        rebalancer.addIndexToType(INDEX_TYPE, address(idx));
        rebalancer.setMaxGardensPerBatch(INDEX_TYPE, 10);
        vm.stopPrank();

        // -- Fund alice with USDC only → WETH is 100% deficit, USDC is 100% excess --
        deal(USDC, alice, 2000e6);
        vm.startPrank(alice);
        IERC20(USDC).approve(address(rebalancer), type(uint256).max);
        IERC20(WETH).approve(address(rebalancer), type(uint256).max);
        vm.stopPrank();

        // Pass the 24h rebalance interval
        vm.warp(block.timestamp + 24 hours + 1);
    }

    function testFork_Rebalancer_SwapsThroughRealCamelotV3Router() public {
        uint256 usdcBefore = IERC20(USDC).balanceOf(alice);
        uint256 wethBefore = IERC20(WETH).balanceOf(alice);
        assertEq(usdcBefore, 2000e6, "precondition: alice funded with USDC only");
        assertEq(wethBefore, 0, "precondition: alice has no WETH");

        // Spot quote from the real pool — the deterministic predictor of execution
        // on the frozen fork (same math + fee the Rebalancer uses for minOut).
        address[] memory tokens = new address[](2);
        tokens[0] = USDC;
        tokens[1] = WETH;
        address[] memory pools = new address[](1);
        pools[0] = CAMELOT_V3_POOL;
        uint256 expectedWeth =
            quote.quoteOut(QuoteInstruction({ amount: 2000e6, tokens: tokens, pools: pools, exactOutput: false }));
        assertGt(expectedWeth, 0, "precondition: live spot quote must be positive");

        // Full production path: pull → route-find (CamelotV3 only) → real router
        // exactInputSingle (0xbc651188) → real Algebra pool → distribute.
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);

        uint256 wethAfter = IERC20(WETH).balanceOf(alice);
        assertGt(wethAfter, 0, "garden must receive WETH from the real CamelotV3 swap");
        // Spot == execution on the frozen fork; 5% band absorbs dust-level differences.
        assertApproxEqRel(wethAfter, expectedWeth, 0.05e18, "received WETH must match the live spot quote");
        assertEq(IERC20(USDC).balanceOf(alice), 0, "all USDC must be sold (0% USDC target)");

        // The rebalancer must not keep any swap output (all distributed to gardens)
        assertEq(IERC20(WETH).balanceOf(address(rebalancer)), 0, "rebalancer must hold no WETH");
        assertEq(IERC20(USDC).balanceOf(address(rebalancer)), 0, "rebalancer must hold no USDC");

        emit log_named_uint("WETH received by garden (wei)", wethAfter);
        emit log_named_uint("expected from spot quote (wei)", expectedWeth);
    }
}

/// @dev Algebra v1 interface used by the deployed CamelotV3 pools (globalState instead of slot0)
interface IAlgebraPoolLike {
    function token0() external view returns (address);
    function token1() external view returns (address);

    /// @dev Newer Algebra variant: 8-field struct
    function globalState()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 fee,
            uint16 timepointIndex,
            uint16 communityFeeToken0,
            uint16 communityFeeToken1,
            uint256 extra,
            bool unlocked
        );
}

/// @notice Fork quote facet: reads the REAL pool's Algebra globalState spot price and fee
///         (same math as CamelotV3Base._quotePool / DexFacetFork._camelotV3SpotQuote).
contract ForkCamelotV3Quote {
    uint256 internal constant Q96 = 1 << 96;

    function quoteOut(QuoteInstruction calldata inst) external view returns (uint256 amountOut) {
        address pool = inst.pools[0];
        address tokenIn = inst.tokens[0];

        (uint160 sqrtPriceX96,, uint16 fee,,,,,) = IAlgebraPoolLike(pool).globalState();
        address token0 = IAlgebraPoolLike(pool).token0();

        uint256 sqrtP = uint256(sqrtPriceX96);
        if (token0 == tokenIn) {
            // token0 -> token1: out = in * sqrtP^2 / 2^192
            amountOut = Math.mulDiv(Math.mulDiv(inst.amount, sqrtP, Q96), sqrtP, Q96);
        } else {
            // token1 -> token0: out = in * 2^192 / sqrtP^2
            amountOut = Math.mulDiv(Math.mulDiv(inst.amount, Q96, sqrtP), Q96, sqrtP);
        }
        // Deduct the pool's swap fee (Algebra globalState.fee, in hundredths of a bip)
        amountOut = Math.mulDiv(amountOut, 1_000_000 - fee, 1_000_000);
    }
}
