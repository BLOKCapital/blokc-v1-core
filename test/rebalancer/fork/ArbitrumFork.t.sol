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
    bool internal forkActive;

    Rebalancer internal rebalancer;
    MockIndex internal mockIndex;

    address internal garden1 = makeAddr("garden1");
    address internal garden2 = makeAddr("garden2");
    address internal keeper = makeAddr("keeper");

    modifier skipIfNoFork() {
        if (!forkActive) return;
        _;
    }

    // ========================================================================
    // Setup
    // ========================================================================

    function setUp() public {
        // Fork Arbitrum One. Requires ARBITRUM_RPC_URL to be set.
        // Run with: ARBITRUM_RPC_URL=<url> forge test --match-contract ArbitrumForkTest -vvv
        string memory rpcUrl = vm.envOr("ARBITRUM_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) {
            forkActive = false;
            return;
        }
        forkActive = true;
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
            bytes4(keccak256("swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256,uint256,address[],address,address,uint256)")),
            Rebalancer.DexType.V2_CONSTANT_PRODUCT
        );
        rebalancer.setDexConfig(
            DEX_UNISWAP_V3, UNISWAP_V3_ROUTER, dexFacet,
            bytes4(keccak256("exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))")),
            Rebalancer.DexType.V3_CONCENTRATED
        );
        rebalancer.setDexConfig(
            keccak256("CAMELOT_V3"), CAMELOT_V3_ROUTER, dexFacet,
            bytes4(keccak256("exactInputSingle((address,address,address,uint256,uint256,uint256,uint160))")),
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

    function test_fork_cumulativeRebalanceExecutesSwap() public skipIfNoFork {
        uint256 wethBefore = IERC20(WETH).balanceOf(garden1) + IERC20(WETH).balanceOf(garden2);
        uint256 wbtcBefore = IERC20(WBTC).balanceOf(garden1) + IERC20(WBTC).balanceOf(garden2);

        rebalancer.cumulativeRebalance(keccak256("BLOKC2"), block.timestamp + 300);

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

    function test_fork_gardensBalanceToTarget() public skipIfNoFork {
        rebalancer.cumulativeRebalance(keccak256("BLOKC2"), block.timestamp + 300);

        _assertBalanced(garden1, "garden1");
        _assertBalanced(garden2, "garden2");
    }

    function test_fork_valueIsPreserved() public skipIfNoFork {
        uint256 garden1WethBefore = IERC20(WETH).balanceOf(garden1);
        uint256 garden1WbtcBefore = IERC20(WBTC).balanceOf(garden1);
        uint256 garden2WethBefore = IERC20(WETH).balanceOf(garden2);
        uint256 garden2WbtcBefore = IERC20(WBTC).balanceOf(garden2);

        rebalancer.cumulativeRebalance(keccak256("BLOKC2"), block.timestamp + 300);

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

// =============================================================================
// Scale Test: 50 gardens on BLOKC10
// =============================================================================

contract ArbitrumForkScaleTest is Test {
    address internal constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address internal constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    address internal constant POOL_REGISTRY = 0xA3178280c191dD46c551b91c651F337E47594d85;
    address internal constant FACET_REGISTRY = 0xcD06FE7cdCacAed1806E2c29E411d4bD05A51Ef3;
    address internal constant DEX_FACET = 0x06eb18FC187Ec0Bf4687e6783DC8cDcB2AD8F97B;
    address internal constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address internal constant CAMELOT_V2_ROUTER = 0xc873fEcbd354f5A56E00E710B90EF4201db2448d;

    // BLOKC10 tokens (Arbitrum One)
    bytes32 internal constant BTC = bytes32("BTC");
    bytes32 internal constant ETH = bytes32("ETH");
    bytes32 internal constant LINK = bytes32("LINK");
    bytes32 internal constant UNI = bytes32("UNI");
    bytes32 internal constant ARB = bytes32("ARB");
    bytes32 internal constant AAVE = bytes32("AAVE");
    bytes32 internal constant GMX = bytes32("GMX");
    bytes32 internal constant PENDLE = bytes32("PENDLE");
    bytes32 internal constant GRT = bytes32("GRT");
    bytes32 internal constant CRV = bytes32("CRV");

    uint256 internal constant GARDEN_COUNT = 50;
    uint256 internal constant TOKEN_COUNT = 10;

    bool internal forkActive;

    modifier skipIfNoFork() {
        if (!forkActive) return;
        _;
    }

    function setUp() public {
        string memory rpcUrl = vm.envOr("ARBITRUM_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) {
            forkActive = false;
            return;
        }
        forkActive = true;
        vm.createSelectFork(rpcUrl);
    }

    function test_scale_50gardens_blokc10() public skipIfNoFork {
        // -- Build token arrays --
        bytes32[] memory symbols = new bytes32[](TOKEN_COUNT);
        symbols[0] = BTC;
        symbols[1] = ETH;
        symbols[2] = LINK;
        symbols[3] = UNI;
        symbols[4] = ARB;
        symbols[5] = AAVE;
        symbols[6] = GMX;
        symbols[7] = PENDLE;
        symbols[8] = GRT;
        symbols[9] = CRV;

        address[] memory tokens = new address[](TOKEN_COUNT);
        tokens[0] = WBTC;
        tokens[1] = WETH;
        tokens[2] = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4; // LINK
        tokens[3] = 0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0; // UNI
        tokens[4] = 0x912CE59144191C1204E64559FE8253a0e49E6548; // ARB
        tokens[5] = 0xba5DdD1f9d7F570dc94a51479a000E3BCE967196; // AAVE
        tokens[6] = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a; // GMX
        tokens[7] = 0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8; // PENDLE
        tokens[8] = 0x9623063377AD1B27544C965cCd7342f7EA7e88C7; // GRT
        tokens[9] = 0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978; // CRV

        uint256[] memory prices = new uint256[](TOKEN_COUNT);
        prices[0] = 60000e8;
        prices[1] = 3000e8;
        prices[2] = 15e8;
        prices[3] = 8e8;
        prices[4] = 1e8;
        prices[5] = 150e8;
        prices[6] = 25e8;
        prices[7] = 5e8;
        prices[8] = 0.15e8;
        prices[9] = 0.5e8;

        uint256[] memory weights = new uint256[](TOKEN_COUNT);
        for (uint256 i = 0; i < TOKEN_COUNT; i++) {
            weights[i] = 0.1e18; // 10% each
        }

        // -- Build garden array --
        address[] memory gardens = new address[](GARDEN_COUNT);
        for (uint256 i = 0; i < GARDEN_COUNT; i++) {
            gardens[i] = makeAddr(string(abi.encodePacked("garden", i)));
        }

        // -- Deploy mocks --
        MockComponentRegistry mockComp = new MockComponentRegistry();
        for (uint256 i = 0; i < TOKEN_COUNT; i++) {
            mockComp.setComponent(symbols[i], tokens[i]);
            mockComp.setPrice(tokens[i], prices[i]);
        }
        mockComp.setComponent(bytes32("USDC"), USDC);
        mockComp.setPrice(USDC, 1e8);
        mockComp.setRegistered(bytes32("USDC"), true);

        MockIndex mockIndex = new MockIndex();
        mockIndex.setWeights(symbols, weights);
        mockIndex.setGardens(gardens);

        MockIndexFactory mockFactory = new MockIndexFactory();
        mockFactory.setRegistered(address(mockIndex), true);

        // -- Deploy Rebalancer --
        Rebalancer rebalancer = new Rebalancer(
            address(this), address(mockFactory), address(mockComp),
            POOL_REGISTRY, FACET_REGISTRY, USDC
        );
        rebalancer.setDexConfig(
            keccak256("CAMELOT_V2"), CAMELOT_V2_ROUTER, DEX_FACET,
            bytes4(keccak256("swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256,uint256,address[],address,address,uint256)")),
            Rebalancer.DexType.V2_CONSTANT_PRODUCT
        );
        rebalancer.setDexConfig(
            keccak256("UNISWAP_V3"), UNISWAP_V3_ROUTER, DEX_FACET,
            bytes4(keccak256("exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))")),
            Rebalancer.DexType.V3_CONCENTRATED
        );
        rebalancer.addIndexToType(keccak256("BLOKC10"), address(mockIndex));

        // -- Fund gardens (small amounts of ETH + BTC only; rest zero for gas efficiency) --
        // Each garden: 0.01 ETH ($30) + 0.0005 BTC ($30) = $60, 10% each token
        // Only fund ETH and BTC — price lookups still happen for all 10 tokens
        for (uint256 i = 0; i < GARDEN_COUNT; i++) {
            deal(WETH, gardens[i], 0.01e18);
            deal(WBTC, gardens[i], 0.0005e8);

            vm.prank(gardens[i]);
            IERC20(WETH).approve(address(rebalancer), type(uint256).max);
            vm.prank(gardens[i]);
            IERC20(WBTC).approve(address(rebalancer), type(uint256).max);
            vm.prank(gardens[i]);
            IERC20(USDC).approve(address(rebalancer), type(uint256).max);
        }

        // -- Warp past cooldown --
        vm.warp(block.timestamp + 24 hours + 1);

        // -- Execute --
        uint256 gasBefore = gasleft();
        rebalancer.cumulativeRebalance(keccak256("BLOKC10"), block.timestamp + 300);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("Gas used for %d gardens x %d tokens:", GARDEN_COUNT, TOKEN_COUNT);
        console2.log("  Total gas: %d", gasUsed);
        console2.log("  Gas per garden: %d", gasUsed / GARDEN_COUNT);

        // -- Verify --
        assertEq(rebalancer.lastRebalanceTimestamp(keccak256("BLOKC10")), block.timestamp);
        uint256 dust = IERC20(WETH).balanceOf(address(rebalancer))
            + IERC20(WBTC).balanceOf(address(rebalancer));
        assertLe(dust, GARDEN_COUNT * 1e12, "Excessive dust");

        // Each garden should have received tokens back
        for (uint256 i = 0; i < GARDEN_COUNT; i++) {
            uint256 wethBal = IERC20(WETH).balanceOf(gardens[i]);
            uint256 wbtcBal = IERC20(WBTC).balanceOf(gardens[i]);
            assertGt(wethBal + wbtcBal, 0, "Garden should have tokens");
        }
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

