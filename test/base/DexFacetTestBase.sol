// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { DiamondTestBase } from "./DiamondTestBase.sol";
import { MockERC20 } from "../mock/MockERC20.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";
import { LiquidityPoolRegistry } from "src/liquidityPoolRegistry/LiquidityPoolRegistry.sol";
import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";

// ── Import real utility facets ──────────────────────────────────────────
import { WithdrawFacet } from "src/garden/facets/utilityFacets/arbitrumOne/withdraw/WithdrawFacet.sol";
import { IWithdraw } from "src/garden/facets/utilityFacets/arbitrumOne/withdraw/IWithdraw.sol";

/// @title DexFacetTestBase
/// @author BLOK Capital DAO
/// @notice Extended Diamond test base for testing utility facets (DEX, Withdraw, Lending, etc.)
///
///         Since utility facet Base contracts use **hardcoded mainnet addresses** for routers,
///         factories, and pool registries, this base provides two usage patterns:
///
///         1. **Fork mode** (recommended for integration tests):
///            Override `setUp()`, call `vm.createSelectFork(...)`, then `super.setUp()`.
///            Real mainnet state is available — no mocks needed for protocol contracts.
///
///         2. **Local mode** (for access-control / unit tests):
///            Call `_deployMockTokens()` and `_deployPoolRegistry()` from setUp().
///            Use `vm.etch` to place mock code at hardcoded addresses if needed.
///
///         Provides:
///         - MockERC20 tokens (USDC, WETH, WBTC, DAI, ARB) with configurable decimals
///         - LiquidityPoolRegistry deployment
///         - Pool registration helpers
///         - Withdraw facet module setup helpers
///         - Token funding helpers
abstract contract DexFacetTestBase is DiamondTestBase {
    // ═══════════════════════════════════════════════════════════════════
    //                       MOCK TOKENS
    // ═══════════════════════════════════════════════════════════════════

    MockERC20 public usdc;
    MockERC20 public weth;
    MockERC20 public wbtc;
    MockERC20 public dai;
    MockERC20 public arb;

    // ═══════════════════════════════════════════════════════════════════
    //                    POOL REGISTRY
    // ═══════════════════════════════════════════════════════════════════

    LiquidityPoolRegistry public poolRegistry;

    // ═══════════════════════════════════════════════════════════════════
    //                    UTILITY FACETS
    // ═══════════════════════════════════════════════════════════════════

    WithdrawFacet public withdrawFacet;

    // ═══════════════════════════════════════════════════════════════════
    //                    UTILITY FACET SELECTORS
    // ═══════════════════════════════════════════════════════════════════

    bytes4[] public selsWithdraw;

    // ═══════════════════════════════════════════════════════════════════
    //                         SETUP
    // ═══════════════════════════════════════════════════════════════════

    function setUp() public virtual override {
        super.setUp();

        // Deploy tokens
        _deployMockTokens();

        // Deploy pool registry
        _deployPoolRegistry();

        // Deploy utility facets
        _deployUtilityFacets();
    }

    // ═══════════════════════════════════════════════════════════════════
    //                    DEPLOYMENT HELPERS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Deploy mock ERC20 tokens with standard decimals
    function _deployMockTokens() internal {
        usdc = new MockERC20("USD Coin", "USDC", 6);
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        wbtc = new MockERC20("Wrapped Bitcoin", "WBTC", 8);
        dai = new MockERC20("Dai Stablecoin", "DAI", 18);
        arb = new MockERC20("Arbitrum", "ARB", 18);
    }

    /// @notice Deploy the LiquidityPoolRegistry owned by this test contract
    function _deployPoolRegistry() internal {
        poolRegistry = new LiquidityPoolRegistry(address(this));
    }

    /// @notice Deploy utility facet contracts and build selector arrays
    function _deployUtilityFacets() internal {
        withdrawFacet = new WithdrawFacet();

        selsWithdraw = _singleSelector(IWithdraw.withdrawUsdc.selector);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                   GARDEN SETUP HELPERS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Register the WITHDRAW_MODULE in the registry and add the withdraw facet
    function _registerWithdrawModule() internal {
        _registerModule(WITHDRAW_MODULE);
        _addFacetToModule(WITHDRAW_MODULE, address(withdrawFacet), selsWithdraw);
    }

    /// @notice Deploy a garden with withdraw module enabled
    /// @param gardenOwner_ The owner of the garden
    /// @return garden The deployed garden address
    function _deployGardenWithWithdraw(address gardenOwner_) internal returns (address garden) {
        _registerWithdrawModule();

        bytes32[] memory modules = new bytes32[](1);
        modules[0] = WITHDRAW_MODULE;
        _addGardenType(GARDEN_TYPE_1, modules);

        garden = _deployGarden(GARDEN_TYPE_1, gardenOwner_);
        _performUpgrade(garden, gardenOwner_);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                   TOKEN HELPERS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Mint tokens to a garden (or any address)
    function _fundWithUsdc(address to, uint256 amount) internal {
        usdc.mint(to, amount);
    }

    /// @notice Mint WETH to an address
    function _fundWithWeth(address to, uint256 amount) internal {
        weth.mint(to, amount);
    }

    /// @notice Mint WBTC to an address
    function _fundWithWbtc(address to, uint256 amount) internal {
        wbtc.mint(to, amount);
    }

    // ═══════════════════════════════════════════════════════════════════
    //                   POOL REGISTRATION HELPERS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Register a pool in the LiquidityPoolRegistry
    function _registerPool(
        address poolAddress,
        address tokenA,
        address tokenB,
        bytes32 dexId,
        string memory pairName,
        uint24 swapFee
    )
        internal
    {
        poolRegistry.addPool(
            ILiquidityPoolRegistry.AddPoolParams({
                poolAddress: poolAddress,
                tokenA: tokenA,
                tokenB: tokenB,
                dexId: dexId,
                pairName: pairName,
                swapFee: swapFee
            })
        );
    }
}
