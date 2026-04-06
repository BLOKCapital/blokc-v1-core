// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { BaseTest } from "../base/BaseTest.sol";
import { LiquidityPoolRegistry } from "src/liquidityPoolRegistry/LiquidityPoolRegistry.sol";
import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";

// ═══════════════════════════════════════════════════════════════════════
//                     MOCK POOL CONTRACTS
// ═══════════════════════════════════════════════════════════════════════
// addPool requires poolAddress.code.length > 0, so we need contracts.

contract MockPool {
    uint256 private _id;

    constructor(uint256 id_) {
        _id = id_;
    }
}

/// @title PoolRegistryTestBase
/// @notice Shared setup for LiquidityPoolRegistry tests.
///         Deploys the registry (owned by `owner`), pre-deploys mock pool contracts,
///         and provides helpers for adding / removing pools with minimal boilerplate.
abstract contract PoolRegistryTestBase is BaseTest {
    LiquidityPoolRegistry public registry;

    // ── DEX identifiers ──────────────────────────────────────────────
    bytes32 public constant DEX_UNISWAP_V3 = keccak256("UNISWAP_V3");
    bytes32 public constant DEX_UNISWAP_V2 = keccak256("UNISWAP_V2");
    bytes32 public constant DEX_CAMELOT_V3 = keccak256("CAMELOT_V3");

    // ── Token addresses (deterministic, non-zero, distinct) ─────────
    address public tokenA = address(0xAAAA);
    address public tokenB = address(0xBBBB);
    address public tokenC = address(0xCCCC);
    address public tokenD = address(0xDDDD);

    // ── Pre-deployed mock pool contracts ─────────────────────────────
    address public pool1;
    address public pool2;
    address public pool3;
    address public pool4;
    address public pool5;

    // ── Default selectors for test DEXes ─────────────────────────────
    bytes4 public constant SWAP_SELECTOR_V3 =
        bytes4(keccak256("uniswapV3Swap((uint256,uint256,address[],address[],bool))"));
    bytes4 public constant QUOTE_SELECTOR_V3 =
        bytes4(keccak256("quoteExactInputForPool(address,address,uint256,address,uint32)"));
    bytes4 public constant SWAP_SELECTOR_V2 =
        bytes4(keccak256("uniswapV2Swap((uint256,uint256,address[],address[],bool))"));
    bytes4 public constant QUOTE_SELECTOR_V2 =
        bytes4(keccak256("quoteExactInputForPool(address,address,uint256,address)"));
    bytes4 public constant SWAP_SELECTOR_CAMELOT =
        bytes4(keccak256("camelotV3Swap((uint256,uint256,address[],address[],bool))"));
    bytes4 public constant QUOTE_SELECTOR_CAMELOT =
        bytes4(keccak256("quoteExactInputForPool(address,address,uint256,address,uint32)"));

    function setUp() public virtual override {
        super.setUp();

        registry = new LiquidityPoolRegistry(owner);

        // Register DEXes before pools can be added
        vm.startPrank(owner);
        registry.registerDex(DEX_UNISWAP_V3, SWAP_SELECTOR_V3, QUOTE_SELECTOR_V3);
        registry.registerDex(DEX_UNISWAP_V2, SWAP_SELECTOR_V2, QUOTE_SELECTOR_V2);
        registry.registerDex(DEX_CAMELOT_V3, SWAP_SELECTOR_CAMELOT, QUOTE_SELECTOR_CAMELOT);
        vm.stopPrank();

        // Deploy 5 mock pool contracts (they need code for the addPool check)
        pool1 = address(new MockPool(1));
        pool2 = address(new MockPool(2));
        pool3 = address(new MockPool(3));
        pool4 = address(new MockPool(4));
        pool5 = address(new MockPool(5));
    }

    // ═══════════════════════════════════════════════════════════════════
    //                         HELPERS
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Build AddPoolParams struct
    function _params(
        address poolAddr,
        address tA,
        address tB,
        bytes32 dexId,
        string memory pairName
    )
        internal
        pure
        returns (ILiquidityPoolRegistry.AddPoolParams memory)
    {
        return ILiquidityPoolRegistry.AddPoolParams({
            poolAddress: poolAddr,
            tokenA: tA,
            tokenB: tB,
            dexId: dexId,
            pairName: pairName
        });
    }

    /// @notice Add a pool as owner
    function _addPool(
        address poolAddr,
        address tA,
        address tB,
        bytes32 dexId,
        string memory pairName
    )
        internal
    {
        vm.prank(owner);
        registry.addPool(_params(poolAddr, tA, tB, dexId, pairName));
    }

    /// @notice Add pool1 with tokenA/tokenB on UNISWAP_V3
    function _addDefaultPool() internal {
        _addPool(pool1, tokenA, tokenB, DEX_UNISWAP_V3, "TOKENA/TOKENB");
    }

    /// @notice Remove a pool as owner
    function _removePool(address poolAddr) internal {
        vm.prank(owner);
        registry.removePool(poolAddr);
    }

    /// @notice Deploy a fresh mock pool contract (for dynamic tests)
    function _deployMockPool(uint256 id) internal returns (address) {
        return address(new MockPool(id));
    }

    /// @notice Compute canonical pair ID (matches contract logic)
    function _computePairId(address tA, address tB) internal pure returns (bytes32) {
        (address t0, address t1) = tA < tB ? (tA, tB) : (tB, tA);
        return keccak256(abi.encode(t0, t1));
    }
}
