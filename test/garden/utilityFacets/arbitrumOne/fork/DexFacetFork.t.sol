// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// ============================================================================
// Fresh protocol infrastructure (deployed from current source)
// ============================================================================
import { Garden } from "src/garden/Garden.sol";
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
import { ProtocolStatus } from "src/protocolStatus/ProtocolStatus.sol";
import { LiquidityPoolRegistry } from "src/liquidityPoolRegistry/LiquidityPoolRegistry.sol";
import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";
import { SwapInstruction, QuoteInstruction } from "src/interfaces/ISwapInstruction.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";
import { IDiamondLoupe } from "src/garden/facets/baseFacets/loupe/IDiamondLoupe.sol";
import { DiamondCutFacet } from "src/garden/facets/baseFacets/cut/DiamondCutFacet.sol";
import { DiamondLoupeFacet } from "src/garden/facets/baseFacets/loupe/DiamondLoupeFacet.sol";
import { OwnershipFacet } from "src/garden/facets/baseFacets/ownership/OwnershipFacet.sol";
import { UpgradeFacet } from "src/garden/facets/baseFacets/upgrade/UpgradeFacet.sol";
import { IUpgrade } from "src/garden/facets/baseFacets/upgrade/IUpgrade.sol";
import { GardenFactory } from "src/factory/GardenFactory.sol";

// ============================================================================
// Real Arbitrum One DEX facets (under test)
// ============================================================================
import { UniswapV2Facet } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV2/UniswapV2Facet.sol";
import { IUniswapV2 } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV2/IUniswapV2.sol";
import { UniswapV3Facet } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3Facet.sol";
import { IUniswapV3 } from "src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/IUniswapV3.sol";
import { CamelotV2Facet } from "src/garden/facets/utilityFacets/arbitrumOne/camelotV2/CamelotV2Facet.sol";
import { ICamelotV2 } from "src/garden/facets/utilityFacets/arbitrumOne/camelotV2/ICamelotV2.sol";
import { CamelotV3Facet } from "src/garden/facets/utilityFacets/arbitrumOne/camelotV3/CamelotV3Facet.sol";
import { ICamelotV3 } from "src/garden/facets/utilityFacets/arbitrumOne/camelotV3/ICamelotV3.sol";

/**
 * @title DexFacetForkTest
 * @notice Arbitrum One fork tests for the four DEX integration facets (Uniswap V2,
 *         Uniswap V3, Camelot V2, Camelot V3) installed in a fresh Garden diamond.
 *
 *         WHAT'S REAL (from the fork state, used as-is):
 *           - WETH (0x82aF...), native USDC (0xaf88...) token contracts
 *           - The canonical WETH/USDC liquidity pool per DEX (verified against the
 *             DEX factory at the pinned block):
 *               Uniswap V2 : 0xF64Dfe17C8b87F012FCf50FbDA1D62bfA148366a (factory getPair)
 *               Uniswap V3 : 0xC6962004f452bE9203591991D15f6b388e09E8D0 (fee tier 500,
 *                             factory getPool(WETH, USDC, 500)). NOTE: the commonly
 *                             cited "classic" 0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443
 *                             is the WETH/USDC.e (bridged USDC) pool — the garden
 *                             trades native USDC, so the native-USDC pool is used.
 *               Camelot V2 : 0x54B26fAf3671677C19F70c4B879A6f7B898F732c (factory getPair)
 *               Camelot V3 : 0xB1026b8e7276e7AC75410F1fcbbe21796e8f7526 (factory poolByPair)
 *           - The real DEX routers (all verified to have code at the pinned block):
 *               Uniswap V2 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24,
 *               Uniswap V3 0xE592427A0AEce92De3Edee1F18E0157C05861564,
 *               Camelot V2 0xc873fEcbd354f5A56E00E710B90EF4201db2448d,
 *               Camelot V3 0x1F721E2E82F6676FCE4eA07A5958cF098D339e18
 *           - Pool funding: WETH is transferred out of the DEX's own WETH/USDC pool
 *             by impersonating the pool (vm.prank + transfer — no minting).
 *
 *         WHAT'S FRESH (deployed from current src/, NOT the live protocol):
 *           - FacetRegistry, ProtocolStatus, GardenFactory, Garden (via factory),
 *             LiquidityPoolRegistry (fresh implementation etched over the pool
 *             registry address hardcoded inside the facets), and the four DEX
 *             facets registered in a single DEX module.
 *
 *         FORK BLOCK: by default the fork is taken at the LATEST block (deterministic
 *         within the run — quotes and swaps share one frozen fork state). The public
 *         Arbitrum RPC prunes historical state within ~30 minutes, so a pinned block
 *         is only reproducible with an archive RPC; set ARBITRUM_FORK_BLOCK to pin
 *         a specific block (0 = latest, the default).
 *
 *         Run with:
 *           RPC_URL_ARBITRUM=https://arb1.arbitrum.io/rpc forge test \
 *             --match-path "test/garden/utilityFacets/arbitrumOne/fork/" -vvv
 */
contract DexFacetForkTest is Test {
    // ========================================================================
    // Arbitrum One real addresses
    // ========================================================================
    address internal constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    /// @notice Canonical WETH/USDC pools (verified via DEX factory calls at FORK_BLOCK)
    address internal constant UNISWAP_V2_POOL = 0xF64Dfe17C8b87F012FCf50FbDA1D62bfA148366a;
    address internal constant UNISWAP_V3_POOL = 0xC6962004f452bE9203591991D15f6b388e09E8D0;
    address internal constant CAMELOT_V2_POOL = 0x54B26fAf3671677C19F70c4B879A6f7B898F732c;
    address internal constant CAMELOT_V3_POOL = 0xB1026b8e7276e7AC75410F1fcbbe21796e8f7526;

    /// @notice LiquidityPoolRegistry address hardcoded inside the current DEX facet sources
    address internal constant POOL_REGISTRY = 0x8C7ab1B167caB83486D518969d4D004C8E91b960;
    /// @notice Previous pool registry address (some deployed/live protocol versions still
    ///         hardcode this one inside the facets)
    address internal constant POOL_REGISTRY_LEGACY = 0xA3178280c191dD46c551b91c651F337E47594d85;

    /// @notice Reference fork block (verified servable at development time).
    ///         The public Arbitrum RPC prunes historical state within ~30 minutes, so the
    ///         default is to fork at the latest block. Set ARBITRUM_FORK_BLOCK to pin a
    ///         specific block for reproducibility (use an archive RPC via RPC_URL_ARBITRUM
    ///         for old blocks), or set it to 0 to fork at latest (default).
    uint256 internal constant FORK_BLOCK = 494_045_497;

    // ========================================================================
    // Protocol identifiers
    // ========================================================================
    bytes32 internal constant MODULE_DEX = keccak256("DEX");
    bytes32 internal constant GARDEN_TYPE = keccak256("DEX_FORK_TEST");
    bytes32 internal constant DEX_UNISWAP_V2 = keccak256("UNISWAP_V2");
    bytes32 internal constant DEX_UNISWAP_V3 = keccak256("UNISWAP_V3");
    bytes32 internal constant DEX_CAMELOT_V2 = keccak256("CAMELOT_V2");
    bytes32 internal constant DEX_CAMELOT_V3 = keccak256("CAMELOT_V3");

    // ========================================================================
    // Test state
    // ========================================================================
    address internal owner; // test user that owns the garden
    FacetRegistry internal registry;
    ProtocolStatus internal protocolStatus;
    GardenFactory internal factory;
    Garden internal garden;
    UniswapV2Facet internal uniswapV2Facet;
    UniswapV3Facet internal uniswapV3Facet;
    CamelotV2Facet internal camelotV2Facet;
    CamelotV3Facet internal camelotV3Facet;

    // Swap sizes (kept small to keep pool impact negligible; Camelot V2 pool is shallow)
    uint256 internal constant WETH_AMOUNT = 0.05e18;
    uint256 internal constant CAMELOT_V2_AMOUNT = 0.001e18;

    /// @notice Slippage buffer applied to facet quotes for minOut
    uint256 internal constant SLIPPAGE_PCT = 5; // 5%

    // ========================================================================
    // Setup — fresh protocol stack + real fork state
    // ========================================================================
    function setUp() public {
        string memory rpcUrl = vm.envOr("RPC_URL_ARBITRUM", string("https://arb1.arbitrum.io/rpc"));
        // ARBITRUM_FORK_BLOCK = 0 (default) -> fork at the latest block. The public RPC
        // prunes historical state, so a pinned block can only be used with an archive RPC
        // or shortly after it was mined. Quotes and swaps run against the same frozen fork
        // state, so outcomes are deterministic regardless of the fork block.
        uint256 forkBlock = vm.envOr("ARBITRUM_FORK_BLOCK", uint256(0));
        if (forkBlock == 0) {
            vm.createSelectFork(rpcUrl);
        } else {
            vm.createSelectFork(rpcUrl, forkBlock);
        }

        owner = makeAddr("gardenOwner");

        // Fresh LiquidityPoolRegistry implementation etched over the address
        // hardcoded inside the DEX facets (old live registry is not used).
        _installPoolRegistryAtHardcodedAddress();
        _registerDexesAndPools();

        // Fresh FacetRegistry: base facets + DEX module containing the four real facets
        registry = _deployFacetRegistry();
        registry.registerModule(MODULE_DEX);
        registry.upgradeModule(MODULE_DEX, _dexModuleCuts());

        bytes32[] memory modules = new bytes32[](1);
        modules[0] = MODULE_DEX;
        registry.addGardenType(GARDEN_TYPE, modules);

        // Fresh ProtocolStatus + GardenFactory
        protocolStatus = new ProtocolStatus(address(this));
        factory = new GardenFactory(address(this), address(registry), address(protocolStatus));

        // One garden owned by the test user, created through the fresh factory
        vm.prank(owner);
        garden = Garden(payable(factory.createGarden(1, GARDEN_TYPE)));

        // Install the DEX module on the garden (two-step upgrade flow)
        _upgradeGarden();

        // Prove the DEX module is live on the diamond
        assertEq(
            IDiamondLoupe(address(garden)).facetAddress(IUniswapV2.uniswapV2Swap.selector),
            address(uniswapV2Facet),
            "uniswapV2Swap not installed"
        );
        assertEq(
            IDiamondLoupe(address(garden)).facetAddress(IUniswapV3.uniswapV3Swap.selector),
            address(uniswapV3Facet),
            "uniswapV3Swap not installed"
        );
        assertEq(
            IDiamondLoupe(address(garden)).facetAddress(ICamelotV2.camelotV2Swap.selector),
            address(camelotV2Facet),
            "camelotV2Swap not installed"
        );
        assertEq(
            IDiamondLoupe(address(garden)).facetAddress(ICamelotV3.camelotV3Swap.selector),
            address(camelotV3Facet),
            "camelotV3Swap not installed"
        );
    }

    // ========================================================================
    // Uniswap V2
    // ========================================================================

    /// @notice Real WETH -> USDC swap on the canonical Uniswap V2 pool with deadline 0
    ///         (facets default to block.timestamp + 30 minutes).
    function testFork_UniswapV2_SwapWithDeadlineZero() public {
        uint256 amountIn = WETH_AMOUNT;
        _fundGardenFromPool(UNISWAP_V2_POOL, amountIn);
        _syncV2Pair(UNISWAP_V2_POOL);

        // Deterministic expectation via the facet's own quote (router getAmountsOut)
        uint256 expected =
            IUniswapV2(address(garden)).uniswapV2Quote(_quoteInstruction(UNISWAP_V2_POOL, amountIn));
        uint256 minOut = _applySlippage(expected);

        (uint256 outReceived, uint256 wethSpent) = _executeSwap(
            IUniswapV2.uniswapV2Swap.selector,
            abi.encodeWithSelector(IUniswapV2.uniswapV2Swap.selector, _swapInstruction(UNISWAP_V2_POOL, amountIn, minOut, 0))
        );

        _assertSwapOutcome(amountIn, wethSpent, minOut, outReceived, expected, "UniswapV2(deadline=0)");
    }

    /// @notice Same swap with an explicit future deadline.
    function testFork_UniswapV2_SwapWithExplicitDeadline() public {
        uint256 amountIn = WETH_AMOUNT;
        _fundGardenFromPool(UNISWAP_V2_POOL, amountIn);
        _syncV2Pair(UNISWAP_V2_POOL);

        uint256 expected =
            IUniswapV2(address(garden)).uniswapV2Quote(_quoteInstruction(UNISWAP_V2_POOL, amountIn));
        uint256 minOut = _applySlippage(expected);

        (uint256 outReceived, uint256 wethSpent) = _executeSwap(
            IUniswapV2.uniswapV2Swap.selector,
            abi.encodeWithSelector(
                IUniswapV2.uniswapV2Swap.selector,
                _swapInstruction(UNISWAP_V2_POOL, amountIn, minOut, block.timestamp + 30 minutes)
            )
        );

        _assertSwapOutcome(amountIn, wethSpent, minOut, outReceived, expected, "UniswapV2(explicit deadline)");
    }

    /// @notice Expired deadline (block.timestamp - 1) reverts at the real router.
    function testFork_UniswapV2_ExpiredDeadlineReverts() public {
        uint256 amountIn = WETH_AMOUNT;
        _fundGardenFromPool(UNISWAP_V2_POOL, amountIn);

        vm.expectRevert(bytes("UniswapV2Router: EXPIRED"));
        vm.prank(owner);
        IUniswapV2(address(garden)).uniswapV2Swap(
            _swapInstruction(UNISWAP_V2_POOL, amountIn, 1, block.timestamp - 1)
        );
    }

    // ========================================================================
    // Uniswap V3
    // ========================================================================

    /// @notice Real WETH -> USDC swap on the canonical Uniswap V3 pool (fee 500) with deadline 0.
    function testFork_UniswapV3_SwapWithDeadlineZero() public {
        uint256 amountIn = WETH_AMOUNT;
        _fundGardenFromPool(UNISWAP_V3_POOL, amountIn);

        // Facet quote uses 30s TWAP; execution is at spot — 5% buffer absorbs the skew.
        uint256 expected =
            IUniswapV3(address(garden)).uniswapV3Quote(_quoteInstruction(UNISWAP_V3_POOL, amountIn));
        uint256 minOut = _applySlippage(expected);

        (uint256 outReceived, uint256 wethSpent) = _executeSwap(
            IUniswapV3.uniswapV3Swap.selector,
            abi.encodeWithSelector(IUniswapV3.uniswapV3Swap.selector, _swapInstruction(UNISWAP_V3_POOL, amountIn, minOut, 0))
        );

        _assertSwapOutcome(amountIn, wethSpent, minOut, outReceived, expected, "UniswapV3(deadline=0)");
    }

    /// @notice Same swap with an explicit future deadline.
    function testFork_UniswapV3_SwapWithExplicitDeadline() public {
        uint256 amountIn = WETH_AMOUNT;
        _fundGardenFromPool(UNISWAP_V3_POOL, amountIn);

        uint256 expected =
            IUniswapV3(address(garden)).uniswapV3Quote(_quoteInstruction(UNISWAP_V3_POOL, amountIn));
        uint256 minOut = _applySlippage(expected);

        (uint256 outReceived, uint256 wethSpent) = _executeSwap(
            IUniswapV3.uniswapV3Swap.selector,
            abi.encodeWithSelector(
                IUniswapV3.uniswapV3Swap.selector,
                _swapInstruction(UNISWAP_V3_POOL, amountIn, minOut, block.timestamp + 30 minutes)
            )
        );

        _assertSwapOutcome(amountIn, wethSpent, minOut, outReceived, expected, "UniswapV3(explicit deadline)");
    }

    /// @notice DOCUMENTS CURRENT FACET BEHAVIOR: UniswapV3Base._uniswapV3Swap ignores the
    ///         instruction deadline entirely — the router deadline is hardcoded to
    ///         block.timestamp. An expired instruction deadline therefore does NOT
    ///         revert; the swap executes normally. (V2 facets do enforce the deadline.)
    function testFork_UniswapV3_ExpiredInstructionDeadlineNotEnforced() public {
        uint256 amountIn = WETH_AMOUNT;
        _fundGardenFromPool(UNISWAP_V3_POOL, amountIn);

        uint256 expected =
            IUniswapV3(address(garden)).uniswapV3Quote(_quoteInstruction(UNISWAP_V3_POOL, amountIn));
        uint256 minOut = _applySlippage(expected);

        (uint256 outReceived, uint256 wethSpent) = _executeSwap(
            IUniswapV3.uniswapV3Swap.selector,
            abi.encodeWithSelector(
                IUniswapV3.uniswapV3Swap.selector,
                _swapInstruction(UNISWAP_V3_POOL, amountIn, minOut, block.timestamp - 1)
            )
        );

        assertGe(outReceived, minOut, "expired instruction deadline should still execute (facet overrides to block.timestamp)");
        console2.log("UniswapV3(expired instruction deadline): swap executed (deadline not enforced by facet)");
    }

    // ========================================================================
    // Camelot V2
    // ========================================================================

    /// @notice Real WETH -> USDC swap on the canonical Camelot V2 pool with deadline 0.
    ///         Small amount — the canonical Camelot V2 WETH/USDC pool is shallow.
    function testFork_CamelotV2_SwapWithDeadlineZero() public {
        uint256 amountIn = CAMELOT_V2_AMOUNT;
        _fundGardenFromPool(CAMELOT_V2_POOL, amountIn);
        _syncV2Pair(CAMELOT_V2_POOL);

        uint256 expected =
            ICamelotV2(address(garden)).camelotV2Quote(_quoteInstruction(CAMELOT_V2_POOL, amountIn));
        uint256 minOut = _applySlippage(expected);

        (uint256 outReceived, uint256 wethSpent) = _executeSwap(
            ICamelotV2.camelotV2Swap.selector,
            abi.encodeWithSelector(ICamelotV2.camelotV2Swap.selector, _swapInstruction(CAMELOT_V2_POOL, amountIn, minOut, 0))
        );

        _assertSwapOutcome(amountIn, wethSpent, minOut, outReceived, expected, "CamelotV2(deadline=0)");
    }

    /// @notice Same swap with an explicit future deadline.
    function testFork_CamelotV2_SwapWithExplicitDeadline() public {
        uint256 amountIn = CAMELOT_V2_AMOUNT;
        _fundGardenFromPool(CAMELOT_V2_POOL, amountIn);
        _syncV2Pair(CAMELOT_V2_POOL);

        uint256 expected =
            ICamelotV2(address(garden)).camelotV2Quote(_quoteInstruction(CAMELOT_V2_POOL, amountIn));
        uint256 minOut = _applySlippage(expected);

        (uint256 outReceived, uint256 wethSpent) = _executeSwap(
            ICamelotV2.camelotV2Swap.selector,
            abi.encodeWithSelector(
                ICamelotV2.camelotV2Swap.selector,
                _swapInstruction(CAMELOT_V2_POOL, amountIn, minOut, block.timestamp + 30 minutes)
            )
        );

        _assertSwapOutcome(amountIn, wethSpent, minOut, outReceived, expected, "CamelotV2(explicit deadline)");
    }

    /// @notice Expired deadline (block.timestamp - 1) reverts at the real router.
    function testFork_CamelotV2_ExpiredDeadlineReverts() public {
        uint256 amountIn = CAMELOT_V2_AMOUNT;
        _fundGardenFromPool(CAMELOT_V2_POOL, amountIn);

        vm.expectRevert(bytes("CamelotRouter: EXPIRED"));
        vm.prank(owner);
        ICamelotV2(address(garden)).camelotV2Swap(
            _swapInstruction(CAMELOT_V2_POOL, amountIn, 1, block.timestamp - 1)
        );
    }

    // ========================================================================
    // Camelot V3
    // ========================================================================

    /// @notice Real WETH -> USDC swap on the canonical Camelot V3 (Algebra) pool with deadline 0.
    /// @dev The facet's camelotV3Quote reads pool.fee()/observe() which the deployed Algebra
    ///      pool does not implement (it exposes globalState()/getTimepoints()), so the quote
    ///      would revert. The expected output is therefore computed with the same math the
    ///      facet uses, reading the pool's real spot price (globalState.price) and fee.
    function testFork_CamelotV3_SwapWithDeadlineZero() public {
        uint256 amountIn = WETH_AMOUNT;
        _fundGardenFromPool(CAMELOT_V3_POOL, amountIn);

        uint256 expected = _camelotV3SpotQuote(CAMELOT_V3_POOL, amountIn);
        uint256 minOut = _applySlippage(expected);

        (uint256 outReceived, uint256 wethSpent) = _executeSwap(
            ICamelotV3.camelotV3Swap.selector,
            abi.encodeWithSelector(ICamelotV3.camelotV3Swap.selector, _swapInstruction(CAMELOT_V3_POOL, amountIn, minOut, 0))
        );

        _assertSwapOutcome(amountIn, wethSpent, minOut, outReceived, expected, "CamelotV3(deadline=0)");
    }

    /// @notice Same swap with an explicit future deadline.
    function testFork_CamelotV3_SwapWithExplicitDeadline() public {
        uint256 amountIn = WETH_AMOUNT;
        _fundGardenFromPool(CAMELOT_V3_POOL, amountIn);

        uint256 expected = _camelotV3SpotQuote(CAMELOT_V3_POOL, amountIn);
        uint256 minOut = _applySlippage(expected);

        (uint256 outReceived, uint256 wethSpent) = _executeSwap(
            ICamelotV3.camelotV3Swap.selector,
            abi.encodeWithSelector(
                ICamelotV3.camelotV3Swap.selector,
                _swapInstruction(CAMELOT_V3_POOL, amountIn, minOut, block.timestamp + 30 minutes)
            )
        );

        _assertSwapOutcome(amountIn, wethSpent, minOut, outReceived, expected, "CamelotV3(explicit deadline)");
    }

    /// @notice DOCUMENTS CURRENT FACET BEHAVIOR: CamelotV3Base._camelotV3Swap also ignores the
    ///         instruction deadline (router deadline hardcoded to block.timestamp). An expired
    ///         instruction deadline does NOT revert; the swap executes normally.
    function testFork_CamelotV3_ExpiredInstructionDeadlineNotEnforced() public {
        uint256 amountIn = WETH_AMOUNT;
        _fundGardenFromPool(CAMELOT_V3_POOL, amountIn);

        uint256 expected = _camelotV3SpotQuote(CAMELOT_V3_POOL, amountIn);
        uint256 minOut = _applySlippage(expected);

        (uint256 outReceived, uint256 wethSpent) = _executeSwap(
            ICamelotV3.camelotV3Swap.selector,
            abi.encodeWithSelector(
                ICamelotV3.camelotV3Swap.selector,
                _swapInstruction(CAMELOT_V3_POOL, amountIn, minOut, block.timestamp - 1)
            )
        );

        assertGe(outReceived, minOut, "expired instruction deadline should still execute (facet overrides to block.timestamp)");
        console2.log("CamelotV3(expired instruction deadline): swap executed (deadline not enforced by facet)");
    }

    // ========================================================================
    // Swap helpers
    // ========================================================================

    /// @notice Executes a swap through the garden as the owner and returns the token deltas.
    /// @dev Uses a low-level call so the same helper works for all four facets. On revert the
    ///      original revert data is bubbled up so the failure reason is visible in test output.
    function _executeSwap(bytes4 selector, bytes memory data) internal returns (uint256 usdcReceived, uint256 wethSpent) {
        uint256 wethBefore = IERC20(WETH).balanceOf(address(garden));
        uint256 usdcBefore = IERC20(USDC).balanceOf(address(garden));

        vm.prank(owner);
        (bool ok, bytes memory returndata) = address(garden).call(data);
        if (!ok) {
            // Bubble up the original revert data so the failure reason is visible
            assembly {
                revert(add(returndata, 32), mload(returndata))
            }
        }

        wethSpent = wethBefore - IERC20(WETH).balanceOf(address(garden));
        usdcReceived = IERC20(USDC).balanceOf(address(garden)) - usdcBefore;
    }

    /// @notice Asserts the swap outcome: exact input spent, output >= minOut, accounting consistent.
    /// @dev The upper bound has 10% slack because the Uniswap V3 / Camelot V3 quotes are
    ///      30s-TWAP based while execution happens at the (frozen) spot price.
    function _assertSwapOutcome(
        uint256 amountIn,
        uint256 wethSpent,
        uint256 minOut,
        uint256 outReceived,
        uint256 expected,
        string memory label
    )
        internal
    {
        assertEq(wethSpent, amountIn, string(abi.encodePacked(label, ": exact input not spent")));
        assertGe(outReceived, minOut, string(abi.encodePacked(label, ": output below minOut")));
        assertLe(outReceived, expected * 110 / 100, string(abi.encodePacked(label, ": output far above quoted amount")));
        // Accounting consistency: the garden spent exactly the funded WETH and holds no residue
        assertEq(IERC20(WETH).balanceOf(address(garden)), 0, string(abi.encodePacked(label, ": WETH residue")));
        console2.log(label);
        console2.log("    amountIn:", amountIn);
        console2.log("    quoted:  ", expected);
        console2.log("    minOut:  ", minOut);
        console2.log("    received:", outReceived);
    }

    // ========================================================================
    // Quote helpers
    // ========================================================================

    function _applySlippage(uint256 quoted) internal pure returns (uint256) {
        return quoted * (100 - SLIPPAGE_PCT) / 100;
    }

    /// @notice Replicates the CamelotV3Base._quotePool math but reads the pool's real
    ///         Algebra interface (globalState price + fee instead of the nonexistent
    ///         fee()/observe() the facet assumes). Spot price == execution price on the
    ///         frozen fork, so this is the tightest deterministic predictor.
    function _camelotV3SpotQuote(address pool, uint256 amountIn) internal view returns (uint256 amountOut) {
        // The deployed pool's globalState is an 8-field struct (newer Algebra variant):
        // price, tick, fee, timepointIndex, communityFeeToken0, communityFeeToken1, extra, unlocked.
        (uint160 sqrtPriceX96, int24 tick, uint16 fee, uint16 timepointIndex, uint16 communityFeeToken0, uint16 communityFeeToken1, uint256 extra, bool unlocked) =
            IAlgebraPoolLike(pool).globalState();
        address token0 = IAlgebraPoolLike(pool).token0();
        address token1 = IAlgebraPoolLike(pool).token1();

        uint256 sqrtP = uint256(sqrtPriceX96);
        uint256 Q96 = 1 << 96;

        if (WETH == token0 && USDC == token1) {
            // token0 -> token1: out = in * sqrtP^2 / 2^192
            amountOut = Math.mulDiv(Math.mulDiv(amountIn, sqrtP, Q96), sqrtP, Q96);
        } else {
            // token1 -> token0: out = in * 2^192 / sqrtP^2
            amountOut = Math.mulDiv(Math.mulDiv(amountIn, Q96, sqrtP), Q96, sqrtP);
        }
        // Deduct the pool's swap fee (Algebra globalState.fee, in hundredths of a bip)
        amountOut = Math.mulDiv(amountOut, 1_000_000 - fee, 1_000_000);
    }

    // ========================================================================
    // Instruction builders
    // ========================================================================

    function _quoteInstruction(address pool, uint256 amount) internal pure returns (QuoteInstruction memory qi) {
        address[] memory tokens = new address[](2);
        tokens[0] = WETH;
        tokens[1] = USDC;
        address[] memory pools = new address[](1);
        pools[0] = pool;
        qi = QuoteInstruction({ amount: amount, tokens: tokens, pools: pools, exactOutput: false });
    }

    function _swapInstruction(
        address pool,
        uint256 amountIn,
        uint256 minOut,
        uint256 deadline
    )
        internal
        pure
        returns (SwapInstruction memory si)
    {
        address[] memory tokens = new address[](2);
        tokens[0] = WETH;
        tokens[1] = USDC;
        address[] memory pools = new address[](1);
        pools[0] = pool;
        si = SwapInstruction({
            amountIn: amountIn,
            amountOut: minOut,
            tokens: tokens,
            pools: pools,
            exactOutput: false,
            deadline: deadline
        });
    }

    // ========================================================================
    // Funding — real tokens transferred from the pool that holds them (no minting)
    // ========================================================================

    function _fundGardenFromPool(address pool, uint256 wethAmount) internal {
        uint256 poolWeth = IERC20(WETH).balanceOf(pool);
        assertGe(poolWeth, wethAmount, "funder pool does not hold enough WETH");
        assertEq(IERC20(WETH).balanceOf(address(garden)), 0, "garden should start with no WETH");

        vm.prank(pool); // impersonate the real pool that holds the tokens
        IERC20(WETH).transfer(address(garden), wethAmount);

        assertEq(IERC20(WETH).balanceOf(address(garden)), wethAmount, "garden funding failed");
    }

    /// @notice Syncs a V2-style pair after funding tokens out of it, so the pair's cached
    ///         reserves match its actual balances. Required because Uniswap V2 / Camelot V2
    ///         pairs compute the swap input from balance deltas and would otherwise see a
    ///         zero input (the amount transferred out is put back in by the swap).
    function _syncV2Pair(address pair) internal {
        (bool ok, bytes memory returndata) = pair.call(abi.encodeWithSignature("sync()"));
        assertTrue(ok, string(abi.encodePacked("sync failed on ", vm.toString(pair))));
        if (!ok) {
            assembly {
                revert(add(returndata, 32), mload(returndata))
            }
        }
    }

    // ========================================================================
    // Fresh protocol stack deployment
    // ========================================================================

    /// @notice Etches a freshly-deployed LiquidityPoolRegistry (current source) over the
    ///         pool registry address(es) hardcoded inside the DEX facets. No live protocol
    ///         contract is used.
    /// @dev vm.etch replaces only the code — storage survives the etch, so any stale state
    ///      (e.g. the legacy live registry at POOL_REGISTRY_LEGACY has the same DEX ids and
    ///      WETH/USDC pools registered) is wiped first; otherwise registerDex / addPool
    ///      would revert with DexAlreadyExists / PoolAlreadyExists.
    function _installPoolRegistryAtHardcodedAddress() internal {
        LiquidityPoolRegistry registryImplementation = new LiquidityPoolRegistry(address(this));

        address[2] memory targets = [POOL_REGISTRY, POOL_REGISTRY_LEGACY];
        for (uint256 i; i < targets.length; i++) {
            vm.etch(targets[i], address(registryImplementation).code);
            vm.store(targets[i], bytes32(0), bytes32(uint256(uint160(address(this)))));
            _wipeRegistryState(targets[i]);

            assertEq(
                LiquidityPoolRegistry(targets[i]).owner(),
                address(this),
                "fresh pool registry owner mismatch"
            );
            assertEq(
                LiquidityPoolRegistry(targets[i]).isDexRegistered(DEX_UNISWAP_V2),
                false,
                "stale UNISWAP_V2 registration not wiped"
            );
            assertEq(
                LiquidityPoolRegistry(targets[i]).isPoolRegistered(UNISWAP_V2_POOL),
                false,
                "stale pool registration not wiped"
            );
        }
    }

    /// @notice Zeroes the LiquidityPoolRegistry storage slots that the fresh implementation
    ///         reads for dex/pool existence, plus the EnumerableSet lengths.
    /// @dev Storage layout of the current source (EnumerableSet structs occupy one slot for
    ///      the _values array and advance the layout for their _indexes mapping member):
    ///        0 = _owner, 1 = _dexIds (values), 2 = _dexIds._indexes, 3 = _dexExists,
    ///        4 = _dexSwapSelector, 5 = _dexQuoteSelector, 6 = _dexActive,
    ///        7 = _allPools (values), 8 = _allPools._indexes, 9 = _allPairIds,
    ///        10 = _poolInfo, 11 = _pairPools, 12 = _dexPools.
    function _wipeRegistryState(address registryAddress) internal {
        bytes32[] memory dexIds = new bytes32[](4);
        dexIds[0] = DEX_UNISWAP_V2;
        dexIds[1] = DEX_UNISWAP_V3;
        dexIds[2] = DEX_CAMELOT_V2;
        dexIds[3] = DEX_CAMELOT_V3;

        address[] memory pools = new address[](4);
        pools[0] = UNISWAP_V2_POOL;
        pools[1] = UNISWAP_V3_POOL;
        pools[2] = CAMELOT_V2_POOL;
        pools[3] = CAMELOT_V3_POOL;

        // EnumerableSet _values lengths: _dexIds (1), _allPools (7), _allPairIds (9)
        vm.store(registryAddress, bytes32(uint256(1)), bytes32(0));
        vm.store(registryAddress, bytes32(uint256(7)), bytes32(0));
        vm.store(registryAddress, bytes32(uint256(9)), bytes32(0));

        for (uint256 i; i < 4; i++) {
            // _dexIds._indexes[dexId] (2) and _dexExists[dexId] (3)
            vm.store(registryAddress, keccak256(abi.encode(dexIds[i], uint256(2))), bytes32(0));
            vm.store(registryAddress, keccak256(abi.encode(dexIds[i], uint256(3))), bytes32(0));
            // _allPools._indexes[pool] (8) and _poolInfo[pool] (10)
            vm.store(registryAddress, keccak256(abi.encode(pools[i], uint256(8))), bytes32(0));
            vm.store(registryAddress, keccak256(abi.encode(pools[i], uint256(10))), bytes32(0));
        }
    }

    function _registerDexesAndPools() internal {
        address[2] memory targets = [POOL_REGISTRY, POOL_REGISTRY_LEGACY];
        for (uint256 i; i < targets.length; i++) {
            LiquidityPoolRegistry lpr = LiquidityPoolRegistry(targets[i]);

            lpr.registerDex(DEX_UNISWAP_V2, IUniswapV2.uniswapV2Swap.selector, IUniswapV2.uniswapV2Quote.selector);
            lpr.addPool(
                ILiquidityPoolRegistry.AddPoolParams({
                    poolAddress: UNISWAP_V2_POOL,
                    tokenA: WETH,
                    tokenB: USDC,
                    dexId: DEX_UNISWAP_V2,
                    pairName: "WETH/USDC"
                })
            );

            lpr.registerDex(DEX_UNISWAP_V3, IUniswapV3.uniswapV3Swap.selector, IUniswapV3.uniswapV3Quote.selector);
            lpr.addPool(
                ILiquidityPoolRegistry.AddPoolParams({
                    poolAddress: UNISWAP_V3_POOL,
                    tokenA: WETH,
                    tokenB: USDC,
                    dexId: DEX_UNISWAP_V3,
                    pairName: "WETH/USDC"
                })
            );

            lpr.registerDex(DEX_CAMELOT_V2, ICamelotV2.camelotV2Swap.selector, ICamelotV2.camelotV2Quote.selector);
            lpr.addPool(
                ILiquidityPoolRegistry.AddPoolParams({
                    poolAddress: CAMELOT_V2_POOL,
                    tokenA: WETH,
                    tokenB: USDC,
                    dexId: DEX_CAMELOT_V2,
                    pairName: "WETH/USDC"
                })
            );

            lpr.registerDex(DEX_CAMELOT_V3, ICamelotV3.camelotV3Swap.selector, ICamelotV3.camelotV3Quote.selector);
            lpr.addPool(
                ILiquidityPoolRegistry.AddPoolParams({
                    poolAddress: CAMELOT_V3_POOL,
                    tokenA: WETH,
                    tokenB: USDC,
                    dexId: DEX_CAMELOT_V3,
                    pairName: "WETH/USDC"
                })
            );
        }
    }

    function _deployFacetRegistry() internal returns (FacetRegistry deployedRegistry) {
        DiamondCutFacet cutFacet = new DiamondCutFacet();
        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();
        UpgradeFacet upgradeFacet = new UpgradeFacet();

        address[4] memory baseFacets =
            [address(cutFacet), address(loupeFacet), address(ownershipFacet), address(upgradeFacet)];

        bytes4[][] memory baseFacetSelectors = new bytes4[][](4);
        baseFacetSelectors[0] = new bytes4[](1);
        baseFacetSelectors[0][0] = cutFacet.diamondCut.selector;

        baseFacetSelectors[1] = new bytes4[](5);
        baseFacetSelectors[1][0] = loupeFacet.facets.selector;
        baseFacetSelectors[1][1] = loupeFacet.facetFunctionSelectors.selector;
        baseFacetSelectors[1][2] = loupeFacet.facetAddresses.selector;
        baseFacetSelectors[1][3] = loupeFacet.facetAddress.selector;
        baseFacetSelectors[1][4] = loupeFacet.supportsInterface.selector;

        baseFacetSelectors[2] = new bytes4[](2);
        baseFacetSelectors[2][0] = ownershipFacet.owner.selector;
        baseFacetSelectors[2][1] = ownershipFacet.transferOwnership.selector;

        baseFacetSelectors[3] = new bytes4[](3);
        baseFacetSelectors[3][0] = upgradeFacet.upgrade.selector;
        baseFacetSelectors[3][1] = upgradeFacet.upgradeDetails.selector;
        baseFacetSelectors[3][2] = upgradeFacet.getModuleVersion.selector;

        deployedRegistry = new FacetRegistry(address(this), baseFacets, baseFacetSelectors);
    }

    /// @notice Deploys the four real Arbitrum One DEX facets and builds the DEX module cuts.
    function _dexModuleCuts() internal returns (IDiamondCut.FacetCut[] memory cuts) {
        uniswapV2Facet = new UniswapV2Facet();
        uniswapV3Facet = new UniswapV3Facet();
        camelotV2Facet = new CamelotV2Facet();
        camelotV3Facet = new CamelotV3Facet();

        cuts = new IDiamondCut.FacetCut[](4);

        bytes4[] memory v2Selectors = new bytes4[](2);
        v2Selectors[0] = IUniswapV2.uniswapV2Swap.selector;
        v2Selectors[1] = IUniswapV2.uniswapV2Quote.selector;
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(uniswapV2Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: v2Selectors
        });

        bytes4[] memory v3Selectors = new bytes4[](2);
        v3Selectors[0] = IUniswapV3.uniswapV3Swap.selector;
        v3Selectors[1] = IUniswapV3.uniswapV3Quote.selector;
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(uniswapV3Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: v3Selectors
        });

        bytes4[] memory cv2Selectors = new bytes4[](2);
        cv2Selectors[0] = ICamelotV2.camelotV2Swap.selector;
        cv2Selectors[1] = ICamelotV2.camelotV2Quote.selector;
        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(camelotV2Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: cv2Selectors
        });

        bytes4[] memory cv3Selectors = new bytes4[](2);
        cv3Selectors[0] = ICamelotV3.camelotV3Swap.selector;
        cv3Selectors[1] = ICamelotV3.camelotV3Quote.selector;
        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(camelotV3Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: cv3Selectors
        });
    }

    function _upgradeGarden() internal {
        (IDiamondCut.FacetCut[] memory facetCuts, bytes32 hashData) = IUpgrade(address(garden)).upgradeDetails();
        assertEq(facetCuts.length, 4, "expected 4 DEX facet cuts pending");
        vm.prank(owner);
        IUpgrade(address(garden)).upgrade(hashData);
        assertEq(
            IUpgrade(address(garden)).getModuleVersion(MODULE_DEX),
            registry.getModuleVersion(MODULE_DEX),
            "module version not synced"
        );
    }
}

/// @notice Minimal Algebra pool interface (Camelot V3 uses Algebra-style pools:
///         globalState() instead of slot0(), getTimepoints() instead of observe()).
/// @dev The deployed pools are a newer Algebra variant whose globalState returns EIGHT
///      fields (an extra uint256 between communityFeeToken1 and the unlocked bool).
interface IAlgebraPoolLike {
    function globalState()
        external
        view
        returns (
            uint160 price,
            int24 tick,
            uint16 fee,
            uint16 timepointIndex,
            uint16 communityFeeToken0,
            uint16 communityFeeToken1,
            uint256 extra,
            bool unlocked
        );
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getTimepoints(uint32[] calldata secondsAgos)
        external
        view
        returns (
            int56[] memory tickCumulatives,
            uint160[] memory secondsPerLiquidityCumulatives,
            uint112[] memory volatilityCumulatives,
            uint256[] memory volumePerAvgLiquidityCumulatives
        );
}
