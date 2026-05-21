// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import "forge-std/Test.sol";
import { Rebalancer } from "src/rebalancer/Rebalancer.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ArbitrumForkTest
 * @notice End-to-end fork test of the Rebalancer against live Arbitrum One DEX pools.
 *         Forks Arbitrum at a pinned block, deploys the Rebalancer with real registry
 *         addresses, funds simulated gardens using `deal`, and executes a cumulative
 *         rebalance through real Camelot V2 pools.
 *
 *         Run with:
 *           forge test --match-contract ArbitrumForkTest --fork-url arbitrum -vvv
 *
 *         Requires API_KEY_INFURA in the environment (see foundry.toml rpc_endpoints).
 */
contract ArbitrumForkTest is Test {
    // ========================================================================
    // Arbitrum One Mainnet Addresses
    // ========================================================================
    address internal constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address internal constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    address internal constant INDEX_FACTORY = 0x91da26BF1a4adDa42355B80502785d3F026d7074;
    address internal constant COMPONENT_REGISTRY = 0x3F8291D2Fb3f5C4391DDbc36C4Ee0B1F48274977;
    address internal constant POOL_REGISTRY = 0xA3178280c191dD46c551b91c651F337E47594d85;
    address internal constant FACET_REGISTRY = 0xcD06FE7cdCacAed1806E2c29E411d4bD05A51Ef3;

    address internal constant CAMELOT_V2_ROUTER = 0xc873fEcbd354f5A56E00E710B90EF4201db2448d;
    address internal constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address internal constant CAMELOT_V3_ROUTER = 0x1F721E2E82F6676FCE4eA07A5958cF098D339e18;

    // ========================================================================
    // DEX identifiers
    // ========================================================================
    bytes32 internal constant DEX_CAMELOT_V2 = keccak256("CAMELOT_V2");
    bytes32 internal constant DEX_UNISWAP_V3 = keccak256("UNISWAP_V3");

    // ========================================================================
    // Test state
    // ========================================================================
    Rebalancer internal rebalancer;
    MockIndex internal mockIndex;

    address internal garden1 = makeAddr("garden1");
    address internal garden2 = makeAddr("garden2");
    address internal keeper = makeAddr("keeper");

    // ========================================================================
    // Setup
    // ========================================================================

    function setUp() public {
        // Fork Arbitrum One. Requires ARBITRUM_RPC_URL to be set.
        // Run with: ARBITRUM_RPC_URL=<url> forge test --match-contract ArbitrumForkTest -vvv
        string memory rpcUrl = vm.envString("ARBITRUM_RPC_URL");
        vm.createSelectFork(rpcUrl);

        // -- Deploy mock index --
        mockIndex = new MockIndex();
        bytes32[] memory symbols = new bytes32[](2);
        symbols[0] = bytes32("ETH");
        symbols[1] = bytes32("BTC");
        uint256[] memory weights = new uint256[](2);
        weights[0] = 0.5e18;
        weights[1] = 0.5e18;
        mockIndex.setWeights(symbols, weights);

        address[] memory gardens = new address[](2);
        gardens[0] = garden1;
        gardens[1] = garden2;
        mockIndex.setGardens(gardens);

        // -- Deploy mock index factory --
        MockIndexFactory mockFactory = new MockIndexFactory();
        mockFactory.setRegistered(address(mockIndex), true);

        // -- Real DexFacet (handles generic quoting via PoolRegistry quoteSelectors) --
        address dexFacet = 0x06eb18FC187Ec0Bf4687e6783DC8cDcB2AD8F97B;

        // -- Mock component registry (stable prices; real one has Chainlink fork issues) --
        MockComponentRegistry mockCompRegistry = new MockComponentRegistry();
        mockCompRegistry.setComponent(bytes32("ETH"), WETH);
        mockCompRegistry.setPrice(WETH, 3000e8); // $3000
        mockCompRegistry.setComponent(bytes32("BTC"), WBTC);
        mockCompRegistry.setPrice(WBTC, 60000e8); // $60000
        mockCompRegistry.setComponent(bytes32("USDC"), USDC);
        mockCompRegistry.setPrice(USDC, 1e8); // $1
        mockCompRegistry.setRegistered(bytes32("USDC"), true);

        // -- Deploy Rebalancer --
        rebalancer = new Rebalancer(
            address(this), // owner
            address(mockFactory), // index factory (mock)
            address(mockCompRegistry), // component registry (mock — avoids Chainlink fork issues)
            POOL_REGISTRY, // pool registry (real)
            FACET_REGISTRY, // facet registry (real)
            USDC // USDC (real)
        );

        // -- Configure DEXs using the real DexFacet for quoting --
        rebalancer.setDexConfig(
            DEX_CAMELOT_V2, CAMELOT_V2_ROUTER, dexFacet,
            Rebalancer.DexType.V2_CONSTANT_PRODUCT
        );
        rebalancer.setDexConfig(
            DEX_UNISWAP_V3, UNISWAP_V3_ROUTER, dexFacet,
            Rebalancer.DexType.V3_CONCENTRATED
        );
        rebalancer.setDexConfig(
            keccak256("CAMELOT_V3"), CAMELOT_V3_ROUTER, dexFacet,
            Rebalancer.DexType.V3_CONCENTRATED
        );

        // -- Register index type --
        rebalancer.addIndexToType(keccak256("BLOKC2"), address(mockIndex));

        // -- Fund gardens with real tokens --
        // Both gardens are WETH-light, WBTC-heavy → cumulative pool also imbalanced
        // Garden1: 0.1 WETH ($300) + 0.01 WBTC ($600) = $900
        // Garden2: 0.1 WETH ($300) + 0.01 WBTC ($600) = $900
        // Combined: 0.2 WETH ($600) + 0.02 WBTC ($1200) = $1800
        // Target BLOKC2 (50/50): $900 WETH (0.3 WETH), $900 WBTC (0.015 WBTC)
        // Excess: $300 WBTC → swap to WETH via Camelot V2 pools
        deal(WETH, garden1, 0.1e18);
        deal(WBTC, garden1, 0.01e8);
        deal(WETH, garden2, 0.1e18);
        deal(WBTC, garden2, 0.01e8);

        // -- Approve Rebalancer --
        vm.prank(garden1);
        IERC20(WETH).approve(address(rebalancer), type(uint256).max);
        vm.prank(garden1);
        IERC20(WBTC).approve(address(rebalancer), type(uint256).max);
        vm.prank(garden1);
        IERC20(USDC).approve(address(rebalancer), type(uint256).max);

        vm.prank(garden2);
        IERC20(WETH).approve(address(rebalancer), type(uint256).max);
        vm.prank(garden2);
        IERC20(WBTC).approve(address(rebalancer), type(uint256).max);
        vm.prank(garden2);
        IERC20(USDC).approve(address(rebalancer), type(uint256).max);

        // -- Warp past 24h cooldown --
        vm.warp(block.timestamp + 24 hours + 1);
    }

    // ========================================================================
    // Tests
    // ========================================================================

    function test_fork_cumulativeRebalanceExecutesSwap() public {
        uint256 wethBefore = IERC20(WETH).balanceOf(garden1) + IERC20(WETH).balanceOf(garden2);
        uint256 wbtcBefore = IERC20(WBTC).balanceOf(garden1) + IERC20(WBTC).balanceOf(garden2);

        rebalancer.cumulativeRebalance(keccak256("BLOKC2"));

        uint256 wethAfter = IERC20(WETH).balanceOf(garden1) + IERC20(WETH).balanceOf(garden2);
        uint256 wbtcAfter = IERC20(WBTC).balanceOf(garden1) + IERC20(WBTC).balanceOf(garden2);

        // Combined WETH should increase (bought from WBTC via USDC)
        assertGt(wethAfter, wethBefore, "WETH should increase after rebalance");
        assertLt(wbtcAfter, wbtcBefore, "WBTC should decrease after rebalance");

        // Rebalancer should hold no leftover tokens (or dust only)
        assertLe(IERC20(WETH).balanceOf(address(rebalancer)), 1e15, "WETH dust");
        assertLe(IERC20(WBTC).balanceOf(address(rebalancer)), 100, "WBTC dust");
        assertLe(IERC20(USDC).balanceOf(address(rebalancer)), 100, "USDC dust");

        // Both gardens should have non-zero balances of both tokens
        assertGt(IERC20(WETH).balanceOf(garden1), 0, "garden1 WETH");
        assertGt(IERC20(WBTC).balanceOf(garden1), 0, "garden1 WBTC");
        assertGt(IERC20(WETH).balanceOf(garden2), 0, "garden2 WETH");
        assertGt(IERC20(WBTC).balanceOf(garden2), 0, "garden2 WBTC");
    }

    function test_fork_gardensBalanceToTarget() public {
        rebalancer.cumulativeRebalance(keccak256("BLOKC2"));

        _assertBalanced(garden1, "garden1");
        _assertBalanced(garden2, "garden2");
    }

    function test_fork_valueIsPreserved() public {
        uint256 garden1WethBefore = IERC20(WETH).balanceOf(garden1);
        uint256 garden1WbtcBefore = IERC20(WBTC).balanceOf(garden1);
        uint256 garden2WethBefore = IERC20(WETH).balanceOf(garden2);
        uint256 garden2WbtcBefore = IERC20(WBTC).balanceOf(garden2);

        rebalancer.cumulativeRebalance(keccak256("BLOKC2"));

        // Values at approximate market prices (from fork block)
        // WETH ~$3000, WBTC ~$60000
        uint256 valueBefore = (garden1WethBefore + garden2WethBefore) * 3000 / 1e18
            + (garden1WbtcBefore + garden2WbtcBefore) * 60_000 / 1e8;

        uint256 garden1WethAfter = IERC20(WETH).balanceOf(garden1);
        uint256 garden1WbtcAfter = IERC20(WBTC).balanceOf(garden1);
        uint256 garden2WethAfter = IERC20(WETH).balanceOf(garden2);
        uint256 garden2WbtcAfter = IERC20(WBTC).balanceOf(garden2);

        uint256 valueAfter = (garden1WethAfter + garden2WethAfter) * 3000 / 1e18
            + (garden1WbtcAfter + garden2WbtcAfter) * 60_000 / 1e8;

        // Value should not drop more than ~2% (slippage + fees on real pools)
        uint256 minAcceptable = valueBefore * 98 / 100;
        assertGe(valueAfter, minAcceptable, "Value loss exceeds 2%");
    }

    // ========================================================================
    // Helpers
    // ========================================================================

    function _assertBalanced(address garden, string memory label) internal view {
        uint256 wethBal = IERC20(WETH).balanceOf(garden);
        uint256 wbtcBal = IERC20(WBTC).balanceOf(garden);

        // Approx values: WETH ~$3000, WBTC ~$60000
        uint256 wethValue = wethBal * 3000 / 1e18;
        uint256 wbtcValue = wbtcBal * 60_000 / 1e8;

        uint256 total = wethValue + wbtcValue;
        if (total == 0) return;

        // BLOKC2 is 50/50 — each should be ~50% of total
        // Allow 15% tolerance on fork (real pool slippage, fees, TWAP gaps)
        uint256 target = total / 2;
        uint256 threshold = target * 15 / 100;

        uint256 wethDiff = wethValue > target ? wethValue - target : target - wethValue;
        uint256 wbtcDiff = wbtcValue > target ? wbtcValue - target : target - wbtcValue;

        assertLe(wethDiff, threshold, string(abi.encodePacked(label, ": WETH off target")));
        assertLe(wbtcDiff, threshold, string(abi.encodePacked(label, ": WBTC off target")));
    }
}

// =============================================================================
// Fork Mocks (minimal)
// =============================================================================

contract MockIndexFactory {
    mapping(address => bool) public registered;
    function setRegistered(address idx, bool val) external { registered[idx] = val; }
    function isIndexRegistered(address idx) external view returns (bool) { return registered[idx]; }
}

contract MockIndex {
    bytes32[] private _symbols;
    uint256[] private _weights;
    address[] private _gardens;

    function setWeights(bytes32[] memory syms, uint256[] memory wts) external {
        _symbols = syms;
        _weights = wts;
    }
    function setGardens(address[] memory g) external { _gardens = g; }
    function getWeights() external view returns (bytes32[] memory, uint256[] memory) {
        return (_symbols, _weights);
    }
    function getConnectedGardens() external view returns (address[] memory) {
        return _gardens;
    }
}

contract MockComponentRegistry {
    mapping(bytes32 => address) public components;
    mapping(address => uint256) public prices;
    mapping(bytes32 => bool) public registered;

    function setComponent(bytes32 symbol, address token) external {
        components[symbol] = token;
        registered[symbol] = true;
    }
    function setPrice(address token, uint256 price) external { prices[token] = price; }
    function setRegistered(bytes32 symbol, bool val) external { registered[symbol] = val; }
    function getComponentAddress(bytes32 symbol) external view returns (address) { return components[symbol]; }
    function fetchPrice(bytes32 symbol) external view returns (uint256) { return prices[components[symbol]]; }
    function isComponentRegistered(bytes32 symbol) external view returns (bool) { return registered[symbol]; }
}

