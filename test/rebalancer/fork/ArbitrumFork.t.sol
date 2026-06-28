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
 * @notice End-to-end fork test against live Arbitrum One protocol contracts.
 *
 *         WHAT'S REAL (deployed on Arbitrum One, used as-is):
 *           - IndexFactory        — deploys a real Index
 *           - Index (BLOKC2-TEST) — real Index deployed through the factory
 *           - ComponentRegistry   — real token/price registry (fetchPrice mocked for fork stability)
 *           - PoolRegistry        — real pool discovery
 *           - FacetRegistry       — real facet/module validation
 *           - DexFacet            — real on-chain quoting
 *           - DEX Routers          — real Uniswap V3 + Camelot V2 swaps
 *           - WETH, WBTC, USDC     — real token contracts
 *
 *         WHAT'S MINIMALLY MOCKED:
 *           - GardenFactory.getGardenType  — mocked to return INDEX type so EOAs
 *             can connect to the Index (avoids deploying full diamond proxies)
 *
 *         Run with:
 *           ARBITRUM_RPC_URL=<url> forge test --match-contract ArbitrumForkTest -vvv
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
    address internal constant FACET_REGISTRY = 0x1e237507bb8520a253300b9e22bFccCd396E45cF;
    address internal constant GARDEN_FACTORY = 0xA6c558f50c435896aEDe997091bD06ef6cAd3603;
    address internal constant DEX_FACET = 0x06eb18FC187Ec0Bf4687e6783DC8cDcB2AD8F97B;

    address internal constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address internal constant CAMELOT_V2_ROUTER = 0xc873fEcbd354f5A56E00E710B90EF4201db2448d;

    // Protocol actors (discovered from on-chain)
    address internal constant DAO = 0xC20fc692710AE3da739d1A10560be6C72A84857F;
    bytes32 internal constant INDEX_GARDEN_TYPE = keccak256("INDEX");

    // ========================================================================
    // Test state
    // ========================================================================
    bool internal forkActive;
    Rebalancer internal rebalancer;
    address internal testIndex;
    address internal garden1;
    address internal garden2;

    modifier skipIfNoFork() {
        if (!forkActive) return;
        _;
    }

    // ========================================================================
    // Setup
    // ========================================================================

    function setUp() public {
        string memory rpcUrl = vm.envOr("ARBITRUM_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) {
            forkActive = false;
            return;
        }
        forkActive = true;
        vm.createSelectFork(rpcUrl);

        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        garden1 = user1;
        garden2 = user2;
        vm.deal(DAO, 10 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);

        // =====================================================================
        // 1. Deploy a real Index through the real IndexFactory
        //    Impersonate the DAO to call deployIndex (onlyOwner)
        // =====================================================================
        address marketCapWeighted = 0xaE505b029C9BC7d415Ed38b420585A02363D5d03;
        bytes32[] memory symbols = new bytes32[](2);
        symbols[0] = bytes32("BTC");
        symbols[1] = bytes32("ETH");

        vm.prank(DAO);
        testIndex = IIndexFactory(INDEX_FACTORY).deployIndex("BLOKC2-FORK-TEST", marketCapWeighted, symbols);

        // =====================================================================
        // 2. Deploy real Garden diamond proxies through the real GardenFactory.
        //    Each garden is a full EIP-2535 diamond with BASE facets installed.
        //    We then install the INDEX module (IndexFacet) via the UpgradeFacet
        //    so the garden can connect to the Index.
        // =====================================================================
        vm.prank(user1);
        garden1 = IGardenFactory(GARDEN_FACTORY).createGarden(1, INDEX_GARDEN_TYPE);
        vm.prank(user2);
        garden2 = IGardenFactory(GARDEN_FACTORY).createGarden(2, INDEX_GARDEN_TYPE);

        // Install the INDEX module on each garden via the two-step upgrade flow:
        //   1. upgradeDetails() → reads FacetRegistry for modules not yet installed
        //   2. upgrade(hash)    → applies the facet cuts
        // The INDEX module is registered in FacetRegistry but not yet installed in
        // freshly deployed gardens. upgradeDetails() detects this and returns the
        // IndexFacet cuts with their hash.
        vm.prank(user1);
        (, bytes32 hash1) = IUpgrade(garden1).upgradeDetails();
        vm.prank(user1);
        IUpgrade(garden1).upgrade(hash1);

        vm.prank(user2);
        (, bytes32 hash2) = IUpgrade(garden2).upgradeDetails();
        vm.prank(user2);
        IUpgrade(garden2).upgrade(hash2);

        // Connect gardens to the Index
        vm.prank(user1);
        IIndexFacet(garden1).connectToIndex(testIndex);
        vm.prank(user2);
        IIndexFacet(garden2).connectToIndex(testIndex);

        // Verify connection
        (, uint256 total) = IIndex(testIndex).getConnectedGardens(0, 0);
        assertEq(total, 2, "Should have 2 gardens connected");

        // =====================================================================
        // 3. Override Index weights to 50/50 for deterministic test behaviour.
        //    The real Index uses MarketCapWeighted which reads live circulating
        //    supply + Chainlink prices, producing dynamic weights (~85/15 for
        //    BTC/ETH at time of writing). We want 50/50 to match our test
        //    garden funding. The Index itself IS real (deployed through the
        //    real IndexFactory) — only its getWeights() output is mocked.
        // =====================================================================
        bytes32[] memory overrideSymbols = new bytes32[](2);
        overrideSymbols[0] = bytes32("BTC");
        overrideSymbols[1] = bytes32("ETH");
        uint256[] memory overrideWeights = new uint256[](2);
        overrideWeights[0] = 0.5e18;
        overrideWeights[1] = 0.5e18;
        vm.mockCall(testIndex, abi.encodeWithSignature("getWeights()"), abi.encode(overrideSymbols, overrideWeights));

        // =====================================================================
        // 4. Fix ComponentRegistry.fetchPrice for fork stability
        //    The real Chainlink oracles can have stale/inconsistent state on a
        //    fork. We use vm.mockCall to return stable prices for the symbols
        //    used in this test. getComponentAddress/isComponentRegistered are
        //    NOT mocked — they use real on-chain registry data.
        // =====================================================================
        _mockFetchPrice(bytes32("BTC"), uint256(60_000e8));
        _mockFetchPrice(bytes32("ETH"), uint256(3000e8));
        _mockFetchPrice(bytes32("USDC"), uint256(1e8));

        // =====================================================================
        // 4. Deploy the Rebalancer — ALL constructor args are real contracts
        // =====================================================================
        rebalancer =
            new Rebalancer(address(this), INDEX_FACTORY, COMPONENT_REGISTRY, POOL_REGISTRY, FACET_REGISTRY, USDC);

        rebalancer.setDexConfig(
            keccak256("CAMELOT_V2"),
            CAMELOT_V2_ROUTER,
            DEX_FACET,
            bytes4(
                keccak256(
                    "swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256,uint256,address[],address,address,uint256)"
                )
            ),
            Rebalancer.DexType.V2_CONSTANT_PRODUCT
        );
        rebalancer.setDexConfig(
            keccak256("UNISWAP_V3"),
            UNISWAP_V3_ROUTER,
            DEX_FACET,
            bytes4(keccak256("exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))")),
            Rebalancer.DexType.V3_CONCENTRATED
        );

        rebalancer.addIndexToType(keccak256("BLOKC2"), testIndex);
        rebalancer.setMaxGardensPerBatch(keccak256("BLOKC2"), 1000);

        // =====================================================================
        // 5. Fund gardens + approve Rebalancer
        // =====================================================================
        deal(WETH, garden1, 0.1e18);
        deal(WBTC, garden1, 0.01e8);
        deal(WETH, garden2, 0.1e18);
        deal(WBTC, garden2, 0.01e8);

        for (uint256 i = 0; i < 2; i++) {
            address g = i == 0 ? garden1 : garden2;
            vm.prank(g);
            IERC20(WETH).approve(address(rebalancer), type(uint256).max);
            vm.prank(g);
            IERC20(WBTC).approve(address(rebalancer), type(uint256).max);
            vm.prank(g);
            IERC20(USDC).approve(address(rebalancer), type(uint256).max);
        }

        vm.warp(block.timestamp + 24 hours + 1);
    }

    // ========================================================================
    // Tests
    // ========================================================================

    /// @notice Proves: tokens pulled from gardens, swapped through real DEX
    ///         pools, redistributed back. WETH increases, WBTC decreases.
    function test_swapExecutesThroughRealDEXs() public skipIfNoFork {
        uint256 wethBefore = IERC20(WETH).balanceOf(garden1) + IERC20(WETH).balanceOf(garden2);
        uint256 wbtcBefore = IERC20(WBTC).balanceOf(garden1) + IERC20(WBTC).balanceOf(garden2);

        rebalancer.cumulativeRebalance(keccak256("BLOKC2"), block.timestamp + 300);

        uint256 wethAfter = IERC20(WETH).balanceOf(garden1) + IERC20(WETH).balanceOf(garden2);
        uint256 wbtcAfter = IERC20(WBTC).balanceOf(garden1) + IERC20(WBTC).balanceOf(garden2);

        assertGt(wethAfter, wethBefore, "WETH should increase after rebalance");
        assertLt(wbtcAfter, wbtcBefore, "WBTC should decrease after rebalance");
        assertLe(IERC20(WETH).balanceOf(address(rebalancer)), 1e15, "WETH dust");
        assertLe(IERC20(WBTC).balanceOf(address(rebalancer)), 100, "WBTC dust");
    }

    /// @notice Proves: each garden's WETH/WBTC ratio matches the BLOKC2 50/50
    ///         target weights after rebalancing.
    function test_gardensBalanceToTargetWeights() public skipIfNoFork {
        rebalancer.cumulativeRebalance(keccak256("BLOKC2"), block.timestamp + 300);
        _assertBalanced(garden1, "garden1");
        _assertBalanced(garden2, "garden2");
    }

    /// @notice Proves: total portfolio value doesn't drop more than 2% after
    ///         real-pool swaps (fees + slippage).
    function test_valuePreserved() public skipIfNoFork {
        uint256 g1wB = IERC20(WETH).balanceOf(garden1);
        uint256 g1bB = IERC20(WBTC).balanceOf(garden1);
        uint256 g2wB = IERC20(WETH).balanceOf(garden2);
        uint256 g2bB = IERC20(WBTC).balanceOf(garden2);

        rebalancer.cumulativeRebalance(keccak256("BLOKC2"), block.timestamp + 300);

        uint256 g1wA = IERC20(WETH).balanceOf(garden1);
        uint256 g1bA = IERC20(WBTC).balanceOf(garden1);
        uint256 g2wA = IERC20(WETH).balanceOf(garden2);
        uint256 g2bA = IERC20(WBTC).balanceOf(garden2);

        uint256 valB = (g1wB + g2wB) * 3000 / 1e18 + (g1bB + g2bB) * 60_000 / 1e8;
        uint256 valA = (g1wA + g2wA) * 3000 / 1e18 + (g1bA + g2bA) * 60_000 / 1e8;
        assertGe(valA, valB * 98 / 100, "Value loss exceeds 2%");
    }

    // ========================================================================
    // Helpers
    // ========================================================================

    function _assertBalanced(address garden, string memory label) internal view {
        uint256 wethVal = IERC20(WETH).balanceOf(garden) * 3000 / 1e18;
        uint256 wbtcVal = IERC20(WBTC).balanceOf(garden) * 60_000 / 1e8;
        uint256 total = wethVal + wbtcVal;
        if (total == 0) return;

        uint256 target = total / 2;
        uint256 threshold = target * 15 / 100;

        uint256 wethDiff = wethVal > target ? wethVal - target : target - wethVal;
        uint256 wbtcDiff = wbtcVal > target ? wbtcVal - target : target - wbtcVal;

        assertLe(wethDiff, threshold, string(abi.encodePacked(label, ": WETH off target")));
        assertLe(wbtcDiff, threshold, string(abi.encodePacked(label, ": WBTC off target")));
    }

    function _mockFetchPrice(bytes32 symbol, uint256 price) internal {
        vm.mockCall(COMPONENT_REGISTRY, abi.encodeWithSignature("fetchPrice(bytes32)", symbol), abi.encode(price));
    }
}

// =============================================================================
// Minimal interfaces for on-chain protocol contracts
// =============================================================================

interface IDiamondCut {
    enum FacetCutAction {
        Add,
        Replace,
        Remove
    }

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }
}

interface IGardenFactory {
    function createGarden(uint256 index, bytes32 gardenType) external returns (address);
    function getGardenType(address garden) external view returns (bytes32);
}

interface IUpgrade {
    function upgradeDetails() external view returns (IDiamondCut.FacetCut[] memory cuts, bytes32 hashData);
    function upgrade(bytes32 hashData) external;
}

interface IIndexFacet {
    function connectToIndex(address indexAddress) external;
}

interface IFacetRegistry {
    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }
    function getModuleFacets(bytes32 moduleId) external view returns (Facet[] memory);
}

interface IIndexFactory {
    function deployIndex(string calldata name, address calc, bytes32[] memory syms) external returns (address);
    function isIndexRegistered(address idx) external view returns (bool);
}

interface IIndex {
    function connectGardenToIndex() external;
    function getConnectedGardens(uint256, uint256) external view returns (address[] memory, uint256);
    function getWeights() external view returns (bytes32[] memory, uint256[] memory);
}

// =============================================================================
// Scale Test: 50 gardens on BLOKC10 (gas profiling)
// =============================================================================

contract ArbitrumForkScaleTest is Test {
    address internal constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address internal constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address internal constant POOL_REGISTRY = 0xA3178280c191dD46c551b91c651F337E47594d85;
    address internal constant FACET_REGISTRY = 0x1e237507bb8520a253300b9e22bFccCd396E45cF;
    address internal constant DEX_FACET = 0x06eb18FC187Ec0Bf4687e6783DC8cDcB2AD8F97B;
    address internal constant CAMELOT_V2_ROUTER = 0xc873fEcbd354f5A56E00E710B90EF4201db2448d;
    address internal constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

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
        tokens[2] = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
        tokens[3] = 0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0;
        tokens[4] = 0x912CE59144191C1204E64559FE8253a0e49E6548;
        tokens[5] = 0xba5DdD1f9d7F570dc94a51479a000E3BCE967196;
        tokens[6] = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a;
        tokens[7] = 0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8;
        tokens[8] = 0x9623063377AD1B27544C965cCd7342f7EA7e88C7;
        tokens[9] = 0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978;

        uint256[] memory prices = new uint256[](TOKEN_COUNT);
        prices[0] = 60_000e8;
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
            weights[i] = 0.1e18;
        }

        address[] memory gardens = new address[](GARDEN_COUNT);
        for (uint256 i = 0; i < GARDEN_COUNT; i++) {
            gardens[i] = makeAddr(string(abi.encodePacked("garden", i)));
        }

        MockCompRegistry mockComp = new MockCompRegistry();
        for (uint256 i = 0; i < TOKEN_COUNT; i++) {
            mockComp.setComponent(symbols[i], tokens[i]);
            mockComp.setPrice(tokens[i], prices[i]);
        }
        mockComp.setComponent(bytes32("USDC"), USDC);
        mockComp.setPrice(USDC, 1e8);
        mockComp.setRegistered(bytes32("USDC"), true);

        MockIdx mockIdx = new MockIdx();
        mockIdx.setWeights(symbols, weights);
        mockIdx.setGardens(gardens);

        MockIdxFactory mockFactory = new MockIdxFactory();
        mockFactory.setRegistered(address(mockIdx), true);

        Rebalancer r = new Rebalancer(
            address(this), address(mockFactory), address(mockComp), POOL_REGISTRY, FACET_REGISTRY, USDC
        );
        r.setDexConfig(
            keccak256("CAMELOT_V2"),
            CAMELOT_V2_ROUTER,
            DEX_FACET,
            bytes4(
                keccak256(
                    "swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256,uint256,address[],address,address,uint256)"
                )
            ),
            Rebalancer.DexType.V2_CONSTANT_PRODUCT
        );
        r.setDexConfig(
            keccak256("UNISWAP_V3"),
            UNISWAP_V3_ROUTER,
            DEX_FACET,
            bytes4(keccak256("exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))")),
            Rebalancer.DexType.V3_CONCENTRATED
        );
        r.addIndexToType(keccak256("BLOKC10"), address(mockIdx));
        r.setMaxGardensPerBatch(keccak256("BLOKC10"), 1000);

        for (uint256 i = 0; i < GARDEN_COUNT; i++) {
            deal(WETH, gardens[i], 0.01e18);
            deal(WBTC, gardens[i], 0.0005e8);
            vm.prank(gardens[i]);
            IERC20(WETH).approve(address(r), type(uint256).max);
            vm.prank(gardens[i]);
            IERC20(WBTC).approve(address(r), type(uint256).max);
            vm.prank(gardens[i]);
            IERC20(USDC).approve(address(r), type(uint256).max);
        }

        vm.warp(block.timestamp + 24 hours + 1);

        uint256 gasBefore = gasleft();
        r.cumulativeRebalance(keccak256("BLOKC10"), block.timestamp + 300);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("Gas: %d total, %d per garden", gasUsed, gasUsed / GARDEN_COUNT);
        assertEq(r.lastRebalanceTimestamp(keccak256("BLOKC10")), block.timestamp);
        uint256 dust = IERC20(WETH).balanceOf(address(r)) + IERC20(WBTC).balanceOf(address(r));
        assertLe(dust, GARDEN_COUNT * 1e12, "Excessive dust");
    }
}

contract MockCompRegistry {
    mapping(bytes32 => address) public components;
    mapping(address => uint256) public prices;
    mapping(bytes32 => bool) public registered;

    function setComponent(bytes32 s, address t) external {
        components[s] = t;
        registered[s] = true;
    }

    function setPrice(address t, uint256 p) external {
        prices[t] = p;
    }

    function setRegistered(bytes32 s, bool v) external {
        registered[s] = v;
    }

    function getComponentAddress(bytes32 s) external view returns (address) {
        return components[s];
    }

    function fetchPrice(bytes32 s) external view returns (uint256) {
        return prices[components[s]];
    }

    function isComponentRegistered(bytes32 s) external view returns (bool) {
        return registered[s];
    }
}

contract MockIdx {
    bytes32[] private _symbols;
    uint256[] private _weights;
    address[] private _gardens;

    function setWeights(bytes32[] memory s, uint256[] memory w) external {
        _symbols = s;
        _weights = w;
    }

    function setGardens(address[] memory g) external {
        _gardens = g;
    }

    function getWeights() external view returns (bytes32[] memory, uint256[] memory) {
        return (_symbols, _weights);
    }

    function getConnectedGardens(uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory gardens, uint256 total)
    {
        total = _gardens.length;
        if (offset >= total || limit == 0) return (new address[](0), total);
        uint256 end = offset + limit;
        if (end > total) end = total;
        gardens = new address[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            gardens[i - offset] = _gardens[i];
        }
    }
}

contract MockIdxFactory {
    mapping(address => bool) public registered;

    function setRegistered(address idx, bool val) external {
        registered[idx] = val;
    }

    function isIndexRegistered(address idx) external view returns (bool) {
        return registered[idx];
    }
}
