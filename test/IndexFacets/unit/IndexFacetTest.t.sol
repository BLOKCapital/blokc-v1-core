// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import "forge-std/Test.sol";

import { IndexFacet } from "../../../src/garden/facets/indexFacets/IndexFacet.sol";

import { IndexBase } from "../../../src/garden/facets/indexFacets/IndexBase.sol";

import { IndexStorage } from "../../../src/garden/facets/indexFacets/IndexStorage.sol";

import { IIndex, SwapCall } from "../../../src/garden/facets/indexFacets/IIndex.sol";
import { IFacetRegistry } from "../../../src/interfaces/IFacetRegistry.sol";
import { LibDiamond } from "../../../src/garden/libraries/LibDiamond.sol";
import { LibStorageSlot } from "../../../src/garden/libraries/LibStorageSlot.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {
    IndexFacet_NotConnectedToIndex,
    IndexFacet_AlreadyConnectedToIndex,
    IndexFacet_IndexNotRegistered,
    IndexFacet_RebalanceIntervalNotPassed,
    IndexFacet_BalanceOutsideThreshold,
    IndexFacet_SwapCallFailed,
    IndexFacet_SelectorNotWhitelisted,
    IndexFacet_SelectorNotFound,
    IndexFacet_InsufficientSwapOutput,
    IndexFacet_ExcessiveValueLoss,
    IndexFacet_RebalanceReentrancy
} from "../../../src/garden/facets/indexFacets/IndexBase.sol";

// =============================================================================
// MOCKS
// =============================================================================

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

    contract MockIndexFactory {
        mapping(address => bool) public registered;

        function setRegistered(address idx, bool val) external {
            registered[idx] = val;
        }

        function isIndexRegistered(address idx) external view returns (bool) {
            return registered[idx];
        }
    }

    contract MockIndex {
        bool public connectCalled;
        bool public disconnectCalled;

        string[] private _symbols;
        uint256[] private _weights;

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

    contract MockComponentRegistry {
        mapping(string => address) public components;
        mapping(address => uint256) public prices;
        mapping(string => bool) public registered;

        bool public revertOnFetchPrice;

        function setComponent(string memory _symbol, address token) external {
            components[_symbol] = token;
            registered[_symbol] = true;
        }

        function setPrice(address token, uint256 price) external {
            prices[token] = price;
        }

        function setRegistered(string memory _symbol, bool val) external {
            registered[_symbol] = val;
        }

        function setRevertOnFetchPrice(bool v) external {
            revertOnFetchPrice = v;
        }

        function getComponentAddress(string memory _symbol) external view returns (address) {
            return components[_symbol];
        }

        function fetchPrice(
            address token,
            string memory /*_symbol*/
        )
            external
            view
            returns (uint256)
        {
            if (revertOnFetchPrice) revert("MockComponentRegistry: fetchPrice failed");
            return prices[token];
        }

        function isComponentRegistered(string memory _symbol) external view returns (bool) {
            return registered[_symbol];
        }
    }

    contract MockFacetRegistry {
        mapping(bytes4 => bytes32) public moduleIds;

        function setModuleId(bytes4 sel, bytes32 moduleId) external {
            moduleIds[sel] = moduleId;
        }

        function getModuleIdBySelector(bytes4 sel) external view returns (bytes32) {
            return moduleIds[sel];
        }
    }

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
        function swapTokens(
            address, address, uint256, uint256
        )
            external
            returns (uint256)
        {
            return 0;
        }

        function alwaysFails() external pure {
            revert("dex: always fails");
        }
    }

    // ── Harness — exposes IndexBase internals and wires storage ──

    contract IndexFacetHarness is IndexBase {
        MockIndexFactory public factory;
        MockIndex public index;
        MockComponentRegistry public componentRegistry;
        MockFacetRegistry public facetRegistry;
        MockDexFacet public dexFacet;
        MockERC20 public usdc;

        function connectToIndex(address idx) external {
            _connectToIndex(idx);
        }

        function disconnectFromIndex() external {
            _disconnectFromIndex();
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

        function getLastRebalanceTimestamp() external view returns (uint256) {
            return _getLastRebalanceTimestamp();
        }

        function forceSetLastRebalanceTimestamp(uint256 ts) external {
            IndexStorage.layout().lastRebalanceTimestamp = ts;
        }

        function forceSetRebalancing(bool v) external {
            IndexStorage.layout().rebalancing = v;
        }

        function getIndexAddress() external view returns (address) {
            return IndexStorage.layout().indexAddress;
        }

        function isRebalancing() external view returns (bool) {
            return IndexStorage.layout().rebalancing;
        }

        function setFacetRegistry(address registry) external {
            LibDiamond.layout().facetRegistry = registry;
        }

        function setTokenBalance(address token, uint256 amount) external {
            MockERC20(token).setBalance(address(this), amount);
        }

        function getTokenBalance(address token) external view returns (uint256) {
            return IERC20(token).balanceOf(address(this));
        }

        // DEX stub — _executeSwapCalls does address(this).call(selector + data)
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
        uint256 internal constant WETH_PRICE = 3000e8;
        uint256 internal constant WBTC_PRICE = 60_000e8;
        uint256 internal constant USDC_PRICE = 1e8;

        // Balances
        uint256 internal constant WETH_BALANCE = 1e18;     // 1 WETH  → $3,000
        uint256 internal constant WBTC_BALANCE = 1e7;      // 0.1 WBTC → $6,000
        uint256 internal constant USDC_BALANCE = 1000e6;   // $1,000 USDC

        // Weights: WETH 60%, WBTC 40% (sum = 1e18)
        uint256 internal constant WETH_WEIGHT = 6e17;
        uint256 internal constant WBTC_WEIGHT = 4e17;

        bytes4 internal swapTokensSel;
        bytes4 internal alwaysFailsSel;

        function setUp() public virtual {
            factory = new MockIndexFactory();
            index = new MockIndex();
            componentRegistry = new MockComponentRegistry();
            facetRegistry = new MockFacetRegistry();
            dexFacet = new MockDexFacet();
            weth = new MockERC20("WETH", 18);
            wbtc = new MockERC20("WBTC", 8);
            usdc = new MockERC20("USDC", 6);

            h = new IndexFacetHarness();

            _etchMockAt(IndexStorage.INDEX_FACTORY_ADDRESS, address(factory));
            _etchMockAt(IndexStorage.INDEX_COMPONENT_REGISTRY_ADDRESS, address(componentRegistry));
            _etchMockAt(IndexStorage.USDC_ADDRESS, address(usdc));
            _etchMockAt(IndexStorage.WETH_ADDRESS, address(weth));

            h.setFacetRegistry(address(facetRegistry));

            componentRegistry.setComponent("WETH", address(weth));
            componentRegistry.setComponent("WBTC", address(wbtc));
            componentRegistry.setComponent("USDC", address(usdc));
            componentRegistry.setPrice(address(weth), WETH_PRICE);
            componentRegistry.setPrice(address(wbtc), WBTC_PRICE);
            componentRegistry.setPrice(address(usdc), USDC_PRICE);
            componentRegistry.setPrice(IndexStorage.USDC_ADDRESS, USDC_PRICE);

            h.setTokenBalance(address(weth), WETH_BALANCE);
            h.setTokenBalance(address(wbtc), WBTC_BALANCE);
            h.setTokenBalance(address(usdc), USDC_BALANCE);

            factory.setRegistered(address(index), true);

            string[] memory symbols = new string[](2);
            uint256[] memory weights = new uint256[](2);
            symbols[0] = "WETH";
            weights[0] = WETH_WEIGHT;
            symbols[1] = "WBTC";
            weights[1] = WBTC_WEIGHT;
            index.setWeights(symbols, weights);

            swapTokensSel = MockDexFacet.swapTokens.selector;
            alwaysFailsSel = MockDexFacet.alwaysFails.selector;

            facetRegistry.setModuleId(swapTokensSel, keccak256("DEX"));
        }

        function _etchMockAt(address target, address mockSource) internal {
            CallForwarder forwarder = new CallForwarder(mockSource);
            vm.etch(target, address(forwarder).code);
        }

        function _connect() internal {
            h.connectToIndex(address(index));
        }

        /// @dev Advance past rebalance interval so _rebalance can be called.
        function _warpPastInterval() internal {
            vm.warp(block.timestamp + IndexStorage.REBALANCE_INTERVAL + 1);
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

        function test_disconnect_revertsWhenNotConnected() public {
            h.disconnectFromIndex();
            vm.expectRevert(IndexFacet_NotConnectedToIndex.selector);
            h.disconnectFromIndex();
        }

        function test_disconnect_revertsWhenIndexRevertsOnDisconnect() public {
            index.setRevertOnDisconnect(true);
            vm.expectRevert("MockIndex: disconnect failed");
            h.disconnectFromIndex();
        }
    }

    // =============================================================================
    //  rebalance — guard clauses
    // =============================================================================

    contract RebalanceGuardsTest is IndexFacetTestBase {
        function setUp() public override {
            super.setUp();
            _connect();
            _warpPastInterval();
        }

        function test_rebalance_revertsOnReentrancy() public {
            h.forceSetRebalancing(true);
            vm.expectRevert(IndexFacet_RebalanceReentrancy.selector);
            h.rebalance(new SwapCall[](0));
        }

        function test_rebalance_revertsWhenNotConnected() public {
            vm.store(
                address(h),
                bytes32(uint256(LibStorageSlot.deriveStorageSlot(type(IndexStorage).name))),
                bytes32(0) // wipes indexAddress slot
            );
            vm.expectRevert(IndexFacet_NotConnectedToIndex.selector);
            h.rebalance(new SwapCall[](0));
        }

        function test_rebalance_revertsWhenRebalanceIntervalNotPassed() public {
            h.forceSetLastRebalanceTimestamp(block.timestamp);
            vm.expectRevert(IndexFacet_RebalanceIntervalNotPassed.selector);
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
            _warpPastInterval();
            // Balance the portfolio to 60/40 targets so _verifyBalancesMatchTargets passes.
            // Total value = WETH($6000) + WBTC($4000) + USDC($0) = $10000
            // WETH target = 10000 * 0.6 = $6000 → 2e18 tokens at $3000
            // WBTC target = 10000 * 0.4 = $4000 → 6_666_666 tokens at $60000 (8 dec)
            h.setTokenBalance(address(weth), 2e18);
            h.setTokenBalance(address(wbtc), 6_666_666);
            h.setTokenBalance(address(usdc), 0);
        }

        function _buildNoOpSwapCalls() internal view returns (SwapCall[] memory calls) {
            calls = new SwapCall[](1);
            calls[0] = SwapCall({
                selector: swapTokensSel,
                data: abi.encode(address(weth), address(wbtc), uint256(0), uint256(0)),
                outputToken: address(weth),
                minOutput: 0
            });
        }

        function test_rebalance_clearsRebalancingFlagOnSuccess() public {
            h.rebalance(_buildNoOpSwapCalls());
            assertFalse(h.isRebalancing());
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
            h.setTokenBalance(address(weth), 2e18 / 10);
            vm.expectRevert();
            h.rebalance(_buildNoOpSwapCalls());
        }

        function test_rebalance_allowsValueLossWithinBps() public {
            uint256 slippageWei = (2e18 * 40) / 10_000;
            h.setTokenBalance(address(weth), 2e18 - slippageWei);
            h.rebalance(_buildNoOpSwapCalls());
        }

        function test_rebalance_emptySwapCallsSucceeds() public {
            h.rebalance(new SwapCall[](0));
        }

        function test_rebalance_secondRebalanceRequiresInterval() public {
            h.rebalance(_buildNoOpSwapCalls());
            vm.expectRevert(IndexFacet_RebalanceIntervalNotPassed.selector);
            h.rebalance(_buildNoOpSwapCalls());
        }

        function test_rebalance_secondRebalanceSucceedsAfterInterval() public {
            h.rebalance(_buildNoOpSwapCalls());
            _warpPastInterval();
            h.rebalance(_buildNoOpSwapCalls());
        }
    }

    // =============================================================================
    //  _executeSwapCalls — per-swap validation
    // =============================================================================

    contract ExecuteSwapCallsTest is IndexFacetTestBase {
        function setUp() public override {
            super.setUp();
            _connect();
            _warpPastInterval();
            h.setTokenBalance(address(weth), 2e18);
            h.setTokenBalance(address(wbtc), 6_666_666);
            h.setTokenBalance(address(usdc), 0);
        }

        function test_swap_revertsOnNonDexSelector() public {
            SwapCall[] memory calls = new SwapCall[](1);
            calls[0] = SwapCall({ selector: alwaysFailsSel, data: "", outputToken: address(weth), minOutput: 0 });
            vm.expectRevert(abi.encodeWithSelector(IndexFacet_SelectorNotWhitelisted.selector, alwaysFailsSel));
            h.rebalance(calls);
        }

        function test_swap_revertsWhenSelectorNotFound() public {
            bytes4 ghostSel = bytes4(keccak256("ghostSwap()"));
            facetRegistry.setModuleId(ghostSel, keccak256("DEX"));

            SwapCall[] memory calls = new SwapCall[](1);
            calls[0] = SwapCall({ selector: ghostSel, data: "", outputToken: address(weth), minOutput: 0 });
            vm.expectRevert(abi.encodeWithSelector(IndexFacet_SelectorNotFound.selector, ghostSel));
            h.rebalance(calls);
        }

        function test_swap_revertsWhenSwapCallFails() public {
            facetRegistry.setModuleId(alwaysFailsSel, keccak256("DEX"));

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
            SwapCall[] memory calls = new SwapCall[](1);
            calls[0] = SwapCall({
                selector: swapTokensSel,
                data: abi.encode(address(wbtc), address(weth), uint256(0), uint256(0)),
                outputToken: address(weth),
                minOutput: 1e18
            });
            vm.expectRevert(
                abi.encodeWithSelector(
                    IndexFacet_InsufficientSwapOutput.selector, uint256(0), address(weth), uint256(0), uint256(1e18)
                )
            );
            h.rebalance(calls);
        }
    }
