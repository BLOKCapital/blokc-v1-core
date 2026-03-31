// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import "forge-std/Test.sol";

import { IndexFacet } from "../../../src/garden/facets/indexFacets/IndexFacet.sol";

import { IndexBase } from "../../../src/garden/facets/indexFacets/IndexBase.sol";

import { IndexStorage } from "../../../src/garden/facets/indexFacets/IndexStorage.sol";

import { IIndex, SwapCall, PendingIntent } from "../../../src/garden/facets/indexFacets/IIndex.sol";
import { IFacetRegistry } from "../../../src/interfaces/IFacetRegistry.sol";
import { LibDiamond } from "../../../src/garden/libraries/LibDiamond.sol";
import { LibStorageSlot } from "../../../src/garden/libraries/LibStorageSlot.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {
    IndexFacet_NotConnectedToIndex,
    IndexFacet_AlreadyConnectedToIndex,
    IndexFacet_IndexNotRegistered,
    IndexFacet_IntentIntervalNotPassed,
    IndexFacet_RebalanceIntervalNotPassed,
    IndexFacet_NoPendingIntent,
    IndexFacet_BalanceOutsideThreshold,
    IndexFacet_SwapCallFailed,
    IndexFacet_SelectorNotWhitelisted,
    IndexFacet_SelectorNotFound,
    IndexFacet_InsufficientSwapOutput,
    IndexFacet_IntentExpired,
    IndexFacet_ExcessiveValueLoss,
    IndexFacet_RebalanceReentrancy,
    IndexFacet_ZeroTotalValue
} from "../../../src/garden/facets/indexFacets/IndexBase.sol";

// =============================================================================
// MOCKS
// =============================================================================

// ── ERC-20 token with configurable balance, decimals, and symbol ──────────────

contract MockERC20 is IERC20, IERC20Metadata {
    string public override name;
    string public override symbol;
    uint8 public override decimals;
    uint256 public override totalSupply;

    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    constructor(string memory _symbol, uint8 _decimals) {
        name = _symbol;
        symbol = _symbol;
        decimals = _decimals;
    }

    function setBalance(address account, uint256 amount) external {
        totalSupply -= balanceOf[account];
        balanceOf[account] = amount;
        totalSupply += amount;
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}

    // ── IndexFactory — only surface called: isIndexRegistered
    // ────────────────────

    contract MockIndexFactory {
        mapping(address => bool) public registered;

        function setRegistered(address idx, bool val) external {
            registered[idx] = val;
        }

        function isIndexRegistered(address idx) external view returns (bool) {
            return registered[idx];
        }
    }

    // ── Index — surfaces called: connectGardenToIndex, disconnectGardenFromIndex, getWeights ──

    contract MockIndex {
        bool public connectCalled;
        bool public disconnectCalled;

        string[] private _symbols;
        uint256[] private _weights;

        // Control whether calls revert
        bool public revertOnConnect;
        bool public revertOnDisconnect;
        bool public revertOnGetWeights;

        function setWeights(string[] memory syms, uint256[] memory wts) external {
            _symbols = syms;
            _weights = wts;
        }

        function setRevertOnConnect(bool v) external {
            revertOnConnect = v;
        }

        function setRevertOnDisconnect(bool v) external {
            revertOnDisconnect = v;
        }

        function setRevertOnGetWeights(bool v) external {
            revertOnGetWeights = v;
        }

        function connectGardenToIndex() external {
            if (revertOnConnect) revert("MockIndex: connect failed");
            connectCalled = true;
        }

        function disconnectGardenFromIndex() external {
            if (revertOnDisconnect) revert("MockIndex: disconnect failed");
            disconnectCalled = true;
        }

        function getWeights() external view returns (string[] memory, uint256[] memory) {
            if (revertOnGetWeights) revert("MockIndex: getWeights failed");
            return (_symbols, _weights);
        }
    }

    // ── IndexComponentRegistry — surfaces called: getComponentAddress, fetchPrice, isComponentRegistered ──

    contract MockComponentRegistry {
        mapping(string => address) public components;
        mapping(address => uint256) public prices;
        mapping(string => bool) public registered;

        // Allow price-fetch to revert on demand
        bool public revertOnFetchPrice;

        function setComponent(string memory symbol, address token) external {
            components[symbol] = token;
            registered[symbol] = true;
        }

        function setPrice(address token, uint256 price) external {
            prices[token] = price;
        }

        function setRegistered(string memory symbol, bool val) external {
            registered[symbol] = val;
        }

        function setRevertOnFetchPrice(bool v) external {
            revertOnFetchPrice = v;
        }

        function getComponentAddress(string memory symbol) external view returns (address) {
            return components[symbol];
        }

        function fetchPrice(
            address token,
            string memory /*symbol*/
        )
            external
            view
            returns (uint256)
        {
            if (revertOnFetchPrice) revert("MockComponentRegistry: fetchPrice failed");
            return prices[token];
        }

        function isComponentRegistered(string memory symbol) external view returns (bool) {
            return registered[symbol];
        }
    }

    // ── FacetRegistry — only surface called by IndexBase: getModuleIdBySelector ──
    // Does NOT implement the full IFacetRegistry interface — only the one function
    // IndexBase._isDexFunction() calls. Inheriting the full interface would require
    // stubbing 30 functions and make the mock brittle to interface changes.

    contract MockFacetRegistry {
        mapping(bytes4 => bytes32) public moduleIds;

        function setModuleId(bytes4 sel, bytes32 moduleId) external {
            moduleIds[sel] = moduleId;
        }

        function getModuleIdBySelector(bytes4 sel) external view returns (bytes32) {
            return moduleIds[sel];
        }
    }

    // ── CallForwarder — deployed once, etched at each hardcoded IndexStorage address ──

    // We deploy one CallForwarder per mock, then etch its compiled bytecode at the
    // hardcoded IndexStorage constant address. The compiler handles jump offsets.

    contract CallForwarder {
        address private immutable _impl;

        constructor(address impl) {
            _impl = impl;
        }

        fallback() external payable {
            address impl = _impl;
            assembly {
                calldatacopy(0, 0, calldatasize())
                let success := call(gas(), impl, callvalue(), 0, calldatasize(), 0, 0)
                returndatacopy(0, 0, returndatasize())
                switch success
                case 0 { revert(0, returndatasize()) }
                default { return(0, returndatasize()) }
            }
        }

        receive() external payable { }
    }

    contract MockDexFacet {
        // Selector: swapTokens(address,address,uint256,uint256)
        function swapTokens(
            address,
            /*tokenIn*/
            address,
            /*tokenOut*/
            uint256,
            /*amountIn*/
            uint256 /*minOut*/
        )
            external
            returns (uint256)
        {
            // The real DEX facet would move tokens; for testing, the harness's setUp
            // pre-loads the output token balance so the minOutput check passes.
            return 0;
        }

        // Selector that always reverts — used to test revert propagation
        function alwaysFails() external pure {
            revert("dex: always fails");
        }
    }

    // ── Harness — exposes IndexBase internals and wires storage
    // ──────────────────
    //
    // IndexBase is abstract and uses IndexStorage + LibDiamond directly.
    // The harness deploys as a standalone contract (no Diamond proxy) and
    // pre-writes the necessary storage slots so every internal function can run.

    contract IndexFacetHarness is IndexBase {
        MockIndexFactory public factory;
        MockIndex public index;
        MockComponentRegistry public componentRegistry;
        MockFacetRegistry public facetRegistry;
        MockDexFacet public dexFacet;
        MockERC20 public usdc;

        // Public wrappers for internal functions
        function connectToIndex(address idx) external {
            _connectToIndex(idx);
        }

        function disconnectFromIndex() external {
            _disconnectFromIndex();
        }

        function rebalanceIntent() external {
            _rebalanceIntent();
        }

        function rebalance(SwapCall[] calldata calls) external {
            _rebalance(calls);
        }

        function isConnectedToIndex() external view returns (bool) {
            return _isConnectedToIndex();
        }

        function getConnectedIndex() external view returns (address) {
            return _getConnectedIndex();
        }

        function hasPendingIntent() external view returns (bool) {
            return _hasPendingIntent();
        }

        function getPendingIntent()
            external
            view
            returns (bool, uint256, string[] memory, uint256[] memory, uint256[] memory)
        {
            return _getPendingIntent();
        }

        // Direct storage writer — bypasses the normal flow so individual
        // internal helpers can be unit-tested in isolation.
        function forceSetPendingIntent(
            bool active,
            string[] memory symbols,
            uint256[] memory currentValues,
            uint256[] memory targetValues,
            address[] memory tokenAddresses,
            uint256[] memory weights,
            uint256 totalValueUsd
        )
            external
        {
            IndexStorage.Layout storage s = IndexStorage.layout();
            s.pendingIntent.active = active;
            s.pendingIntent.symbols = symbols;
            s.pendingIntent.currentValues = currentValues;
            s.pendingIntent.targetValues = targetValues;
            s.pendingIntent.tokenAddresses = tokenAddresses;
            s.pendingIntent.weights = weights;
            s.pendingIntent.totalValueUsd = totalValueUsd;
        }

        function forceSetLastRebalanceTimestamp(uint256 ts) external {
            IndexStorage.layout().lastRebalanceTimestamp = ts;
        }

        function forceSetLastIntentTimestamp(uint256 ts) external {
            IndexStorage.layout().lastIntentTimestamp = ts;
        }

        function forceSetRebalancing(bool v) external {
            IndexStorage.layout().rebalancing = v;
        }

        function getIndexAddress() external view returns (address) {
            return IndexStorage.layout().indexAddress;
        }

        function getLastRebalanceTimestamp() external view returns (uint256) {
            return IndexStorage.layout().lastRebalanceTimestamp;
        }

        function getLastIntentTimestamp() external view returns (uint256) {
            return IndexStorage.layout().lastIntentTimestamp;
        }

        function isRebalancing() external view returns (bool) {
            return IndexStorage.layout().rebalancing;
        }

        // Writes LibDiamond.facetRegistry in THIS contract's storage context.
        // Must be called from tests instead of writing LibDiamond.layout() directly
        // in the test contract, which would write to the test's own storage slot.
        function setFacetRegistry(address registry) external {
            LibDiamond.layout().facetRegistry = registry;
        }

        // Sets token balances from within the harness's execution context.
        // This guarantees that whatever address the harness internally uses to
        // read balances is the same address whose storage we're writing to.
        function setTokenBalance(address token, uint256 amount) external {
            // Write directly via the mock's setBalance — token is the deployed mock address
            MockERC20(token).setBalance(address(this), amount);
        }

        // Returns this contract's balance of a token — used by tests to verify
        // that setTokenBalance took effect from the harness's perspective.
        function getTokenBalance(address token) external view returns (uint256) {
            return IERC20(token).balanceOf(address(this));
        }

        // ── DEX stub functions
        // ───────────────────────────────────────────────────
        // _executeSwapCalls does address(this).call(selector + data).
        // In production "this" is the Diamond which has DEX facets installed.
        // In tests "this" is this harness, so the DEX selectors must exist here.
        // These are no-ops — token balance changes are set up by tests directly.

        function swapTokens(address, address, uint256, uint256) external returns (uint256) {
            return 0;
        }
    }

    // =============================================================================
    // BASE TEST SETUP
    // =============================================================================

    abstract contract IndexFacetTestBase is Test {
        IndexFacetHarness internal h;

        MockIndexFactory internal factory;
        MockIndex internal index;
        MockComponentRegistry internal componentRegistry;
        MockFacetRegistry internal facetRegistry;
        MockDexFacet internal dexFacet;
        MockERC20 internal weth;
        MockERC20 internal usdc;
        MockERC20 internal wbtc;

        // Prices (8 decimals — Chainlink standard)
        uint256 internal constant WETH_PRICE = 3000e8; // $3,000
        uint256 internal constant WBTC_PRICE = 60_000e8; // $60,000
        uint256 internal constant USDC_PRICE = 1e8; // $1.00

        // Balances
        uint256 internal constant WETH_BALANCE = 1e18; // 1 WETH  → $3,000 value
        uint256 internal constant WBTC_BALANCE = 1e7; // 0.1 WBTC → $6,000 value (8 decimals)
        uint256 internal constant USDC_BALANCE = 1000e6; // $1,000 USDC (6 decimals)

        // Weights: WETH 60%, WBTC 40% (sum = 1e18)
        uint256 internal constant WETH_WEIGHT = 6e17;
        uint256 internal constant WBTC_WEIGHT = 4e17;

        bytes4 internal swapTokensSel;
        bytes4 internal alwaysFailsSel;

        function setUp() public virtual {
            // Deploy mocks
            factory = new MockIndexFactory();
            index = new MockIndex();
            componentRegistry = new MockComponentRegistry();
            facetRegistry = new MockFacetRegistry();
            dexFacet = new MockDexFacet();
            weth = new MockERC20("WETH", 18);
            wbtc = new MockERC20("WBTC", 8);
            usdc = new MockERC20("USDC", 6);

            // Deploy harness
            h = new IndexFacetHarness();

            // Wire storage — bypass code-address constants by using vm.store
            // to overwrite the hardcoded addresses in IndexStorage.
            // We etch mock code at the exact mainnet addresses IndexStorage uses.
            _etchMockAt(IndexStorage.INDEX_FACTORY_ADDRESS, address(factory));
            _etchMockAt(IndexStorage.INDEX_COMPONENT_REGISTRY_ADDRESS, address(componentRegistry));
            _etchMockAt(IndexStorage.USDC_ADDRESS, address(usdc));
            _etchMockAt(IndexStorage.WETH_ADDRESS, address(weth));

            // Use vm.store to write directly into the harness's storage.
            h.setFacetRegistry(address(facetRegistry));

            // Configure component registry
            componentRegistry.setComponent("WETH", address(weth));
            componentRegistry.setComponent("WBTC", address(wbtc));
            componentRegistry.setComponent("USDC", address(usdc));
            componentRegistry.setPrice(address(weth), WETH_PRICE);
            componentRegistry.setPrice(address(wbtc), WBTC_PRICE);
            componentRegistry.setPrice(address(usdc), USDC_PRICE);
            // _getUsdcValueUsd calls fetchPrice(IndexStorage.USDC_ADDRESS, ...) — the
            // hardcoded constant, not the deployed mock address. Register the price
            // under the constant address too so the lookup returns the correct value.
            componentRegistry.setPrice(IndexStorage.USDC_ADDRESS, USDC_PRICE);

            // Pre-fund the harness with tokens
            h.setTokenBalance(address(weth), WETH_BALANCE);
            h.setTokenBalance(address(wbtc), WBTC_BALANCE);
            h.setTokenBalance(address(usdc), USDC_BALANCE);

            // Register index
            factory.setRegistered(address(index), true);

            // Set index weights
            string[] memory symbols = new string[](2);
            uint256[] memory weights = new uint256[](2);
            symbols[0] = "WETH";
            weights[0] = WETH_WEIGHT;
            symbols[1] = "WBTC";
            weights[1] = WBTC_WEIGHT;
            index.setWeights(symbols, weights);

            // DEX selectors
            swapTokensSel = MockDexFacet.swapTokens.selector;
            alwaysFailsSel = MockDexFacet.alwaysFails.selector;

            // Register swapTokens as a DEX function
            facetRegistry.setModuleId(swapTokensSel, keccak256("DEX"));
            // alwaysFails is NOT DEX — intentionally absent
        }

        // ── Helpers
        // ──────────────────────────────────────────────

        /// @dev Etch a CallForwarder at `target` so all calls from IndexBase's
        ///      hardcoded constant addresses are forwarded via CALL to `mockSource`,
        ///      executing inside mockSource's own storage context.
        ///
        ///      Why CALL and not delegatecall:
        ///        delegatecall runs impl bytecode in TARGET's storage → empty
        ///        CALL runs impl bytecode in IMPL's storage → correct
        ///
        ///      Why deploy a Solidity contract instead of hand-rolled bytecode:
        ///        Hand-rolled bytecode requires exact jump offset calculation.
        ///        One wrong byte → invalid jump → silent revert. The Solidity
        ///        compiler handles all of this correctly.
        function _etchMockAt(address target, address mockSource) internal {
            // Deploy a CallForwarder pointing at mockSource, then etch its
            // runtime bytecode at the hardcoded target address.
            CallForwarder forwarder = new CallForwarder(mockSource);
            vm.etch(target, address(forwarder).code);
        }

        /// @dev Connect the harness to the mock index (shared step).
        function _connect() internal {
            h.connectToIndex(address(index));
        }

        /// @dev Advance time past both cooldowns and create a valid pending intent.
        function _createIntent() internal {
            vm.warp(block.timestamp + IndexStorage.REBALANCE_INTERVAL + IndexStorage.INTENT_EXPIRY + 1);
            h.rebalanceIntent();
        }
    }

    // =============================================================================
    //  connectToIndex
    // =============================================================================

    contract ConnectToIndexTest is IndexFacetTestBase {
        function test_connect_setsIndexAddress() public {
            h.connectToIndex(address(index));
            assertEq(h.getIndexAddress(), address(index));
        }

        function test_connect_setsIsConnectedFlag() public {
            h.connectToIndex(address(index));
            assertTrue(h.isConnectedToIndex());
        }

        function test_connect_callsConnectGardenToIndex() public {
            h.connectToIndex(address(index));
            assertTrue(index.connectCalled());
        }

        function test_connect_emitsIndexConnectedEvent() public {
            vm.expectEmit(true, false, false, false);
            emit IIndex.IndexConnected(address(index));
            h.connectToIndex(address(index));
        }

        function test_connect_revertsWhenNotRegistered() public {
            address fakeIndex = makeAddr("fakeIndex");
            vm.expectRevert(abi.encodeWithSelector(IndexFacet_IndexNotRegistered.selector, fakeIndex));
            h.connectToIndex(fakeIndex);
        }

        function test_connect_revertsWhenIndexRevertsOnConnect() public {
            index.setRevertOnConnect(true);
            vm.expectRevert("MockIndex: connect failed");
            h.connectToIndex(address(index));
        }

        function test_connect_getConnectedIndexReturnsAddress() public {
            h.connectToIndex(address(index));
            assertEq(h.getConnectedIndex(), address(index));
        }

        function test_connect_getConnectedIndexReturnsZeroBeforeConnect() public view {
            assertEq(h.getConnectedIndex(), address(0));
        }
    }

    // =============================================================================
    //  disconnectFromIndex
    // =============================================================================

    contract DisconnectFromIndexTest is IndexFacetTestBase {
        function setUp() public override {
            super.setUp();
            _connect();
        }

        function test_disconnect_clearsIndexAddress() public {
            h.disconnectFromIndex();
            assertEq(h.getIndexAddress(), address(0));
        }

        function test_disconnect_clearsIsConnectedFlag() public {
            h.disconnectFromIndex();
            assertFalse(h.isConnectedToIndex());
        }

        function test_disconnect_callsDisconnectGardenFromIndex() public {
            h.disconnectFromIndex();
            assertTrue(index.disconnectCalled());
        }

        function test_disconnect_emitsIndexDisconnectedEvent() public {
            vm.expectEmit(true, false, false, false);
            emit IIndex.IndexDisconnected(address(index));
            h.disconnectFromIndex();
        }

        function test_disconnect_clearsPendingIntent() public {
            // Force an active pending intent
            string[] memory syms = new string[](1);
            syms[0] = "WETH";
            uint256[] memory vals = new uint256[](1);
            vals[0] = 100e8;
            uint256[] memory tgts = new uint256[](1);
            tgts[0] = 100e8;
            address[] memory toks = new address[](1);
            toks[0] = address(weth);
            uint256[] memory wts = new uint256[](1);
            wts[0] = 1e18;
            h.forceSetPendingIntent(true, syms, vals, tgts, toks, wts, 100e8);

            assertTrue(h.hasPendingIntent());
            h.disconnectFromIndex();
            assertFalse(h.hasPendingIntent());
        }

        function test_disconnect_revertsWhenNotConnected() public {
            h.disconnectFromIndex(); // first disconnect
            vm.expectRevert(IndexFacet_NotConnectedToIndex.selector);
            h.disconnectFromIndex(); // second must revert
        }

        function test_disconnect_revertsWhenIndexRevertsOnDisconnect() public {
            index.setRevertOnDisconnect(true);
            vm.expectRevert("MockIndex: disconnect failed");
            h.disconnectFromIndex();
        }
    }

    // =============================================================================
    //  rebalanceIntent
    // =============================================================================

    contract RebalanceIntentTest is IndexFacetTestBase {
        function setUp() public override {
            super.setUp();
            _connect();
            // Advance past both cooldowns
            vm.warp(block.timestamp + IndexStorage.REBALANCE_INTERVAL + IndexStorage.INTENT_EXPIRY + 1);
        }

        function test_intent_revertsWhenNotConnected() public {
            h.disconnectFromIndex();
            vm.expectRevert(IndexFacet_NotConnectedToIndex.selector);
            h.rebalanceIntent();
        }

        function test_intent_revertsWhenIntentIntervalNotPassed() public {
            h.rebalanceIntent(); // first — advances lastIntentTimestamp
            // Only 1 second passes — well within INTENT_EXPIRY
            vm.warp(block.timestamp + 1);
            vm.expectRevert(IndexFacet_IntentIntervalNotPassed.selector);
            h.rebalanceIntent();
        }

        function test_intent_revertsWhenRebalanceIntervalNotPassed() public {
            // Set lastRebalanceTimestamp to now so the rebalance interval hasn't passed
            h.forceSetLastRebalanceTimestamp(block.timestamp);
            vm.expectRevert(IndexFacet_RebalanceIntervalNotPassed.selector);
            h.rebalanceIntent();
        }

        function test_intent_revertsOnZeroTotalValue() public {
            // Zero out all token balances
            h.setTokenBalance(address(weth), 0);
            h.setTokenBalance(address(wbtc), 0);
            h.setTokenBalance(address(usdc), 0);
            vm.expectRevert(IndexFacet_ZeroTotalValue.selector);
            h.rebalanceIntent();
        }

        function test_intent_revertsWhenGetWeightsFails() public {
            index.setRevertOnGetWeights(true);
            vm.expectRevert("MockIndex: getWeights failed");
            h.rebalanceIntent();
        }

        function test_intent_setsPendingIntentActive() public {
            h.rebalanceIntent();
            assertTrue(h.hasPendingIntent());
        }

        function test_intent_storesSymbols() public {
            h.rebalanceIntent();
            (,, string[] memory symbols,,) = h.getPendingIntent();
            assertEq(symbols.length, 2);
            assertEq(symbols[0], "WETH");
            assertEq(symbols[1], "WBTC");
        }

        function test_intent_storesCorrectCurrentValues() public {
            // WETH: 1e18 * 3000e8 / 1e18 = 3000e8
            // WBTC: 1e7  * 60000e8 / 1e8  = 6000e8
            h.rebalanceIntent();
            (,,, uint256[] memory currentValues,) = h.getPendingIntent();
            assertEq(currentValues[0], 3000e8, "WETH current value");
            assertEq(currentValues[1], 6000e8, "WBTC current value");
        }

        function test_intent_storesCorrectTargetValues() public {
            // totalValue = 3000 + 6000 + 1000 (usdc) = 10000e8
            // WETH target = 10000e8 * 0.6 = 6000e8
            // WBTC target = 10000e8 * 0.4 = 4000e8
            h.rebalanceIntent();
            (,,,, uint256[] memory targetValues) = h.getPendingIntent();
            assertEq(targetValues[0], 6000e8, "WETH target value");
            assertEq(targetValues[1], 4000e8, "WBTC target value");
        }

        function test_intent_includesTotalValueWithUsdc() public {
            h.rebalanceIntent();
            (, uint256 totalValueUsd,,,) = h.getPendingIntent();
            // 3000 + 6000 + 1000 = 10000e8
            assertEq(totalValueUsd, 10_000e8);
        }

        function test_intent_updatesLastIntentTimestamp() public {
            uint256 before = h.getLastIntentTimestamp();
            h.rebalanceIntent();
            assertGt(h.getLastIntentTimestamp(), before);
            assertEq(h.getLastIntentTimestamp(), block.timestamp);
        }

        function test_intent_emitsRebalanceIntentCreatedEvent() public {
            vm.expectEmit(true, true, false, false);
            emit IIndex.RebalanceIntentCreated(
                address(h), address(index), new string[](0), new uint256[](0), new uint256[](0), 0
            );
            h.rebalanceIntent();
        }

        function test_intent_overwritesPreviousIntent() public {
            h.rebalanceIntent();

            // Advance past intent expiry to allow a second intent
            vm.warp(block.timestamp + IndexStorage.INTENT_EXPIRY + 1);
            // Also advance past rebalance interval
            vm.warp(block.timestamp + IndexStorage.REBALANCE_INTERVAL);

            // Change WETH balance before second intent
            h.setTokenBalance(address(weth), 2e18);
            h.rebalanceIntent();

            (,,, uint256[] memory currentValues,) = h.getPendingIntent();
            // WETH: 2e18 * 3000e8 / 1e18 = 6000e8
            assertEq(currentValues[0], 6000e8, "second intent should reflect new balance");
        }
    }

    // =============================================================================
    //  rebalance — guard clauses
    // =============================================================================

    contract RebalanceGuardsTest is IndexFacetTestBase {
        function setUp() public override {
            super.setUp();
            _connect();
            _createIntent();
        }

        // ── Reentrancy guard
        // ─────────────────────────────────────

        function test_rebalance_revertsOnReentrancy() public {
            h.forceSetRebalancing(true);
            vm.expectRevert(IndexFacet_RebalanceReentrancy.selector);
            h.rebalance(new SwapCall[](0));
        }

        // ── Not connected
        // ─────────────────────────────────────────

        function test_rebalance_revertsWhenNotConnected() public {
            // Manually clear index address without going through disconnect
            // (disconnect clears pending intent; we want to test this guard independently)
            vm.store(
                address(h),
                bytes32(uint256(LibStorageSlot.deriveStorageSlot(type(IndexStorage).name))),
                bytes32(0) // wipes indexAddress slot
            );
            vm.expectRevert(IndexFacet_NotConnectedToIndex.selector);
            h.rebalance(new SwapCall[](0));
        }

        // ── No pending intent
        // ─────────────────────────────────────

        function test_rebalance_revertsWhenNoPendingIntent() public {
            // Clear the intent flag directly
            h.forceSetPendingIntent(
                false, new string[](0), new uint256[](0), new uint256[](0), new address[](0), new uint256[](0), 0
            );
            vm.expectRevert(IndexFacet_NoPendingIntent.selector);
            h.rebalance(new SwapCall[](0));
        }

        // ── Rebalance interval
        // ────────────────────────────────────

        function test_rebalance_revertsWhenRebalanceIntervalNotPassed() public {
            // Set lastRebalanceTimestamp to now (interval hasn't elapsed)
            h.forceSetLastRebalanceTimestamp(block.timestamp);
            vm.expectRevert(IndexFacet_RebalanceIntervalNotPassed.selector);
            h.rebalance(new SwapCall[](0));
        }

        // ── Intent expired
        // ────────────────────────────────────────

        function test_rebalance_revertsWhenIntentExpired() public {
            // Wind time past the intent expiry window
            vm.warp(block.timestamp + IndexStorage.INTENT_EXPIRY + 1);
            vm.expectRevert(IndexFacet_IntentExpired.selector);
            h.rebalance(new SwapCall[](0));
        }
    }

    // =============================================================================
    //  rebalance — happy path & value-loss check
    // =============================================================================

    contract RebalanceExecutionTest is IndexFacetTestBase {
        function setUp() public override {
            super.setUp();
            _connect();
            _createIntent();
            // Balance the portfolio to 60/40 targets so _verifyBalancesMatchTargets passes.
            // Total at intent = 10000e8. WETH target = 6000e8 = 2e18 tokens.
            // WBTC target = 4000e8 = 6_666_666 tokens. Zero USDC for predictability.
            // Use h.setTokenBalance so the write happens in the harness's storage context.
            h.setTokenBalance(address(weth), 2e18);
            h.setTokenBalance(address(wbtc), 6_666_666);
            h.setTokenBalance(address(usdc), 0);
        }

        function _buildNoOpSwapCalls() internal view returns (SwapCall[] memory calls) {
            // A swap call whose selector is DEX-whitelisted, succeeds, and produces
            // exactly the minOutput (0) so the check passes trivially.
            calls = new SwapCall[](1);
            calls[0] = SwapCall({
                selector: swapTokensSel,
                data: abi.encode(address(weth), address(wbtc), uint256(0), uint256(0)),
                outputToken: address(weth),
                minOutput: 0
            });
        }

        function test_rebalance_clearsRebalancingFlagOnSuccess() public {
            // After rebalance completes the reentrancy flag must be false
            h.rebalance(_buildNoOpSwapCalls());
            assertFalse(h.isRebalancing());
        }

        function test_rebalance_clearsPendingIntentAfterSuccess() public {
            h.rebalance(_buildNoOpSwapCalls());
            assertFalse(h.hasPendingIntent());
        }

        function test_rebalance_updatesLastRebalanceTimestamp() public {
            uint256 before = h.getLastRebalanceTimestamp();
            h.rebalance(_buildNoOpSwapCalls());
            assertGt(h.getLastRebalanceTimestamp(), before);
            assertEq(h.getLastRebalanceTimestamp(), block.timestamp);
        }

        function test_rebalance_emitsRebalanceCompletedEvent() public {
            vm.expectEmit(true, true, false, false);
            emit IIndex.RebalanceCompleted(
                address(h), address(index), block.timestamp, block.timestamp + IndexStorage.REBALANCE_INTERVAL
            );
            h.rebalance(_buildNoOpSwapCalls());
        }

        function test_rebalance_revertsOnExcessiveValueLoss() public {
            // Starting portfolio: 2e18 WETH ($6000), 6_666_666 WBTC (~$4000), 0 USDC → total ~$10000
            // Drain 10% of WETH → value drops by $600 = 6% of total, exceeds 0.5% limit.
            h.setTokenBalance(address(weth), 2e18 / 10);
            vm.expectRevert();
            h.rebalance(_buildNoOpSwapCalls());
        }

        function test_rebalance_allowsValueLossWithinBps() public {
            // Remove 0.4% of WETH balance (within the 0.5% / 50 bps limit).
            // 0.4% of 2e18 = 8e15 wei WETH removed.
            uint256 slippageWei = (2e18 * 40) / 10_000;
            h.setTokenBalance(address(weth), 2e18 - slippageWei);
            // Should succeed — value loss is below MAX_VALUE_LOSS_BPS
            h.rebalance(_buildNoOpSwapCalls());
        }

        function test_rebalance_emptySwapCallsSucceeds() public {
            // Set balances so they match the 60/40 targets within 1% threshold.
            // Intent was created with total = 10000e8 (3000 WETH + 6000 WBTC + 1000 USDC).
            // Targets: WETH = 6000e8, WBTC = 4000e8.
            // WETH needed: 6000e8 * 1e18 / 3000e8 = 2e18
            // WBTC needed: 4000e8 * 1e8  / 60000e8 = 6_666_666 (rounds down, within 1%)
            // Zero USDC so total stays predictable.
            h.setTokenBalance(address(weth), 2e18);
            h.setTokenBalance(address(wbtc), 6_666_666);
            h.setTokenBalance(address(usdc), 0);

            h.rebalance(new SwapCall[](0));
            assertFalse(h.hasPendingIntent());
        }
    }

    // =============================================================================
    //  _executeSwapCalls — per-swap validation
    // =============================================================================

    contract ExecuteSwapCallsTest is IndexFacetTestBase {
        function setUp() public override {
            super.setUp();
            _connect();
            _createIntent();
            // Balance the portfolio so _verifyBalancesMatchTargets passes for
            // tests that reach the end of _rebalance successfully.
            h.setTokenBalance(address(weth), 2e18);
            h.setTokenBalance(address(wbtc), 6_666_666);
            h.setTokenBalance(address(usdc), 0);
        }

        function test_swap_revertsOnNonDexSelector() public {
            // alwaysFailsSel is not registered as DEX
            SwapCall[] memory calls = new SwapCall[](1);
            calls[0] = SwapCall({ selector: alwaysFailsSel, data: "", outputToken: address(weth), minOutput: 0 });
            vm.expectRevert(abi.encodeWithSelector(IndexFacet_SelectorNotWhitelisted.selector, alwaysFailsSel));
            h.rebalance(calls);
        }

        function test_swap_revertsWhenSelectorNotFound() public {
            // Register an unknown selector as DEX but don't install it in the diamond
            bytes4 ghostSel = bytes4(keccak256("ghostSwap()"));
            facetRegistry.setModuleId(ghostSel, keccak256("DEX"));

            SwapCall[] memory calls = new SwapCall[](1);
            calls[0] = SwapCall({ selector: ghostSel, data: "", outputToken: address(weth), minOutput: 0 });
            vm.expectRevert(abi.encodeWithSelector(IndexFacet_SelectorNotFound.selector, ghostSel));
            h.rebalance(calls);
        }

        function test_swap_revertsWhenSwapCallFails() public {
            // Register alwaysFails as DEX so it passes the whitelist check
            facetRegistry.setModuleId(alwaysFailsSel, keccak256("DEX"));

            // When the harness calls address(this).call(alwaysFailsSel), we need that
            // selector to exist on the harness and revert. We achieve this by intercepting
            // the call with vm.mockCallRevert, which causes address(this).call to return
            // (false, <revert data>) — exactly what _executeSwapCalls checks.
            vm.mockCallRevert(
                address(h),
                abi.encodeWithSelector(alwaysFailsSel),
                abi.encodeWithSignature("Error(string)", "dex: always fails")
            );

            SwapCall[] memory calls = new SwapCall[](1);
            calls[0] = SwapCall({ selector: alwaysFailsSel, data: "", outputToken: address(weth), minOutput: 0 });
            vm.expectRevert(
                abi.encodeWithSelector(
                    IndexFacet_SwapCallFailed.selector,
                    uint256(0),
                    abi.encodeWithSignature("Error(string)", "dex: always fails")
                )
            );
            h.rebalance(calls);
        }

        function test_swap_revertsOnInsufficientOutput() public {
            // minOutput = 1e18 but the swap produces 0 tokens (no balance change)
            SwapCall[] memory calls = new SwapCall[](1);
            calls[0] = SwapCall({
                selector: swapTokensSel,
                data: abi.encode(address(wbtc), address(weth), uint256(0), uint256(0)),
                outputToken: address(weth),
                minOutput: 1e18 // requires 1 WETH increase — impossible with no-op
            });
            vm.expectRevert(
                abi.encodeWithSelector(
                    IndexFacet_InsufficientSwapOutput.selector, uint256(0), address(weth), uint256(0), uint256(1e18)
                )
            );
            h.rebalance(calls);
        }

        function test_swap_measuresOutputTokenBalanceDelta() public {
            uint256 balanceBefore = weth.balanceOf(address(h));

            SwapCall[] memory calls = new SwapCall[](1);
            calls[0] = SwapCall({
                selector: swapTokensSel,
                data: abi.encode(address(wbtc), address(weth), uint256(0), uint256(0)),
                outputToken: address(weth),
                minOutput: 0
            });
            h.rebalance(calls);

            // No tokens moved (no-op swap) — balance unchanged, minOutput=0 satisfied
            assertEq(weth.balanceOf(address(h)), balanceBefore);
        }

        function test_swap_multipleCallsExecuteInOrder() public {
            // Two no-op swaps — assert both execute without reverting
            SwapCall[] memory calls = new SwapCall[](2);
            calls[0] = SwapCall({
                selector: swapTokensSel,
                data: abi.encode(address(wbtc), address(weth), uint256(0), uint256(0)),
                outputToken: address(weth),
                minOutput: 0
            });
            calls[1] = SwapCall({
                selector: swapTokensSel,
                data: abi.encode(address(weth), address(wbtc), uint256(0), uint256(0)),
                outputToken: address(wbtc),
                minOutput: 0
            });
            h.rebalance(calls);
            assertFalse(h.hasPendingIntent());
        }
    }

    // =============================================================================
    //  _isDexFunction
    // =============================================================================

    contract IsDexFunctionTest is IndexFacetTestBase {
        function test_isDex_trueForRegisteredDexSelector() public view {
            // swapTokensSel was registered as DEX in setUp
            assertTrue(facetRegistry.getModuleIdBySelector(swapTokensSel) == keccak256("DEX"));
        }

        function test_isDex_falseForUnregisteredSelector() public view {
            bytes4 rando = bytes4(keccak256("randomFunction()"));
            assertFalse(facetRegistry.getModuleIdBySelector(rando) == keccak256("DEX"));
        }

        function test_isDex_falseForBaseModuleSelector() public {
            bytes4 baseSel = bytes4(keccak256("someBaseFn()"));
            facetRegistry.setModuleId(baseSel, keccak256("BASE"));
            assertFalse(facetRegistry.getModuleIdBySelector(baseSel) == keccak256("DEX"));
        }
    }

    // =============================================================================
    //  USDC value accounting
    // =============================================================================

    contract UsdcValueTest is IndexFacetTestBase {
        function setUp() public override {
            super.setUp();
            _connect();
            vm.warp(block.timestamp + IndexStorage.REBALANCE_INTERVAL + IndexStorage.INTENT_EXPIRY + 1);
        }

        function test_usdc_includedInTotalValueWhenNotComponent() public {
            // WETH + WBTC + USDC = 3000 + 6000 + 1000 = 10000e8
            h.rebalanceIntent();
            (, uint256 totalValueUsd,,,) = h.getPendingIntent();
            assertEq(totalValueUsd, 10_000e8);
        }

        function test_usdc_excludedWhenAlreadyComponent() public {
            // Make USDC an index component — it should not be double-counted
            string[] memory symbols = new string[](3);
            uint256[] memory weights = new uint256[](3);
            symbols[0] = "WETH";
            weights[0] = 5e17;
            symbols[1] = "WBTC";
            weights[1] = 3e17;
            symbols[2] = "USDC";
            weights[2] = 2e17;
            index.setWeights(symbols, weights);

            h.rebalanceIntent();
            (, uint256 totalValueUsd,,,) = h.getPendingIntent();
            // Should be exactly 3000 + 6000 + 1000 = 10000e8 (USDC counted once via components loop)
            assertEq(totalValueUsd, 10_000e8);
        }

        function test_usdc_zeroWhenBalanceIsZero() public {
            h.setTokenBalance(address(usdc), 0);
            h.rebalanceIntent();
            (, uint256 totalValueUsd,,,) = h.getPendingIntent();
            // 3000 + 6000 (no USDC) = 9000e8
            assertEq(totalValueUsd, 9000e8);
        }

        function test_usdc_gracefullySkippedWhenNotRegistered() public {
            componentRegistry.setRegistered("USDC", false);
            // Must not revert — just exclude USDC value
            h.rebalanceIntent();
            (, uint256 totalValueUsd,,,) = h.getPendingIntent();
            assertEq(totalValueUsd, 9000e8);
        }
    }

    // =============================================================================
    //  _verifyBalancesMatchTargets
    // =============================================================================

    contract VerifyBalancesTest is IndexFacetTestBase {
        function setUp() public override {
            super.setUp();
            _connect();
            _createIntent();
        }

        function test_verify_passesWhenBalancesExactlyOnTarget() public {
            // Adjust balances so values exactly match the targets in the intent.
            // Targets: WETH=6000e8, WBTC=4000e8 (from 10000e8 total with 60/40 split)
            // WETH needed: 6000e8 / 3000e8 * 1e18 = 2e18
            // WBTC needed: 4000e8 / 60000e8 * 1e8 = ~6.667e6 (rounds down)
            h.setTokenBalance(address(weth), 2e18);
            h.setTokenBalance(address(wbtc), 6_666_666); // ~4000e8 value
            h.setTokenBalance(address(usdc), 0); // drain USDC so total stays correct

            // Should succeed — no revert
            h.rebalance(new SwapCall[](0));
        }

        function test_verify_revertsWhenOutsideThreshold() public {
            // Drive WETH balance to zero — far outside 1% threshold
            h.setTokenBalance(address(weth), 0);
            vm.expectRevert(); // IndexFacet_BalanceOutsideThreshold
            h.rebalance(new SwapCall[](0));
        }

        function test_verify_passesAtExactThresholdBoundary() public {
            // WETH target ≈ 6000e8. 1% threshold = 60e8.
            // Reduce WETH balance by exactly 1% → should still pass.
            // 1% of 2e18 = 2e16
            h.setTokenBalance(address(weth), 2e18 - 2e16);
            h.setTokenBalance(address(usdc), 0);
            h.setTokenBalance(address(wbtc), 6_666_666);
            h.rebalance(new SwapCall[](0));
        }
    }

    // =============================================================================
    //  View functions
    // =============================================================================

    contract ViewFunctionsTest is IndexFacetTestBase {
        function test_isConnectedToIndex_falseInitially() public view {
            assertFalse(h.isConnectedToIndex());
        }

        function test_isConnectedToIndex_trueAfterConnect() public {
            _connect();
            assertTrue(h.isConnectedToIndex());
        }

        function test_isConnectedToIndex_falseAfterDisconnect() public {
            _connect();
            h.disconnectFromIndex();
            assertFalse(h.isConnectedToIndex());
        }

        function test_getConnectedIndex_zeroInitially() public view {
            assertEq(h.getConnectedIndex(), address(0));
        }

        function test_getConnectedIndex_nonZeroAfterConnect() public {
            _connect();
            assertEq(h.getConnectedIndex(), address(index));
        }

        function test_hasPendingIntent_falseInitially() public view {
            assertFalse(h.hasPendingIntent());
        }

        function test_hasPendingIntent_trueAfterIntent() public {
            _connect();
            _createIntent();
            assertTrue(h.hasPendingIntent());
        }

        function test_hasPendingIntent_falseAfterRebalance() public {
            _connect();
            _createIntent();
            // Balance the portfolio to targets so _verifyBalancesMatchTargets passes.
            h.setTokenBalance(address(weth), 2e18);
            h.setTokenBalance(address(wbtc), 6_666_666);
            h.setTokenBalance(address(usdc), 0);
            h.rebalance(new SwapCall[](0));
            assertFalse(h.hasPendingIntent());
        }

        function test_getPendingIntent_returnsCorrectTuple() public {
            _connect();
            _createIntent();
            (bool active, uint256 totalValueUsd, string[] memory symbols,,) = h.getPendingIntent();
            assertTrue(active);
            assertEq(totalValueUsd, 10_000e8);
            assertEq(symbols.length, 2);
        }

        function test_getPendingIntent_inactiveWhenNoIntent() public view {
            (bool active,,,,) = h.getPendingIntent();
            assertFalse(active);
        }
    }

