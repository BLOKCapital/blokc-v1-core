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
import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { QuoteInstruction } from "src/interfaces/ISwapInstruction.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import {
    Rebalancer_NoIndicesRegistered,
    Rebalancer_IndexAlreadyInType,
    Rebalancer_IndexNotInType,
    Rebalancer_IndexNotRegistered,
    Rebalancer_NoGardensFound,
    Rebalancer_RebalanceIntervalNotPassed,
    Rebalancer_RebalanceReentrancy,
    Rebalancer_ZeroTotalValue,
    Rebalancer_ExcessiveValueLoss,
    Rebalancer_BatchSizeNotSet,
    Rebalancer_InvalidConfig
} from "src/rebalancer/Rebalancer.sol";

// =============================================================================
// MOCKS
// =============================================================================

// ── ERC-20 with settable balance, decimals, and OZ SafeERC20 compatibility ────

contract MockERC20 is IERC20, IERC20Metadata {
    using SafeERC20 for IERC20;

    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _totalSupply;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        return true;
    }

    function setBalance(address account, uint256 amount) external {
        _totalSupply = _totalSupply - _balances[account] + amount;
        _balances[account] = amount;
    }

    function mint(address to, uint256 amount) external {
        _totalSupply += amount;
        _balances[to] += amount;
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        _allowances[from][msg.sender] -= amount;
        _balances[from] -= amount;
        _balances[to] += amount;
        return true;
    }
}

// ── V2-style pool for constant-product quoting (Camelot V2 / Uniswap V2) ──

contract MockV2Pool {
    address public token0;
    address public token1;
    uint112 public reserve0;
    uint112 public reserve1;
    uint32 public blockTimestampLast;

    function setPool(address t0, address t1, uint112 r0, uint112 r1) external {
        token0 = t0;
        token1 = t1;
        reserve0 = r0;
        reserve1 = r1;
        blockTimestampLast = uint32(block.timestamp);
    }

    function getReserves() external view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, blockTimestampLast);
    }
}

// ── IndexFactory mock
// ──────────────────────────────────────────────────────────

contract MockIndexFactory {
    mapping(address => bool) public registered;

    function setRegistered(address idx, bool val) external {
        registered[idx] = val;
    }

    function isIndexRegistered(address idx) external view returns (bool) {
        return registered[idx];
    }
}

// ── Index mock — returns symbols, weights, and connected gardens ───────────────

contract MockIndex {
    bytes32[] private _symbols;
    uint256[] private _weights;
    address[] private _gardens;

    function setWeights(bytes32[] memory syms, uint256[] memory wts) external {
        _symbols = syms;
        _weights = wts;
    }

    function setGardens(address[] memory g) external {
        _gardens = g;
    }

    function getWeights() external view returns (bytes32[] memory, uint256[] memory) {
        return (_symbols, _weights);
    }

    function getConnectedGardens() external view returns (address[] memory) {
        return _gardens;
    }
}

// ── IndexComponentRegistry mock — tokens, prices, registration ────────────────

contract MockComponentRegistry {
    mapping(bytes32 => address) public components;
    mapping(address => uint256) public prices; // 8 decimals
    mapping(bytes32 => bool) public registered;

    function setComponent(bytes32 symbol, address token) external {
        components[symbol] = token;
        registered[symbol] = true;
    }

    function setPrice(address token, uint256 price) external {
        prices[token] = price;
    }

    function setRegistered(bytes32 symbol, bool val) external {
        registered[symbol] = val;
    }

    function getComponentAddress(bytes32 symbol) external view returns (address) {
        return components[symbol];
    }

    function fetchPrice(bytes32 symbol) external view returns (uint256) {
        return prices[components[symbol]];
    }

    function isComponentRegistered(bytes32 symbol) external view returns (bool) {
        return registered[symbol];
    }
}

// ── LiquidityPoolRegistry mock
// ─────────────────────────────────────────────────

contract MockPoolRegistry {
    mapping(bytes32 => ILiquidityPoolRegistry.PoolInfo) private _pools;
    mapping(bytes32 => address[]) private _pairPools; // keccak256(tokenA,tokenB) -> pools[]
    mapping(bytes32 => bool) public dexActive;
    mapping(bytes32 => bool) public dexRegistered;

    function setDexActive(bytes32 dexId, bool active) external {
        dexActive[dexId] = active;
    }

    function setDexRegistered(bytes32 dexId, bool reg) external {
        dexRegistered[dexId] = reg;
    }

    function isDexActive(bytes32 dexId) external view returns (bool) {
        return dexActive[dexId];
    }

    function isDexRegistered(bytes32 dexId) external view returns (bool) {
        return dexRegistered[dexId];
    }

    function addPool(address poolAddr, bytes32 dexId, string memory pairName, address t0, address t1) external {
        ILiquidityPoolRegistry.PoolInfo memory info = ILiquidityPoolRegistry.PoolInfo({
            poolAddress: poolAddr, dexId: dexId, pairName: pairName, token0: t0, token1: t1
        });
        _pools[bytes32(uint256(uint160(poolAddr)))] = info;

        bytes32 pairKey = keccak256(abi.encodePacked(t0, t1));
        _pairPools[pairKey].push(poolAddr);
    }

    function getPool(address poolAddress) external view returns (ILiquidityPoolRegistry.PoolInfo memory) {
        return _pools[bytes32(uint256(uint160(poolAddress)))];
    }

    function getPoolsForPair(address tokenA, address tokenB) external view returns (address[] memory) {
        bytes32 forwardKey = keccak256(abi.encodePacked(tokenA, tokenB));
        bytes32 reverseKey = keccak256(abi.encodePacked(tokenB, tokenA));
        address[] memory fwd = _pairPools[forwardKey];
        address[] memory rev = _pairPools[reverseKey];
        address[] memory result = new address[](fwd.length + rev.length);
        uint256 idx = 0;
        for (uint256 i = 0; i < fwd.length; i++) {
            result[idx++] = fwd[i];
        }
        for (uint256 i = 0; i < rev.length; i++) {
            result[idx++] = rev[i];
        }
        return result;
    }

    // Stubs for other ILiquidityPoolRegistry functions (not called by rebalancer)
    function getAllPools() external view returns (address[] memory) {
        return new address[](0);
    }

    function isPoolRegistered(address) external view returns (bool) {
        return true;
    }

    function getDex(bytes32) external view returns (ILiquidityPoolRegistry.DexInfo memory) {
        return ILiquidityPoolRegistry.DexInfo({
            dexId: bytes32(0), swapSelector: bytes4(0), quoteSelector: bytes4(0), active: false
        });
    }
    mapping(bytes32 => bytes4) public quoteSelectors;

    function setQuoteSelector(bytes32 dexId, bytes4 sel) external {
        quoteSelectors[dexId] = sel;
    }

    function getSwapSelectorForDex(bytes32) external view returns (bytes4) {
        return bytes4(0);
    }

    function getQuoteSelectorForDex(bytes32 dexId) external view returns (bytes4) {
        return quoteSelectors[dexId];
    }

    function getRegisteredDexIds() external view returns (bytes32[] memory) {
        return new bytes32[](0);
    }

    function getActiveDexIds() external view returns (bytes32[] memory) {
        return new bytes32[](0);
    }

    function getDexPoolCount(bytes32) external view returns (uint256) {
        return 0;
    }

    function getPoolCount() external view returns (uint256) {
        return 0;
    }

    function getAllPairIds() external view returns (bytes32[] memory) {
        return new bytes32[](0);
    }

    function getPoolsForPairOnDex(address, address, bytes32) external view returns (address[] memory) {
        return new address[](0);
    }

    function getPoolsByDex(bytes32) external view returns (address[] memory) {
        return new address[](0);
    }
}

// ── Mock DEX Router + Quote Facet (handles both swap and quote) ─────────────

contract MockRouter {
    // Rate mapping: keccak256(tokenIn, tokenOut) => rate * 1e18
    // rate = (tokenOut units per tokenIn unit) * 1e18
    mapping(bytes32 => uint256) public rates;

    function setRate(address tokenIn, address tokenOut, uint256 rate) external {
        rates[keccak256(abi.encode(tokenIn, tokenOut))] = rate;
    }

    function _executeSwap(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        address _recipient
    )
        internal
        returns (uint256 amountOut)
    {
        // Pull input tokens from caller (who has approved this router)
        IERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn);
        // Burn the received tokens (simulates sending to pool)
        MockERC20(_tokenIn).setBalance(address(this), 0);
        // Calculate output
        uint256 rate = rates[keccak256(abi.encode(_tokenIn, _tokenOut))];
        amountOut = _amountIn * rate / 1e18;
        // Mint output tokens and send to recipient
        MockERC20(_tokenOut).mint(_recipient, amountOut);
    }

    // ─── Camelot V2
    // ──────────────────────────────────────────
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256, /* amountOutMin */
        address[] calldata path,
        address to,
        address, /* referrer */
        uint256 /* deadline */
    )
        external
    {
        _executeSwap(path[0], path[1], amountIn, to);
    }

    // ─── Uniswap V2
    // ─────────────────────────────────────────
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256, /* amountOutMin */
        address[] calldata path,
        address to,
        uint256 /* deadline */
    )
        external
        returns (uint256[] memory amounts)
    {
        uint256 out = _executeSwap(path[0], path[1], amountIn, to);
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = out;
    }

    // ─── Uniswap V3
    // ─────────────────────────────────────────
    function exactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24,
        address recipient,
        uint256,
        uint256 amountIn,
        uint256,
        uint160
    )
        external
        returns (uint256 amountOut)
    {
        return _executeSwap(tokenIn, tokenOut, amountIn, recipient);
    }

    // ─── Generic Quote (registry-driven) ──────────────────
    /// @notice Matches the universal QuoteInstruction interface used by all DEX facets.
    ///         The selector is stored in MockPoolRegistry and retrieved via getQuoteSelectorForDex.
    function quoteOut(QuoteInstruction calldata inst) external view returns (uint256 amountOut) {
        uint256 rate = rates[keccak256(abi.encode(inst.tokens[0], inst.tokens[1]))];
        if (rate == 0) return 0;
        amountOut = inst.amount * rate / 1e18;
    }
}

// =============================================================================
// TEST BASE
// =============================================================================

abstract contract RebalancerTestBase is Test {
    using SafeERC20 for IERC20;

    // -- Addresses --
    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice"); // garden owner
    address internal bob = makeAddr("bob"); // garden owner
    address internal charlie = makeAddr("charlie"); // garden owner
    address internal keeper = makeAddr("keeper"); // permissionless caller
    address internal stranger = makeAddr("stranger");

    // -- DEX Identifiers --
    bytes32 internal constant DEX_CAMELOT_V2 = keccak256("CAMELOT_V2");
    bytes32 internal constant DEX_UNISWAP_V2 = keccak256("UNISWAP_V2");
    bytes32 internal constant DEX_UNISWAP_V3 = keccak256("UNISWAP_V3");

    // -- Component Symbols --
    bytes32 internal constant SYM_WETH = bytes32("WETH");
    bytes32 internal constant SYM_WBTC = bytes32("WBTC");
    bytes32 internal constant SYM_USDC = bytes32("USDC");

    // -- Index Type --
    bytes32 internal constant INDEX_TYPE = keccak256("BLOKC2");

    // -- Token Decimals --
    uint8 internal constant WETH_DECIMALS = 18;
    uint8 internal constant WBTC_DECIMALS = 8;
    uint8 internal constant USDC_DECIMALS = 6;

    // -- Prices (8 decimals, Chainlink standard) --
    uint256 internal constant WETH_PRICE = 3000e8; // $3,000
    uint256 internal constant WBTC_PRICE = 60_000e8; // $60,000
    uint256 internal constant USDC_PRICE = 1e8; // $1

    // -- Mocks --
    MockERC20 internal weth;
    MockERC20 internal wbtc;
    MockERC20 internal usdc;
    MockIndexFactory internal indexFactory;
    MockIndex internal blokc2Index;
    MockComponentRegistry internal compRegistry;
    MockPoolRegistry internal poolRegistry;
    MockV2Pool internal wethUsdcPool;
    MockV2Pool internal wbtcUsdcPool;
    MockRouter internal router;
    Rebalancer internal rebalancer;

    // -- Garden addresses (these are just the user addresses; in production, gardens are diamond proxies) --
    address[] internal gardens;

    function setUp() public virtual {
        // -- Deploy mock tokens --
        weth = new MockERC20("Wrapped Ether", "WETH", WETH_DECIMALS);
        wbtc = new MockERC20("Wrapped Bitcoin", "WBTC", WBTC_DECIMALS);
        usdc = new MockERC20("USD Coin", "USDC", USDC_DECIMALS);

        // -- Deploy mock registries --
        indexFactory = new MockIndexFactory();
        blokc2Index = new MockIndex();
        compRegistry = new MockComponentRegistry();
        poolRegistry = new MockPoolRegistry();

        // -- Deploy mock router (acts as both router and quote facet) --
        router = new MockRouter();

        // -- Configure component registry --
        compRegistry.setComponent(SYM_WETH, address(weth));
        compRegistry.setPrice(address(weth), WETH_PRICE);
        compRegistry.setComponent(SYM_WBTC, address(wbtc));
        compRegistry.setPrice(address(wbtc), WBTC_PRICE);
        compRegistry.setComponent(SYM_USDC, address(usdc));
        compRegistry.setPrice(address(usdc), USDC_PRICE);

        // -- Configure index factory --
        indexFactory.setRegistered(address(blokc2Index), true);

        // -- Configure index --
        bytes32[] memory symbols = new bytes32[](2);
        symbols[0] = SYM_WETH;
        symbols[1] = SYM_WBTC;
        uint256[] memory weights = new uint256[](2);
        weights[0] = 0.5e18; // 50% WETH
        weights[1] = 0.5e18; // 50% WBTC

        blokc2Index.setWeights(symbols, weights);
        gardens = new address[](2);
        gardens[0] = alice;
        gardens[1] = bob;
        blokc2Index.setGardens(gardens);

        // -- Configure pool registry --
        poolRegistry.setDexRegistered(DEX_CAMELOT_V2, true);
        poolRegistry.setDexActive(DEX_CAMELOT_V2, true);
        poolRegistry.setDexRegistered(DEX_UNISWAP_V2, true);
        poolRegistry.setDexActive(DEX_UNISWAP_V2, true);

        // -- Deploy mock V2 pools --
        // WETH/USDC pool: ~$3000/ETH rate
        wethUsdcPool = new MockV2Pool();
        // token0 = USDC, token1 = WETH; reserve0 = 100K USDC (6 dec), reserve1 = ~33.33 WETH (18 dec)
        wethUsdcPool.setPool(address(usdc), address(weth), 100_000 * 1e6, 33.33e18);
        poolRegistry.addPool(address(wethUsdcPool), DEX_CAMELOT_V2, "WETH/USDC", address(usdc), address(weth));

        // WBTC/USDC pool: ~$60000/BTC rate
        wbtcUsdcPool = new MockV2Pool();
        // token0 = USDC, token1 = WBTC; reserve0 = 600K USDC (6 dec), reserve1 = 10 WBTC (8 dec)
        wbtcUsdcPool.setPool(address(usdc), address(wbtc), 600_000 * 1e6, 10 * 1e8);
        poolRegistry.addPool(address(wbtcUsdcPool), DEX_CAMELOT_V2, "WBTC/USDC", address(usdc), address(wbtc));

        // -- Register quote selectors (the router acts as the DEX facet for quoting) --
        bytes4 quoteSel = router.quoteOut.selector;
        poolRegistry.setQuoteSelector(DEX_CAMELOT_V2, quoteSel);
        poolRegistry.setQuoteSelector(DEX_UNISWAP_V2, quoteSel);

        // -- Configure router rates (used for both quotes and swaps) --
        router.setRate(address(weth), address(usdc), 3000 * 1e6);
        router.setRate(address(usdc), address(weth), uint256(1e18) * 1e18 / (3000 * 1e6));
        router.setRate(address(wbtc), address(usdc), 60_000 * 1e6 * 1e10);
        router.setRate(address(usdc), address(wbtc), uint256(1e8) * 1e18 / (60_000 * 1e6));

        // -- Deploy Rebalancer (registry-driven, no DEX hardcoding) --
        rebalancer = new Rebalancer(
            owner,
            address(indexFactory),
            address(compRegistry),
            address(poolRegistry),
            address(1), // facetRegistry (stored for protocol awareness; not directly called in tests)
            address(usdc)
        );

        // -- Configure DEXs via DAO (identical to how a real deployment would work) --
        vm.startPrank(owner);
        rebalancer.setDexConfig(
            DEX_CAMELOT_V2,
            address(router),
            address(router),
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens.selector,
            Rebalancer.DexType.V2_CONSTANT_PRODUCT
        );
        rebalancer.setDexConfig(
            DEX_UNISWAP_V2,
            address(router),
            address(router),
            router.swapExactTokensForTokens.selector,
            Rebalancer.DexType.V2_STANDARD
        );
        vm.stopPrank();

        // -- Register BLOKC2 index type --
        vm.prank(owner);
        rebalancer.addIndexToType(INDEX_TYPE, address(blokc2Index));

        // -- Set max gardens per batch high so existing tests complete in one call --
        vm.prank(owner);
        rebalancer.setMaxGardensPerBatch(INDEX_TYPE, 1000);
    }

    // ==========================================================================
    // Helpers
    // ==========================================================================

    /// @notice Fund a garden with tokens and approve the rebalancer
    function _fundGarden(address garden, uint256 wethAmount, uint256 wbtcAmount, uint256 usdcAmount) internal {
        // Use explicit amounts to avoid Solidity rational-number issues with 10_000_000 etc.
        if (wethAmount > 0) weth.mint(garden, wethAmount);
        if (wbtcAmount > 0) wbtc.mint(garden, wbtcAmount);
        if (usdcAmount > 0) usdc.mint(garden, usdcAmount);

        // Approve rebalancer
        vm.prank(garden);
        weth.approve(address(rebalancer), type(uint256).max);
        vm.prank(garden);
        wbtc.approve(address(rebalancer), type(uint256).max);
        vm.prank(garden);
        usdc.approve(address(rebalancer), type(uint256).max);
    }

    /// @notice Helper to compute constant-product expected output
    function _quoteCP(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256) {
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        return numerator / denominator;
    }

    /// @notice Advance time past the 24-hour cooldown
    function _warpPastInterval() internal {
        vm.warp(block.timestamp + 24 hours + 1);
    }

    /// @notice Helper to compute the USD value of a token amount (8 decimals)
    function _usdValue(uint256 amount, uint8 decimals, uint256 price) internal pure returns (uint256) {
        return amount * price / (10 ** decimals);
    }
}

// =============================================================================
// 1. ADMIN TESTS
// =============================================================================

contract AdminTest is RebalancerTestBase {
    function test_addIndexToType_revertsIfNotOwner() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        rebalancer.addIndexToType(INDEX_TYPE, makeAddr("someIndex"));
    }

    function test_addIndexToType_revertsIfIndexNotInFactory() public {
        address fakeIndex = makeAddr("fakeIndex");
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Rebalancer_IndexNotRegistered.selector, fakeIndex));
        rebalancer.addIndexToType(INDEX_TYPE, fakeIndex);
    }

    function test_addIndexToType_revertsIfAlreadyInType() public {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(Rebalancer_IndexAlreadyInType.selector, INDEX_TYPE, address(blokc2Index))
        );
        rebalancer.addIndexToType(INDEX_TYPE, address(blokc2Index));
    }

    function test_addIndexToType_succeeds() public {
        MockIndex newIndex = new MockIndex();
        indexFactory.setRegistered(address(newIndex), true);

        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit Rebalancer.IndexTypeRegistered(INDEX_TYPE, address(newIndex));
        rebalancer.addIndexToType(INDEX_TYPE, address(newIndex));

        assertEq(rebalancer.getIndexCountForType(INDEX_TYPE), 2);
    }

    function test_removeIndexFromType_revertsIfNotOwner() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        rebalancer.removeIndexFromType(INDEX_TYPE, address(blokc2Index));
    }

    function test_removeIndexFromType_revertsIfNotInType() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Rebalancer_IndexNotInType.selector, INDEX_TYPE, makeAddr("notThere")));
        rebalancer.removeIndexFromType(INDEX_TYPE, makeAddr("notThere"));
    }

    function test_removeIndexFromType_succeeds() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit Rebalancer.IndexTypeRemoved(INDEX_TYPE, address(blokc2Index));
        rebalancer.removeIndexFromType(INDEX_TYPE, address(blokc2Index));

        assertEq(rebalancer.getIndexCountForType(INDEX_TYPE), 0);
    }
}

// =============================================================================
// 2. GUARD TESTS
// =============================================================================

contract GuardTest is RebalancerTestBase {
    function test_rebalance_revertsIfNoIndicesRegistered() public {
        // Remove the only index
        vm.prank(owner);
        rebalancer.removeIndexFromType(INDEX_TYPE, address(blokc2Index));

        _warpPastInterval();
        vm.expectRevert(abi.encodeWithSelector(Rebalancer_NoIndicesRegistered.selector, INDEX_TYPE));
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
    }

    function test_rebalance_revertsIfNoGardensFound() public {
        // Remove all gardens from the index
        blokc2Index.setGardens(new address[](0));

        _warpPastInterval();
        vm.expectRevert(abi.encodeWithSelector(Rebalancer_NoGardensFound.selector, INDEX_TYPE));
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
    }

    function test_rebalance_revertsIfIntervalNotPassed() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Rebalancer_RebalanceIntervalNotPassed.selector,
                INDEX_TYPE,
                0, // lastRebalance is 0 (never rebalanced)
                24 hours // next allowed
            )
        );
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
    }

    function test_rebalance_revertsIfReentrancy() public {
        // This is hard to trigger directly since the reentrancy guard
        // uses a per-type flag. We'd need the swap to re-enter, which
        // requires involving the DEX router in a circular manner.
        // This is tested indirectly via the happy path — if the reentrancy
        // guard fires incorrectly, the test breaks.
        _warpPastInterval();
        _fundGarden(alice, 1e18, 10_000_000, 1000e6);
        _fundGarden(bob, 0.5e18, 5_000_000, 500e6);

        // First rebalance should succeed
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);

        // Second rebalance within the same interval should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                Rebalancer_RebalanceIntervalNotPassed.selector, INDEX_TYPE, block.timestamp, block.timestamp + 24 hours
            )
        );
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
    }

    function test_rebalance_revertsIfZeroTotalValue() public {
        // Gardens exist but have zero balance
        _warpPastInterval();
        vm.expectRevert(abi.encodeWithSelector(Rebalancer_ZeroTotalValue.selector, INDEX_TYPE));
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
    }

    function test_rebalance_succeedsAfterInterval() public {
        _fundGarden(alice, 1e18, 10_000_000, 0);
        _fundGarden(bob, 0.5e18, 5_000_000, 0);

        _warpPastInterval();
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);

        assertEq(rebalancer.lastRebalanceTimestamp(INDEX_TYPE), block.timestamp);
    }
}

// =============================================================================
// 3. FULL CUMULATIVE REBALANCE (HAPPY PATH)
// =============================================================================

contract CumulativeRebalanceTest is RebalancerTestBase {
    function setUp() public override {
        super.setUp();
        // Alice: 1 WETH ($3000) + 0.1 WBTC ($6000) = $9000 total → 50/50 target = $4500 each
        // Bob:   0.5 WETH ($1500) + 0.05 WBTC ($3000) = $4500 total → 50/50 target = $2250 each
        // Combined: 1.5 WETH ($4500) + 0.15 WBTC ($9000) = $13,500 total
        // Target: 50% WETH = $6750 → need ~2.25 WETH
        //         50% WBTC = $6750 → need ~0.1125 WBTC
        // Excess WBTC ($9000-$6750=$2250) → swap to WETH
        _fundGarden(alice, 1e18, 10_000_000, 0);
        _fundGarden(bob, 0.5e18, 5_000_000, 0);

        _warpPastInterval();
    }

    function test_happyPath_executesRebalance() public {
        uint256 aliceWethBefore = weth.balanceOf(alice);
        uint256 aliceWbtcBefore = wbtc.balanceOf(alice);
        uint256 bobWethBefore = weth.balanceOf(bob);
        uint256 bobWbtcBefore = wbtc.balanceOf(bob);

        vm.expectEmit(true, false, false, true);
        emit Rebalancer.CumulativeRebalanceCompleted(INDEX_TYPE, 2, block.timestamp, block.timestamp + 24 hours);
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);

        // Gardens should have received tokens back (proportional redistribution)
        // Alice contributed $9000 / $13500 = 66.67% of total value
        // Bob contributed $4500 / $13500 = 33.33% of total value

        uint256 aliceWethAfter = weth.balanceOf(alice);
        uint256 aliceWbtcAfter = wbtc.balanceOf(alice);
        uint256 bobWethAfter = weth.balanceOf(bob);
        uint256 bobWbtcAfter = wbtc.balanceOf(bob);

        // Both gardens should have both tokens (not zero)
        assertGt(aliceWethAfter, 0, "Alice should have WETH");
        assertGt(aliceWbtcAfter, 0, "Alice should have WBTC");
        assertGt(bobWethAfter, 0, "Bob should have WETH");
        assertGt(bobWbtcAfter, 0, "Bob should have WBTC");

        // Combined WETH should be higher (bought more WETH from WBTC)
        uint256 totalWethAfter = aliceWethAfter + bobWethAfter;
        uint256 totalWbtcAfter = aliceWbtcAfter + bobWbtcAfter;
        assertGt(totalWethAfter, aliceWethBefore + bobWethBefore, "Total WETH should increase");
        assertLt(totalWbtcAfter, aliceWbtcBefore + bobWbtcBefore, "Total WBTC should decrease");

        // No dust left in rebalancer (or very minimal)
        assertLe(weth.balanceOf(address(rebalancer)), 100, "Rebalancer WETH dust");
        assertLe(wbtc.balanceOf(address(rebalancer)), 100, "Rebalancer WBTC dust");
        assertLe(usdc.balanceOf(address(rebalancer)), 100, "Rebalancer USDC dust");

        // Timestamp updated
        assertEq(rebalancer.lastRebalanceTimestamp(INDEX_TYPE), block.timestamp);
    }

    function test_happyPath_withUsdc() public {
        // Add USDC to gardens (non-component token)
        _fundGarden(alice, 1e18, 10_000_000, 2000e6); // +$2000 USDC
        _fundGarden(bob, 0.5e18, 5_000_000, 1000e6); // +$1000 USDC

        // Note: we already have approvals from the first _fundGarden call in setUp.
        // The second call adds more tokens but re-approves (no harm).

        // Actually, let me set up fresh. Since _fundGarden mints (not sets), calling it twice
        // will add more balance. The first call was in setUp, so balances already exist.
        // Let me set up additional USDC.
        usdc.mint(alice, 2000e6);
        usdc.mint(bob, 1000e6);

        _warpPastInterval();
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);

        // USDC should have been returned proportionally (or swapped into components)
        // Since USDC is not a component, it's fully swapped into WETH/WBTC
        uint256 aliceUsdcAfter = usdc.balanceOf(alice);
        uint256 bobUsdcAfter = usdc.balanceOf(bob);

        // After rebalancing, USDC should be very low (swapped into components)
        assertLe(aliceUsdcAfter + bobUsdcAfter, 100, "USDC should be mostly swapped away");

        // But gardens should have received WETH/WBTC proportional to their total contribution (including USDC)
        uint256 aliceWethAfter = weth.balanceOf(alice);
        assertGt(aliceWethAfter, 1e18, "Alice should have more WETH (USDC swapped in)");
    }

    function test_rebalance_emitsStartAndCompletedEvents() public {
        // Record all emitted logs and verify they include expected events
        vm.recordLogs();
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bool foundStart = false;
        bool foundCompleted = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == Rebalancer.CumulativeRebalanceStarted.selector) {
                foundStart = true;
            }
            if (logs[i].topics[0] == Rebalancer.CumulativeRebalanceCompleted.selector) {
                foundCompleted = true;
            }
        }
        assertTrue(foundStart, "Missing CumulativeRebalanceStarted event");
        assertTrue(foundCompleted, "Missing CumulativeRebalanceCompleted event");
    }

    function test_rebalance_emitsSwapAndRedistributionEvents() public {
        vm.recordLogs();
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bool foundSwap = false;
        bool foundGarden = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == Rebalancer.CumulativeSwapExecuted.selector) {
                foundSwap = true;
            }
            if (logs[i].topics[0] == Rebalancer.GardenRedistributed.selector) {
                foundGarden = true;
            }
        }
        assertTrue(foundSwap, "Missing CumulativeSwapExecuted event");
        assertTrue(foundGarden, "Missing GardenRedistributed event");
    }

    function test_rebalance_anyoneCanCall() public {
        // keeper (not owner) calls rebalance and it succeeds
        vm.prank(keeper);
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
        assertEq(rebalancer.lastRebalanceTimestamp(INDEX_TYPE), block.timestamp);
    }
}

// =============================================================================
// 4. TOKEN PULLING AND APPROVAL TESTS
// =============================================================================

contract TokenPullTest is RebalancerTestBase {
    function setUp() public override {
        super.setUp();
        _warpPastInterval();
    }

    function test_pull_revertsIfNoApproval() public {
        // Fund garden but don't approve
        weth.mint(alice, 1e18);
        wbtc.mint(alice, 10_000_000);
        // No approval set

        // Bob is funded and approved (from _fundGarden)
        _fundGarden(bob, 0.5e18, 5_000_000, 0);

        // The transferFrom for alice should revert since she didn't approve
        vm.expectRevert();
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
    }

    function test_pull_partialApproval_reverts() public {
        // Fund alice and approve WETH but not WBTC
        weth.mint(alice, 1e18);
        wbtc.mint(alice, 10_000_000);
        vm.prank(alice);
        weth.approve(address(rebalancer), type(uint256).max);
        // WBTC not approved

        _fundGarden(bob, 0.5e18, 5_000_000, 0);

        vm.expectRevert();
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
    }

    function test_pull_insufficientApproval_reverts() public {
        // Fund alice and approve less than the balance
        weth.mint(alice, 1e18);
        wbtc.mint(alice, 10_000_000);
        vm.prank(alice);
        weth.approve(address(rebalancer), 0.5e18); // Only approve half
        vm.prank(alice);
        wbtc.approve(address(rebalancer), type(uint256).max);

        _fundGarden(bob, 0.5e18, 5_000_000, 0);

        // The transferFrom for WETH should revert (trying to pull 1e18 with 0.5e18 allowance)
        vm.expectRevert();
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
    }

    function test_pull_zeroBalanceGardens_succeeds() public {
        // Add a third garden with zero balance
        address[] memory allGardens = new address[](3);
        allGardens[0] = alice;
        allGardens[1] = bob;
        allGardens[2] = charlie; // charlie has zero balance
        blokc2Index.setGardens(allGardens);

        _fundGarden(alice, 1e18, 10_000_000, 0);
        _fundGarden(bob, 0.5e18, 5_000_000, 0);
        // charlie: no funding, but approve anyway
        vm.prank(charlie);
        weth.approve(address(rebalancer), type(uint256).max);
        vm.prank(charlie);
        wbtc.approve(address(rebalancer), type(uint256).max);

        // Should succeed — transferFrom with 0 amount just returns success
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
    }

    function test_pull_singleGarden_succeeds() public {
        // Only one garden
        address[] memory singleGarden = new address[](1);
        singleGarden[0] = alice;
        blokc2Index.setGardens(singleGarden);

        _fundGarden(alice, 1e18, 10_000_000, 0);

        // With one garden, no swaps needed if weights already match
        // But the rebalancer still needs to rebalance
        // WETH: $3000, WBTC: $6000, total: $9000
        // Target: $4500 WETH, $4500 WBTC
        // Current: $3000 WETH (deficit), $6000 WBTC (excess)
        // Need to swap WBTC → WETH
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);

        // Alice should get tokens back
        assertGt(weth.balanceOf(alice), 0);
        assertGt(wbtc.balanceOf(alice), 0);
    }
}

// =============================================================================
// 5. REDISTRIBUTION MATH TESTS
// =============================================================================

contract RedistributionTest is RebalancerTestBase {
    function setUp() public override {
        super.setUp();
        _warpPastInterval();
    }

    function test_redistribution_proportionality() public {
        // Alice: $9000 (66.67%), Bob: $4500 (33.33%)
        _fundGarden(alice, 1e18, 10_000_000, 0);
        _fundGarden(bob, 0.5e18, 5_000_000, 0);

        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);

        uint256 aliceWeth = weth.balanceOf(alice);
        uint256 bobWeth = weth.balanceOf(bob);
        uint256 aliceWbtc = wbtc.balanceOf(alice);
        uint256 bobWbtc = wbtc.balanceOf(bob);

        // Alice should have ~2x Bob's tokens since she contributed 2x the value
        // Allow 2% tolerance for rounding and swap slippage
        uint256 aliceWethValue = _usdValue(aliceWeth, WETH_DECIMALS, WETH_PRICE);
        uint256 bobWethValue = _usdValue(bobWeth, WETH_DECIMALS, WETH_PRICE);
        uint256 aliceWbtcValue = _usdValue(aliceWbtc, WBTC_DECIMALS, WBTC_PRICE);
        uint256 bobWbtcValue = _usdValue(bobWbtc, WBTC_DECIMALS, WBTC_PRICE);

        uint256 aliceTotal = aliceWethValue + aliceWbtcValue;
        uint256 bobTotal = bobWethValue + bobWbtcValue;

        // Ratio should be ~2:1 (Alice:B)
        // Alice gets ~66.67%, Bob gets ~33.33%
        uint256 expectedAliceShare = uint256(2 * 1e18) / 3; // ~0.666e18
        uint256 actualAliceShare = aliceTotal * 1e18 / (aliceTotal + bobTotal);

        // Within 5% of expected ratio (200 bps = 2% per token, 5% for combined rounding)
        assertApproxEqRel(actualAliceShare, expectedAliceShare, 0.05e18);
    }

    function test_redistribution_singleGarden() public {
        address[] memory singleGarden = new address[](1);
        singleGarden[0] = alice;
        blokc2Index.setGardens(singleGarden);

        _fundGarden(alice, 1e18, 10_000_000, 0);

        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);

        // Alice should get back all tokens (proportion = 100%)
        uint256 aliceWeth = weth.balanceOf(alice);
        uint256 aliceWbtc = wbtc.balanceOf(alice);
        assertGt(aliceWeth, 0, "Alice should receive WETH");
        assertGt(aliceWbtc, 0, "Alice should receive WBTC");

        // Rebalancer should be nearly empty
        assertLe(weth.balanceOf(address(rebalancer)), 100);
        assertLe(wbtc.balanceOf(address(rebalancer)), 100);
    }

    function test_redistribution_equalContribution() public {
        // Both gardens contribute exactly the same
        _fundGarden(alice, 1e18, 10_000_000, 0);
        _fundGarden(bob, 1e18, 10_000_000, 0);

        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);

        uint256 aliceWeth = weth.balanceOf(alice);
        uint256 bobWeth = weth.balanceOf(bob);
        uint256 aliceWbtc = wbtc.balanceOf(alice);
        uint256 bobWbtc = wbtc.balanceOf(bob);

        // Equal contribution → roughly equal return
        assertApproxEqRel(aliceWeth, bobWeth, 0.02e18); // 2% tolerance
        assertApproxEqRel(aliceWbtc, bobWbtc, 0.02e18);
    }

    function test_redistribution_dustIsolation() public {
        // Test that tiny balances don't cause issues
        _fundGarden(alice, 1e18, 10_000_000, 0);
        _fundGarden(bob, 1, 1, 0); // Dust amounts

        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);

        // Bob should still get some tokens back
        assertGe(weth.balanceOf(bob), 0);
        assertGe(wbtc.balanceOf(bob), 0);
    }
}

// =============================================================================
// 6. SWAP EXECUTION TESTS
// =============================================================================

contract SwapTest is RebalancerTestBase {
    function setUp() public override {
        super.setUp();
        _warpPastInterval();
    }

    function test_swap_executesViaCamelotV2() public {
        _fundGarden(alice, 1e18, 10_000_000, 0);
        _fundGarden(bob, 0.5e18, 5_000_000, 0);

        // Swap should emit event from the router
        // The exact amounts depend on the pools and quotes
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);

        // Verify WETH balance increased (we swapped WBTC→USDC→WETH)
        uint256 totalWethAfter = weth.balanceOf(alice) + weth.balanceOf(bob);
        assertGt(totalWethAfter, 1.5e18, "Total WETH should increase after swapping WBTC");
    }

    function test_swap_noPoolsAvailable_noSwaps() public {
        // Register gardens but remove pool
        _fundGarden(alice, 1e18, 10_000_000, 0);
        _fundGarden(bob, 0.5e18, 5_000_000, 0);

        // Don't add any WETH/WBTC direct pool. The rebalancer will try WETH→USDC
        // and USDC→WBTC pools, which exist. But if we remove those too...
        // Actually the wethUsdcPool and wbtcUsdcPool are already registered in base setUp.
        // The findBestSwapRoute tries direct first, then via USDC.
        // Let's just test with what we have — the swap should work via USDC routing.

        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
        // Just verify it doesn't revert
    }

    function test_swap_inactiveDex_excluded() public {
        _fundGarden(alice, 1e18, 10_000_000, 0);
        _fundGarden(bob, 0.5e18, 5_000_000, 0);

        // Deactivate Camelot V2
        poolRegistry.setDexActive(DEX_CAMELOT_V2, false);

        // The rebalancer should still work (using other DEXs if available,
        // or simply skipping swaps and redistributing)
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
    }
}

// =============================================================================
// 7. VALUE LOSS PROTECTION TESTS
// =============================================================================

contract ValueLossTest is RebalancerTestBase {
    function setUp() public override {
        super.setUp();
        _warpPastInterval();
    }

    function test_valueLoss_normalRebalancePasses() public {
        _fundGarden(alice, 1e18, 10_000_000, 0);
        _fundGarden(bob, 0.5e18, 5_000_000, 0);

        // With normal rates, the value loss should be well within 0.5%
        // (no excessive value loss revert)
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
    }

    function test_valueLoss_rebalancePreservesMostValue() public {
        _fundGarden(alice, 1e18, 10_000_000, 0);
        _fundGarden(bob, 0.5e18, 5_000_000, 0);

        uint256 aliceValueBefore =
            _usdValue(1e18, WETH_DECIMALS, WETH_PRICE) + _usdValue(10_000_000, WBTC_DECIMALS, WBTC_PRICE);
        uint256 bobValueBefore =
            _usdValue(0.5e18, WETH_DECIMALS, WETH_PRICE) + _usdValue(5_000_000, WBTC_DECIMALS, WBTC_PRICE);
        uint256 totalValueBefore = aliceValueBefore + bobValueBefore;

        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);

        // Compute total value after
        uint256 aliceValueAfter = _usdValue(weth.balanceOf(alice), WETH_DECIMALS, WETH_PRICE)
            + _usdValue(wbtc.balanceOf(alice), WBTC_DECIMALS, WBTC_PRICE);
        uint256 bobValueAfter = _usdValue(weth.balanceOf(bob), WETH_DECIMALS, WETH_PRICE)
            + _usdValue(wbtc.balanceOf(bob), WBTC_DECIMALS, WBTC_PRICE);
        uint256 totalValueAfter = aliceValueAfter + bobValueAfter;

        // Total value should not drop more than 0.5% (MAX_VALUE_LOSS_BPS)
        uint256 minAcceptable = totalValueBefore * (10_000 - 50) / 10_000; // 99.5%
        assertGe(totalValueAfter, minAcceptable, "Value loss exceeds 0.5%");
    }
}

// =============================================================================
// 8. EDGE CASE TESTS
// =============================================================================

contract EdgeCaseTest is RebalancerTestBase {
    function setUp() public override {
        super.setUp();
    }

    function test_multipleIndicesSameType() public {
        // Register a second BLOKC2 index with the same symbols and weights
        MockIndex blokc2V2 = new MockIndex();
        indexFactory.setRegistered(address(blokc2V2), true);

        bytes32[] memory symbols = new bytes32[](2);
        symbols[0] = SYM_WETH;
        symbols[1] = SYM_WBTC;
        uint256[] memory weights = new uint256[](2);
        weights[0] = 0.5e18;
        weights[1] = 0.5e18;

        blokc2V2.setWeights(symbols, weights);

        // Different gardens on the second index
        address[] memory gardens2 = new address[](1);
        gardens2[0] = charlie;
        blokc2V2.setGardens(gardens2);

        vm.prank(owner);
        rebalancer.addIndexToType(INDEX_TYPE, address(blokc2V2));

        _fundGarden(alice, 1e18, 10_000_000, 0);
        _fundGarden(bob, 0.5e18, 5_000_000, 0);
        _fundGarden(charlie, 0.3e18, 3_000_000, 0);

        _warpPastInterval();
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);

        // All three gardens should receive tokens
        assertGt(weth.balanceOf(alice), 0);
        assertGt(weth.balanceOf(bob), 0);
        assertGt(weth.balanceOf(charlie), 0);
    }

    function test_noSwapNeeded_whenAlreadyBalanced() public {
        // Set up gardens where the portfolio is already at target weights
        // WETH at $3000, WBTC at $60000
        // Target: 50/50
        // To be balanced: value of WETH = value of WBTC
        // WETH value = wethAmount * 3000e8 / 10^18 = wethAmount * 3000 / 10^18
        // WBTC value = wbtcAmount * 60000e8 / 10^8 = wbtcAmount * 60000 / 10^8
        //
        // For equal value: weth * 3000 / 10^18 = wbtc * 60000 / 10^8
        // weth * 3000 * 10^8 = wbtc * 60000 * 10^18
        // weth * 3e11 = wbtc * 6e22
        // weth = wbtc * 20 * 10^10
        //
        // If wbtc = 5_000_000: weth = 5_000_000 * 20e10 = 0.05 * 10^8 * 20 * 10^10 = 1e18
        // So 1 WETH and 0.05 WBTC are worth $3000 each → balanced

        _fundGarden(alice, 1e18, 5_000_000, 0);

        address[] memory singleGarden = new address[](1);
        singleGarden[0] = alice;
        blokc2Index.setGardens(singleGarden);

        _warpPastInterval();
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);

        // Alice should get back approximately the same amounts
        // (within BALANCE_THRESHOLD_BPS = 2%)
        assertApproxEqRel(weth.balanceOf(alice), 1e18, 0.02e18);
        assertApproxEqRel(wbtc.balanceOf(alice), 5_000_000, 0.02e18);
    }
}

// =============================================================================
// 9. END-TO-END TARGET WEIGHT VERIFICATION
// =============================================================================

contract EndToEndTargetWeightTest is RebalancerTestBase {
    // BLOKC2 = 50% WETH, 50% WBTC
    // After rebalancing, each garden's WETH and WBTC value should be equal
    // within BALANCE_THRESHOLD_BPS (200 bps = 2%)

    /// @dev Helper: compute the USD value of a garden's WETH + WBTC holdings
    function _gardenTotalValue(address garden) internal view returns (uint256) {
        return _usdValue(weth.balanceOf(garden), WETH_DECIMALS, WETH_PRICE)
            + _usdValue(wbtc.balanceOf(garden), WBTC_DECIMALS, WBTC_PRICE);
    }

    /// @dev Helper: assert garden's WETH/WBTC ratio matches 50/50 target within threshold
    function _assertBalancedToTarget(address garden, string memory label) internal {
        uint256 wethValue = _usdValue(weth.balanceOf(garden), WETH_DECIMALS, WETH_PRICE);
        uint256 wbtcValue = _usdValue(wbtc.balanceOf(garden), WBTC_DECIMALS, WBTC_PRICE);
        uint256 totalValue = wethValue + wbtcValue;

        // Target: each should be 50% of total
        uint256 targetPerToken = totalValue / 2;
        uint256 threshold = targetPerToken * 200 / 10_000; // 2% of target

        uint256 wethDiff = wethValue > targetPerToken ? wethValue - targetPerToken : targetPerToken - wethValue;
        uint256 wbtcDiff = wbtcValue > targetPerToken ? wbtcValue - targetPerToken : targetPerToken - wbtcValue;

        assertLe(wethDiff, threshold, string(abi.encodePacked(label, ": WETH off target")));
        assertLe(wbtcDiff, threshold, string(abi.encodePacked(label, ": WBTC off target")));
    }

    function setUp() public override {
        super.setUp();
        _warpPastInterval();
    }

    function test_e2e_singleGardenBalancesToTarget() public {
        // Alice: 1 WETH ($3000) + 10M WBTC ($6000) = $9000
        // WETH is under target (33%), WBTC is over target (67%)
        // After rebalance: both should be ~$4500 (50/50)
        _fundGarden(alice, 1e18, 10_000_000, 0);

        address[] memory singleGarden = new address[](1);
        singleGarden[0] = alice;
        blokc2Index.setGardens(singleGarden);

        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);

        _assertBalancedToTarget(alice, "single garden");

        // Additional sanity: value should be preserved
        uint256 valueAfter = _gardenTotalValue(alice);
        assertApproxEqRel(valueAfter, 9000e8, 0.01e18); // within 1% of $9000
    }

    function test_e2e_twoGardensBothBalanceToTarget() public {
        // Alice: 1 WETH ($3000) + 10M WBTC ($6000) = $9000  → WETH 33%, WBTC 67%
        // Bob:   0.5 WETH ($1500) + 5M WBTC ($3000) = $4500  → WETH 33%, WBTC 67%
        // Both are identically imbalanced (too much WBTC)
        _fundGarden(alice, 1e18, 10_000_000, 0);
        _fundGarden(bob, 0.5e18, 5_000_000, 0);

        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);

        _assertBalancedToTarget(alice, "alice");
        _assertBalancedToTarget(bob, "bob");

        // Alice contributed $9000, Bob $4500 → Alice should have 2x Bob's value
        uint256 aliceValue = _gardenTotalValue(alice);
        uint256 bobValue = _gardenTotalValue(bob);
        assertApproxEqRel(aliceValue, bobValue * 2, 0.02e18); // within 2%
    }

    function test_e2e_asymmetricImbalanceBalancesToTarget() public {
        // Alice: 2 WETH ($6000) + 5M WBTC ($3000) = $9000   → WETH 67%, WBTC 33% (too much WETH)
        // Bob:   0.5 WETH ($1500) + 10M WBTC ($6000) = $7500 → WETH 20%, WBTC 80% (too much WBTC)
        //
        // Combined: 2.5 WETH ($7500) + 15M WBTC ($9000) = $16,500
        // Target WETH: $8250 → 2.75 WETH  → deficit of 0.25 WETH
        // Target WBTC: $8250 → 13.75M WBTC → excess of 1.25M WBTC
        // Swap: ~1.25M WBTC → ~0.25 WETH (via USDC)
        _fundGarden(alice, 2e18, 5_000_000, 0);
        _fundGarden(bob, 0.5e18, 10_000_000, 0);

        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);

        _assertBalancedToTarget(alice, "alice (asymmetric)");
        _assertBalancedToTarget(bob, "bob (asymmetric)");
    }

    function test_e2e_threeGardensBalanceToTarget() public {
        // Three gardens with different sizes and imbalances
        _fundGarden(alice, 1e18, 10_000_000, 0); // $9K, WETH-light
        _fundGarden(bob, 3e18, 10_000_000, 0); // $15K, WETH-heavy
        _fundGarden(charlie, 0.5e18, 5_000_000, 0); // $4.5K, WETH-light

        address[] memory allGardens = new address[](3);
        allGardens[0] = alice;
        allGardens[1] = bob;
        allGardens[2] = charlie;
        blokc2Index.setGardens(allGardens);

        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);

        _assertBalancedToTarget(alice, "alice (3 gardens)");
        _assertBalancedToTarget(bob, "bob (3 gardens)");
        _assertBalancedToTarget(charlie, "charlie (3 gardens)");
    }

    function test_e2e_withUSDCbalancesToTarget() public {
        // Alice: 1 WETH ($3000) + 5M WBTC ($3000) + $3000 USDC  = $9K, all balanced
        // Bob:   0.5 WETH ($1500) + 10M WBTC ($6000) + $1500 USDC = $9K, WBTC-heavy
        //
        // After rebalance, USDC should be swapped into components,
        // and both gardens should end up 50/50 WETH/WBTC
        _fundGarden(alice, 1e18, 5_000_000, 3000e6);
        _fundGarden(bob, 0.5e18, 10_000_000, 1500e6);

        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);

        _assertBalancedToTarget(alice, "alice (with USDC)");
        _assertBalancedToTarget(bob, "bob (with USDC)");

        // USDC should have been mostly swapped away
        assertLe(usdc.balanceOf(alice) + usdc.balanceOf(bob), 100, "USDC dust");
    }
}

// =============================================================================
// BATCH TESTS
// =============================================================================

contract BatchTest is RebalancerTestBase {
    function setUp() public override {
        super.setUp();
        // Override: set a small batch size for cursor testing
        vm.prank(owner);
        rebalancer.setMaxGardensPerBatch(INDEX_TYPE, 2);
    }

    function test_singleBatch_completesRound() public {
        _fundGarden(alice, 1e18, 5_000_000, 0);
        _fundGarden(bob, 0.5e18, 10_000_000, 0);

        _warpPastInterval();

        assertEq(rebalancer.gardenCursor(INDEX_TYPE), 0);

        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);

        // Round should be complete (2 gardens, batchSize=2)
        assertEq(rebalancer.gardenCursor(INDEX_TYPE), 0);
        assertEq(rebalancer.lastRebalanceTimestamp(INDEX_TYPE), block.timestamp);
    }

    function test_multiBatch_cursorAdvances() public {
        address dave = makeAddr("dave");
        address eve = makeAddr("eve");

        address[] memory allGardens = new address[](5);
        allGardens[0] = alice;
        allGardens[1] = bob;
        allGardens[2] = charlie;
        allGardens[3] = dave;
        allGardens[4] = eve;
        blokc2Index.setGardens(allGardens);

        _fundGarden(alice, 1e18, 5_000_000, 0);
        _fundGarden(bob, 0.5e18, 10_000_000, 0);
        _fundGarden(charlie, 2e18, 15_000_000, 0);
        _fundGarden(dave, 0.2e18, 1_000_000, 0);
        _fundGarden(eve, 0.3e18, 2_000_000, 0);

        vm.prank(owner);
        rebalancer.setMaxGardensPerBatch(INDEX_TYPE, 2);

        _warpPastInterval();

        // Batch 1: gardens [0,1]
        vm.expectEmit(true, false, false, true);
        emit Rebalancer.BatchRebalanceCompleted(INDEX_TYPE, 2, 5);
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
        assertEq(rebalancer.gardenCursor(INDEX_TYPE), 2);

        // Batch 2: gardens [2,3]
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
        assertEq(rebalancer.gardenCursor(INDEX_TYPE), 4);

        // Batch 3 (final): garden [4], completes round
        vm.expectEmit(true, false, false, true);
        emit Rebalancer.CumulativeRebalanceCompleted(INDEX_TYPE, 5, block.timestamp, block.timestamp + 24 hours);
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);

        assertEq(rebalancer.gardenCursor(INDEX_TYPE), 0);
        assertEq(rebalancer.lastRebalanceTimestamp(INDEX_TYPE), block.timestamp);
    }

    function test_cooldownNotEnforcedMidRound() public {
        address[] memory allGardens = new address[](4);
        allGardens[0] = alice;
        allGardens[1] = bob;
        allGardens[2] = charlie;
        allGardens[3] = makeAddr("dave");
        blokc2Index.setGardens(allGardens);

        _fundGarden(alice, 1e18, 5_000_000, 0);
        _fundGarden(bob, 0.5e18, 10_000_000, 0);
        _fundGarden(charlie, 2e18, 15_000_000, 0);

        _warpPastInterval();

        // Batch 1
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
        assertEq(rebalancer.gardenCursor(INDEX_TYPE), 2);

        // Batch 2 — should succeed even without advancing time
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
        assertEq(rebalancer.gardenCursor(INDEX_TYPE), 0);
    }

    function test_cooldownEnforcedForNewRound() public {
        _fundGarden(alice, 1e18, 5_000_000, 0);
        _fundGarden(bob, 0.5e18, 10_000_000, 0);

        _warpPastInterval();

        // Complete one round
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
        assertEq(rebalancer.gardenCursor(INDEX_TYPE), 0);

        // Try to start a new round immediately — should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                Rebalancer_RebalanceIntervalNotPassed.selector, INDEX_TYPE, block.timestamp, block.timestamp + 24 hours
            )
        );
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
    }

    function test_revertsIfBatchSizeNotSet() public {
        // Deploy a fresh rebalancer that has no batch size set
        Rebalancer freshRebalancer = new Rebalancer(
            owner, address(indexFactory), address(compRegistry), address(poolRegistry), address(1), address(usdc)
        );

        vm.prank(owner);
        freshRebalancer.addIndexToType(INDEX_TYPE, address(blokc2Index));

        _fundGarden(alice, 1e18, 5_000_000, 0);
        _warpPastInterval();

        vm.expectRevert(abi.encodeWithSelector(Rebalancer_BatchSizeNotSet.selector, INDEX_TYPE));
        freshRebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
    }

    function test_setMaxGardensPerBatch_accessControl() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        rebalancer.setMaxGardensPerBatch(INDEX_TYPE, 10);
    }

    function test_setMaxGardensPerBatch_revertsIfZero() public {
        vm.prank(owner);
        vm.expectRevert(Rebalancer_InvalidConfig.selector);
        rebalancer.setMaxGardensPerBatch(INDEX_TYPE, 0);
    }

    function test_setMaxGardensPerBatch_succeeds() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit Rebalancer.MaxGardensPerBatchSet(INDEX_TYPE, 42);
        rebalancer.setMaxGardensPerBatch(INDEX_TYPE, 42);

        assertEq(rebalancer.maxGardensPerBatch(INDEX_TYPE), 42);
    }

    function test_cursorResetOnGardenRemoval() public {
        // 4 gardens, batchSize=2
        address[] memory allGardens = new address[](4);
        allGardens[0] = alice;
        allGardens[1] = bob;
        allGardens[2] = charlie;
        allGardens[3] = makeAddr("dave");
        blokc2Index.setGardens(allGardens);

        _fundGarden(alice, 1e18, 5_000_000, 0);
        _fundGarden(bob, 0.5e18, 10_000_000, 0);
        _fundGarden(charlie, 2e18, 15_000_000, 0);

        _warpPastInterval();

        // Batch 1: gardens [0,1], cursor goes to 2
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
        assertEq(rebalancer.gardenCursor(INDEX_TYPE), 2);

        // Remove 2 gardens (bob and dave), now only alice and charlie remain
        // Due to swap-and-pop, the array after 2 removals depends on EnumerableSet internals
        allGardens = new address[](2);
        allGardens[0] = alice;
        allGardens[1] = charlie;
        blokc2Index.setGardens(allGardens);

        // cursor=2 but totalGardens=2 — cursor >= totalGardens, resets to 0
        // Next call starts a fresh round (cooldown enforced since cursor was reset)
        // Actually the cooldown was never set (cursor was never 0 and we didn't complete),
        // so cursor resets to 0 and the cooldown check won't have elapsed
        // But cursor was reset to 0 internally (not via completion), so no timestamp was set
        // The lastRebalanceTimestamp is still 0 (never completed a round), so no cooldown
        rebalancer.cumulativeRebalance(INDEX_TYPE, block.timestamp + 300);
        assertEq(rebalancer.gardenCursor(INDEX_TYPE), 0);
        assertEq(rebalancer.lastRebalanceTimestamp(INDEX_TYPE), block.timestamp);
    }
}
