// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";
import { LiquidityPoolRegistry } from "src/liquidityPoolRegistry/LiquidityPoolRegistry.sol";
import { SwapInstruction, QuoteInstruction } from "src/interfaces/ISwapInstruction.sol";
import { IBalancerV3 } from "src/garden/facets/utilityFacets/ethereum/balancerV3/IBalancerV3.sol";
import {
    BalancerV3Base,
    BalancerV3Facet_MultiHopUnsupported,
    BalancerV3Facet_InvalidPath,
    BalancerV3Facet_InvalidAmount,
    BalancerV3Facet_DexInactive,
    BalancerV3Facet_PoolDexMismatch,
    BalancerV3Facet_Permit2AmountTooLarge
} from "src/garden/facets/utilityFacets/ethereum/balancerV3/BalancerV3Base.sol";

/// @dev Exposes the internal `_balancerV3Swap` / `_balancerV3Quote` hooks so the
///      fork test can exercise them directly without a diamond install.
contract BalancerV3ForkHarness is BalancerV3Base {
    function swap(SwapInstruction calldata instruction) external {
        _balancerV3Swap(instruction);
    }

    function quote(QuoteInstruction calldata instruction) external view returns (uint256) {
        return _balancerV3Quote(instruction);
    }
}

contract BalancerV3FacetForkTest is Test {
    address internal constant POOL_REGISTRY = 0xDe6338E4dd7B0A2076e8CE63cC0443dC6cE7f0B6;
    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address internal constant BALANCER_POOL = 0x111ce2A60C30f6058A57D0dBAe1A39A42D998826;
    address internal constant TOKEN_IN = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant TOKEN_OUT = 0x4ba01f22827018b4772CD326C7627FB4956A7C00;

    bytes32 internal constant BALANCER_V3 = keccak256("BALANCER_V3");
    bytes32 internal constant OTHER_DEX = keccak256("UNISWAP_V3");

    BalancerV3ForkHarness internal harness;

    function setUp() public {
        string memory rpcUrl = _mainnetRpcUrl();
        vm.skip(bytes(rpcUrl).length == 0, "MAINNET_RPC_URL or API_KEY_ALCHEMY not set");

        _selectMainnetFork(rpcUrl);

        harness = new BalancerV3ForkHarness();

        _installPoolRegistry();
        _registerBalancerDex();
        _registerBalancerPool();
    }

    // ========================================================================
    // Happy path — real Balancer V3 router, vault and pool on forked mainnet
    // ========================================================================

    function testForkExactInputSingleSwapsAgainstMainnetBalancerV3() public {
        uint256 amountIn = 1_000_000;
        deal(TOKEN_IN, address(harness), amountIn);

        uint256 tokenInBalanceBefore = IERC20(TOKEN_IN).balanceOf(address(harness));
        uint256 tokenOutBalanceBefore = IERC20(TOKEN_OUT).balanceOf(address(harness));

        harness.swap(_singleHopInstruction(amountIn, 1, false));

        uint256 tokenInSpent = tokenInBalanceBefore - IERC20(TOKEN_IN).balanceOf(address(harness));
        uint256 tokenOutReceived = IERC20(TOKEN_OUT).balanceOf(address(harness)) - tokenOutBalanceBefore;

        assertEq(tokenInSpent, amountIn);
        assertGt(tokenOutReceived, 0);
        assertEq(IERC20(TOKEN_IN).allowance(address(harness), PERMIT2), 0);
    }

    function testForkExactOutputSingleSwapsAgainstMainnetBalancerV3() public {
        uint256 amountInMaximum = 1_000_000;
        uint256 amountOut = 0.01 ether;
        deal(TOKEN_IN, address(harness), amountInMaximum);

        uint256 tokenInBalanceBefore = IERC20(TOKEN_IN).balanceOf(address(harness));
        uint256 tokenOutBalanceBefore = IERC20(TOKEN_OUT).balanceOf(address(harness));

        harness.swap(_singleHopInstruction(amountInMaximum, amountOut, true));

        uint256 tokenInSpent = tokenInBalanceBefore - IERC20(TOKEN_IN).balanceOf(address(harness));
        uint256 tokenOutReceived = IERC20(TOKEN_OUT).balanceOf(address(harness)) - tokenOutBalanceBefore;

        assertEq(tokenOutReceived, amountOut);
        assertGt(tokenInSpent, 0);
        assertLe(tokenInSpent, amountInMaximum);
        assertEq(IERC20(TOKEN_IN).allowance(address(harness), PERMIT2), 0);
    }

    function testForkQuoteExactInReturnsNonZero() public view {
        uint256 quoted = harness.quote(_singleHopQuote(1_000_000, false));
        assertGt(quoted, 0);
    }

    function testForkQuoteExactOutReturnsNonZero() public view {
        uint256 quoted = harness.quote(_singleHopQuote(0.01 ether, true));
        assertGt(quoted, 0);
    }

    // ========================================================================
    // Rejections — exercised against the real registry / router / vault
    // ========================================================================

    function testForkSwapRevertsWhenDexInactive() public {
        LiquidityPoolRegistry(POOL_REGISTRY).setDexActive(BALANCER_V3, false);

        vm.expectRevert(BalancerV3Facet_DexInactive.selector);
        harness.swap(_singleHopInstruction(1_000_000, 1, false));
    }

    function testForkSwapRevertsOnMultiHopPath() public {
        address[] memory tokens = new address[](3);
        tokens[0] = TOKEN_IN;
        tokens[1] = address(0xdead);
        tokens[2] = TOKEN_OUT;

        address[] memory pools = new address[](2);
        pools[0] = BALANCER_POOL;
        pools[1] = address(0xbeef);

        SwapInstruction memory inst = SwapInstruction({
            amountIn: 1_000_000, amountOut: 1, tokens: tokens, pools: pools, exactOutput: false, deadline: 0
        });

        vm.expectRevert(BalancerV3Facet_MultiHopUnsupported.selector);
        this.callSwap(inst);
    }

    function testForkSwapRevertsWhenTokensLengthIsNotTwo() public {
        address[] memory tokens = new address[](3);
        tokens[0] = TOKEN_IN;
        tokens[1] = address(0xdead);
        tokens[2] = TOKEN_OUT;

        address[] memory pools = new address[](1);
        pools[0] = BALANCER_POOL;

        SwapInstruction memory inst = SwapInstruction({
            amountIn: 1_000_000, amountOut: 1, tokens: tokens, pools: pools, exactOutput: false, deadline: 0
        });

        vm.expectRevert(BalancerV3Facet_InvalidPath.selector);
        this.callSwap(inst);
    }

    function testForkSwapRevertsWhenPoolDexIdMismatches() public {
        // Re-register the same live Balancer pool under a different dex so that
        // `poolInfo.dexId != BALANCER_V3` inside `_validatePool`.
        LiquidityPoolRegistry registry = LiquidityPoolRegistry(POOL_REGISTRY);
        registry.registerDex(OTHER_DEX, bytes4(uint32(1)), bytes4(uint32(2)));
        registry.removePool(BALANCER_POOL);
        registry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: BALANCER_POOL,
                tokenA: TOKEN_IN,
                tokenB: TOKEN_OUT,
                dexId: OTHER_DEX,
                pairName: "msUSD/USDC"
            })
        );

        vm.expectRevert(BalancerV3Facet_PoolDexMismatch.selector);
        harness.swap(_singleHopInstruction(1_000_000, 1, false));
    }

    function testForkSwapRevertsWhenAmountExceedsPermit2Limit() public {
        uint256 amountIn = uint256(type(uint160).max) + 1;
        deal(TOKEN_IN, address(harness), amountIn);

        vm.expectRevert(abi.encodeWithSelector(BalancerV3Facet_Permit2AmountTooLarge.selector, amountIn));
        harness.swap(_singleHopInstruction(amountIn, 1, false));
    }

    function testForkSwapRevertsOnZeroAmountIn() public {
        vm.expectRevert(BalancerV3Facet_InvalidAmount.selector);
        harness.swap(_singleHopInstruction(0, 1, false));
    }

    function testForkSwapRevertsOnZeroAmountOut() public {
        // F1 regression: a zero slippage floor / zero exact-out must also revert.
        vm.expectRevert(BalancerV3Facet_InvalidAmount.selector);
        harness.swap(_singleHopInstruction(1_000_000, 0, false));
    }

    function testForkQuoteRevertsOnMultiHop() public {
        address[] memory tokens = new address[](3);
        tokens[0] = TOKEN_IN;
        tokens[1] = address(0xdead);
        tokens[2] = TOKEN_OUT;

        address[] memory pools = new address[](2);
        pools[0] = BALANCER_POOL;
        pools[1] = address(0xbeef);

        QuoteInstruction memory inst =
            QuoteInstruction({ amount: 1_000_000, tokens: tokens, pools: pools, exactOutput: false });

        vm.expectRevert(BalancerV3Facet_MultiHopUnsupported.selector);
        this.callQuote(inst);
    }

    function testForkQuoteRevertsOnZeroAmount() public {
        vm.expectRevert(BalancerV3Facet_InvalidAmount.selector);
        harness.quote(_singleHopQuote(0, false));
    }

    // ========================================================================
    // External re-entry points — force memory → calldata coercion for expectRevert
    // ========================================================================

    function callSwap(SwapInstruction calldata inst) external {
        harness.swap(inst);
    }

    function callQuote(QuoteInstruction calldata inst) external view returns (uint256) {
        return harness.quote(inst);
    }

    // ========================================================================
    // Helpers
    // ========================================================================

    function _singleHopInstruction(
        uint256 amountIn,
        uint256 amountOut,
        bool exactOutput
    )
        internal
        pure
        returns (SwapInstruction memory instruction)
    {
        address[] memory tokens = new address[](2);
        tokens[0] = TOKEN_IN;
        tokens[1] = TOKEN_OUT;

        address[] memory pools = new address[](1);
        pools[0] = BALANCER_POOL;

        instruction = SwapInstruction({
            amountIn: amountIn,
            amountOut: amountOut,
            tokens: tokens,
            pools: pools,
            exactOutput: exactOutput,
            deadline: 0
        });
    }

    function _singleHopQuote(
        uint256 amount,
        bool exactOutput
    )
        internal
        pure
        returns (QuoteInstruction memory instruction)
    {
        address[] memory tokens = new address[](2);
        tokens[0] = TOKEN_IN;
        tokens[1] = TOKEN_OUT;

        address[] memory pools = new address[](1);
        pools[0] = BALANCER_POOL;

        instruction = QuoteInstruction({ amount: amount, tokens: tokens, pools: pools, exactOutput: exactOutput });
    }

    function _installPoolRegistry() internal {
        LiquidityPoolRegistry registryImplementation = new LiquidityPoolRegistry(address(this));

        vm.etch(POOL_REGISTRY, address(registryImplementation).code);
        vm.store(POOL_REGISTRY, bytes32(0), bytes32(uint256(uint160(address(this)))));

        assertEq(LiquidityPoolRegistry(POOL_REGISTRY).owner(), address(this));
    }

    function _registerBalancerDex() internal {
        LiquidityPoolRegistry(POOL_REGISTRY)
            .registerDex(BALANCER_V3, IBalancerV3.balancerV3Swap.selector, IBalancerV3.balancerV3Quote.selector);
    }

    function _registerBalancerPool() internal {
        LiquidityPoolRegistry(POOL_REGISTRY)
            .addPool(
                ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: BALANCER_POOL,
                tokenA: TOKEN_IN,
                tokenB: TOKEN_OUT,
                dexId: BALANCER_V3,
                pairName: "msUSD/USDC"
            })
            );
    }

    function _mainnetRpcUrl() internal view returns (string memory rpcUrl) {
        rpcUrl = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(rpcUrl).length != 0) return rpcUrl;

        string memory alchemyKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyKey).length != 0) {
            return string.concat("https://eth-mainnet.g.alchemy.com/v2/", alchemyKey);
        }

        return "";
    }

    function _selectMainnetFork(string memory rpcUrl) internal {
        uint256 forkBlock = vm.envOr("MAINNET_FORK_BLOCK", uint256(0));
        if (forkBlock == 0) {
            vm.createSelectFork(rpcUrl);
            return;
        }

        vm.createSelectFork(rpcUrl, forkBlock);
    }
}
