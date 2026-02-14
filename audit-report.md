# BLOK Capital DAO (blokc-v1-core) Security Audit Report

**Auditor:** Trail of Bits Methodology (Automated + Manual)
**Date:** 2026-02-13
**Commit:** `d9c1937` (main branch)
**Solidity Version:** ^0.8.31
**Scope:** All `.sol` files in `src/` (82 files across 15 modules)

---

## 1. Executive Summary

### Scope

The BLOK Capital DAO protocol is a Diamond proxy (EIP-2535) based DeFi portfolio management system deployed on Arbitrum One. It enables users to deploy personal "Garden" contracts (Diamond proxies) that can interact with multiple DeFi protocols (Uniswap V2/V3, Camelot V2/V3, Aave V3, GMX V2, Pendle V2, Circle CCTP) and connect to on-chain indices for automated rebalancing.

**Key components audited:**
- Diamond proxy core (Garden, DiamondCut, Loupe, Ownership, Upgrade facets)
- FacetRegistry (module-based facet management)
- GardenFactory (CREATE2 deployment)
- Index system (Index, IndexFactory, component/calculation registries)
- DEX integration facets (UniswapV2/V3, CamelotV2/V3)
- DeFi integration facets (AaveV3, GmxV2, PendleV2)
- Cross-chain (CCTP), Withdraw, RewardCollection facets
- Protocol governance (ProtocolStatus with ENS-based Security Council)
- SBT collections and registries

### Methodology

1. **Reconnaissance** - Full codebase read and architecture mapping
2. **Static Analysis** - Slither v0.11.5 (101 detectors, 260 findings triaged)
3. **Manual Review** - Trail of Bits checklist (access control, reentrancy, math, oracles, token handling, MEV, proxy, DoS, cross-contract, protocol-specific)
4. **Property Testing** - Invariant test suggestions for critical findings

### Overall Risk Assessment

| Severity | Count |
|----------|-------|
| Critical | 1 |
| High | 3 |
| Medium | 7 |
| Low | 5 |
| Informational | 5 |

**Overall Risk: HIGH** - The critical finding (missing access control on rebalance functions) enables direct fund theft via sandwich attacks. Several high-severity issues compound this risk.

---

## 2. Findings Table

| ID | Title | Severity | File | Line(s) |
|----|-------|----------|------|---------|
| C-01 | Missing access control on `rebalanceIntent()` and `rebalance()` allows anyone to execute swaps | Critical | IndexBase.sol | 93, 141 |
| H-01 | Attacker-controlled swap parameters in `_rebalance()` enable sandwich attacks | High | IndexBase.sol | 179-196 |
| H-02 | Single-step ownership transfer can permanently lock garden funds | High | OwnershipFacet.sol | 28 |
| H-03 | Incorrect Uniswap V3 Factory address (identical to Pool Registry) breaks pool validation | High | UniswapV3Base.sol | 88-90 |
| M-01 | ETH locked in Garden contracts with no withdrawal mechanism | Medium | Garden.sol | 224 |
| M-02 | GmxV2 leverage calculation uses incompatible decimal scales | Medium | GmxV2Base.sol | 145-146 |
| M-03 | GmxV2 `_addCollateral()` does not interact with GMX protocol | Medium | GmxV2Base.sol | 228-246 |
| M-04 | GmxV2 `_getPositionPnL()` always returns zero | Medium | GmxV2Base.sol | 278-288 |
| M-05 | CirculatingSupply lacks ownership transfer safeguards | Medium | CirculatingSupply.sol | 23-26 |
| M-06 | FacetRegistry `validateSelector()` allows bypass for unregistered garden types | Medium | FacetRegistry.sol | 658-662 |
| M-07 | GmxV2 `positionKeys` array grows unboundedly | Medium | GmxV2Base.sol | 175, 257-273 |
| L-01 | CCTP `_sendUsdc()` uses `transferFrom(msg.sender)` inconsistent with diamond pattern | Low | CCTPBase.sol | 100 |
| L-02 | Unused `BASE_MODULE` constant in Garden contract | Low | Garden.sol | 86 |
| L-03 | Missing `updatedAt == 0` check in MarketCapWeighted oracle validation | Low | MarketCapWeighted.sol | 114 |
| L-04 | Missing event emission in `CirculatingSupply.setUpdater()` | Low | CirculatingSupply.sol | 23-26 |
| L-05 | `Index.connectGardenToIndex()` has no permission check - any address can connect | Low | Index.sol | 142-148 |
| I-01 | Unused return values from `EnumerableSet.add()`/`remove()` | Informational | Multiple | Multiple |
| I-02 | State variables should be declared immutable | Informational | Multiple | Multiple |
| I-03 | `DiamondCut` event not indexed per best practices | Informational | IDiamondCut.sol | 44 |
| I-04 | GMX V2 constants use Arbitrum Sepolia testnet addresses | Informational | GmxV2Base.sol | 107-116 |
| I-05 | Naming convention violations for immutable variables | Informational | Multiple | Multiple |

---

## 3. Detailed Findings

---

### C-01: Missing Access Control on `rebalanceIntent()` and `rebalance()` Allows Anyone to Execute Swaps

**Severity:** Critical
**File:** `src/garden/facets/indexFacets/IndexBase.sol:93,141`
**Status:** Open

#### Description

The `IndexFacet.rebalanceIntent()` and `IndexFacet.rebalance()` functions lack the `onlyGardenOwner` modifier. Any external address can:
1. Call `rebalanceIntent()` to create a pending rebalance intent
2. Call `rebalance(swapCalls)` with attacker-controlled swap parameters to execute arbitrary DEX trades using the garden's funds

```solidity
// IndexFacet.sol:33-34 - NO onlyGardenOwner modifier!
function rebalanceIntent() external nonReentrant {
    _rebalanceIntent();
}

function rebalance(SwapCall[] calldata swapCalls) external nonReentrant {
    _rebalance(swapCalls);
}
```

#### Impact

**Direct fund theft.** An attacker can:
1. Call `rebalanceIntent()` on any index-connected garden
2. Wait for the intent to be created (captures current portfolio state)
3. Call `rebalance()` with swap calls that have `amountOutMinimum = 0`
4. Sandwich the transaction to extract maximum value from every swap
5. The `_verifyBalancesMatchTargets()` check uses a 1% threshold (`BALANCE_THRESHOLD_BPS = 100`), allowing the attacker to extract up to ~1% of portfolio value per rebalance

Since `rebalanceIntent()` can be called every 5 minutes and `rebalance()` every hour, this is a repeatable attack.

#### Root Cause

The comment in `IIndex.sol:83` states "Can be called by anyone (primarily CRE automation)" - this is by design but critically unsafe. The CRE (Centralized Rebalance Engine) should be authenticated.

#### Proof of Concept

```solidity
// Attack flow:
// 1. Attacker finds garden connected to index with funds
// 2. Attacker calls rebalanceIntent() - creates pending intent
// 3. Attacker constructs swap calls with 0 slippage protection
// 4. Attacker sandwiches their own rebalance() call

function attack(address gardenDiamond) external {
    // Step 1: Create intent (anyone can call)
    IIndex(gardenDiamond).rebalanceIntent();

    // Step 2: Build malicious swap calls with 0 amountOutMinimum
    SwapCall[] memory calls = new SwapCall[](1);
    calls[0] = SwapCall({
        selector: IUniswapV3.uniswapV3ExactInputSingle.selector,
        data: abi.encode(UniswapV3ExactInputSingleParams({
            tokenIn: WETH,
            tokenOut: USDC,
            amountIn: gardenWethBalance,
            amountOutMinimum: 0, // No slippage protection!
            swapFee: 3000,
            deadline: block.timestamp + 300
        }))
    });

    // Step 3: Sandwich this call
    IIndex(gardenDiamond).rebalance(calls);
}
```

#### Recommended Fix

Add `onlyGardenOwner` to both functions, or implement a CRE whitelist:

```diff
- function rebalanceIntent() external nonReentrant {
+ function rebalanceIntent() external nonReentrant onlyGardenOwner {
      _rebalanceIntent();
  }

- function rebalance(SwapCall[] calldata swapCalls) external nonReentrant {
+ function rebalance(SwapCall[] calldata swapCalls) external nonReentrant onlyGardenOwner {
      _rebalance(swapCalls);
  }
```

If CRE automation is required, implement an authorized relayer pattern with on-chain signature verification.

---

### H-01: Attacker-Controlled Swap Parameters in `_rebalance()` Enable Sandwich Attacks

**Severity:** High
**File:** `src/garden/facets/indexFacets/IndexBase.sol:179-196`
**Status:** Open

#### Description

Even if C-01 is fixed with access control, the `_rebalance()` function accepts externally-provided `SwapCall[]` parameters without validating that the swap parameters (especially `amountOutMinimum`) provide adequate slippage protection. The only check is that the selector belongs to the DEX module.

```solidity
function _executeSwapCalls(SwapCall[] calldata swapCalls) internal {
    for (uint256 i = 0; i < swapCalls.length; i++) {
        bytes4 selector = swapCalls[i].selector;
        if (!_isDexFunction(selector)) revert IndexFacet_SelectorNotWhitelisted(selector);

        bytes memory callData = abi.encodePacked(selector, swapCalls[i].data);
        (bool success, bytes memory returnData) = address(this).call(callData);
        // ... no validation of swap parameters
    }
}
```

#### Impact

The caller can set `amountOutMinimum` to 0 in swap calls, making every swap susceptible to sandwich attacks. Even the garden owner could inadvertently submit poorly constructed swap calls.

#### Root Cause

Swap parameter validation is deferred entirely to the DEX router contracts. The protocol does not enforce minimum slippage protection.

#### Recommended Fix

Add minimum slippage enforcement in `_executeSwapCalls()`, or validate that `amountOutMinimum` meets a protocol-defined threshold (e.g., using TWAP price with max slippage of `MAX_SLIPPAGE_BPS = 500`).

---

### H-02: Single-Step Ownership Transfer Can Permanently Lock Garden Funds

**Severity:** High
**File:** `src/garden/facets/baseFacets/ownership/OwnershipFacet.sol:28`
**Status:** Open

#### Description

`OwnershipFacet.transferOwnership()` immediately transfers ownership to the new address without a two-step confirmation process.

```solidity
function transferOwnership(address _newOwner) external override onlyGardenOwner {
    _transferOwnership(_newOwner); // Immediately sets new owner
}

function _transferOwnership(address _newOwner) internal {
    OwnershipStorage.layout().owner = _newOwner; // No pending owner pattern
    emit OwnershipTransferred(msg.sender, _newOwner);
}
```

#### Impact

If ownership is transferred to an incorrect address (typo, wrong chain address, contract that can't interact):
- All funds in the garden become permanently locked
- No upgrade, withdrawal, or management operations possible
- The garden becomes an irrecoverable loss

#### Root Cause

No two-step (propose + accept) ownership transfer pattern.

#### Recommended Fix

Implement a two-step ownership transfer:

```solidity
function transferOwnership(address _newOwner) external onlyGardenOwner {
    OwnershipStorage.layout().pendingOwner = _newOwner;
    emit OwnershipTransferRequested(msg.sender, _newOwner);
}

function acceptOwnership() external {
    require(msg.sender == OwnershipStorage.layout().pendingOwner);
    _transferOwnership(msg.sender);
    delete OwnershipStorage.layout().pendingOwner;
}
```

---

### H-03: Incorrect Uniswap V3 Factory Address Breaks Pool Validation

**Severity:** High
**File:** `src/garden/facets/utilityFacets/arbitrumOne/uniswapV3/UniswapV3Base.sol:88-90`
**Status:** Open

#### Description

The `POOL_REGISTRY_ADDRESS` and `UNISWAP_FACTORY_ADDRESS` constants are set to the **same address**:

```solidity
address internal constant POOL_REGISTRY_ADDRESS = 0xBa7898DbE9C2be340197e1fffe85FC5a3B977744;
address internal constant UNISWAP_FACTORY_ADDRESS = 0xBa7898DbE9C2be340197e1fffe85FC5a3B977744;
```

The actual Uniswap V3 Factory on Arbitrum One is `0x1F98431c8aD98523631AE4a59f267346ea31F984`. The `_validatePool()` function calls:

```solidity
address pool = IUniswapV3Factory(UNISWAP_FACTORY_ADDRESS).getPool(tokenIn, tokenOut, swapFee);
```

This calls `getPool()` on the LiquidityPoolRegistry contract, which does not implement this function. This will either revert or return unexpected data.

#### Impact

- All Uniswap V3 swap pool validation may fail or behave unpredictably
- If the call reverts, Uniswap V3 swaps become entirely unusable
- If it doesn't revert (unlikely), it could bypass pool validation entirely

#### Root Cause

Copy-paste error - both constants set to pool registry address.

#### Recommended Fix

```diff
- address internal constant UNISWAP_FACTORY_ADDRESS = 0xBa7898DbE9C2be340197e1fffe85FC5a3B977744;
+ address internal constant UNISWAP_FACTORY_ADDRESS = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
```

---

### M-01: ETH Locked in Garden Contracts With No Withdrawal Mechanism

**Severity:** Medium
**File:** `src/garden/Garden.sol:224`
**Status:** Open (Confirmed by Slither `locked-ether` detector)

#### Description

The Garden contract has a `receive()` function that accepts ETH, and the constructor/fallback are payable:

```solidity
receive() external payable { }
```

However, there is no facet that provides ETH withdrawal functionality. The `WithdrawFacet` only handles USDC.

#### Impact

Any ETH sent to a Garden contract (accidentally or via protocol operations like GMX execution fees) becomes permanently locked.

#### Root Cause

Missing ETH withdrawal function in the withdrawal facet.

#### Recommended Fix

Add an ETH withdrawal function to `WithdrawFacet`:

```solidity
function withdrawEth(uint256 amount) external onlyGardenOwner ifIndexNotConnected {
    address to = IERC173(address(this)).owner();
    (bool success, ) = to.call{value: amount}("");
    require(success, "ETH transfer failed");
}
```

---

### M-02: GmxV2 Leverage Calculation Uses Incompatible Decimal Scales

**Severity:** Medium
**File:** `src/garden/facets/utilityFacets/arbitrumOne/gmxV2/GmxV2Base.sol:145-146`
**Status:** Open

#### Description

```solidity
uint256 leverage = (params.sizeInUsd * 1e18) / (params.collateralAmount * 1e18);
if (leverage > s.maxLeverage * 1e18) revert GmxV2Base_ExcessiveLeverage();
```

The `1e18` multipliers in numerator and denominator cancel out, making `leverage = sizeInUsd / collateralAmount`. However:
- `sizeInUsd` is in 30 decimals (GMX V2 standard: USD values use 30 decimal precision)
- `collateralAmount` is in token decimals (e.g., 6 for USDC, 18 for WETH)

For USDC collateral: a $1000 position with 100 USDC collateral = `1000e30 / 100e6 = 1e25`, which is always > `10e18`, meaning the leverage check **always reverts** for USDC-collateralized positions.

#### Impact

GMX V2 short positions with USDC collateral are unusable due to always-reverting leverage check. With WETH collateral, the check is also incorrect.

#### Root Cause

Decimal scale mismatch between GMX V2's USD representation (30 decimals) and token amounts.

#### Recommended Fix

Normalize both values to the same decimal precision before comparison.

---

### M-03: GmxV2 `_addCollateral()` Does Not Interact With GMX Protocol

**Severity:** Medium
**File:** `src/garden/facets/utilityFacets/arbitrumOne/gmxV2/GmxV2Base.sol:228-246`
**Status:** Open

#### Description

```solidity
function _addCollateral(bytes32 positionKey, uint256 collateralAmount) internal {
    // ... validation ...
    // Note: In production, you would call GMX to actually add collateral
    position.collateralAmount += collateralAmount;
    s.totalCollateralLocked += collateralAmount;
}
```

The function only updates local storage but does not call GMX's ExchangeRouter to actually add collateral to the on-chain position. This creates a desync between the protocol's recorded state and the actual GMX position.

#### Impact

- Local state diverges from actual GMX position state
- Leverage calculations based on local `collateralAmount` are incorrect
- Users may believe they have safer positions than they actually do

---

### M-04: GmxV2 `_getPositionPnL()` Always Returns Zero

**Severity:** Medium
**File:** `src/garden/facets/utilityFacets/arbitrumOne/gmxV2/GmxV2Base.sol:278-288`
**Status:** Open

#### Description

```solidity
function _getPositionPnL(bytes32 positionKey) internal view returns (int256 pnl) {
    // Note: In production, call GMX Reader to get actual PnL
    return 0; // Always returns 0
}
```

This is called in `_closeShort()` and emitted in the `ShortPositionClosed` event with incorrect PnL data.

#### Impact

Off-chain systems relying on the `ShortPositionClosed` event receive incorrect PnL data. Position management decisions based on this data will be wrong.

---

### M-05: CirculatingSupply Lacks Ownership Transfer Safeguards

**Severity:** Medium
**File:** `src/indices/CirculatingSupply.sol:23-26`
**Status:** Open

#### Description

```solidity
function setUpdater(address newUpdater) external {
    require(msg.sender == updater, "Not updater");
    updater = newUpdater; // No zero-address check, no two-step
}
```

The `updater` role controls all circulating supply data, which directly affects index weights and therefore rebalancing of all connected gardens.

#### Impact

- Transfer to zero address permanently locks the updater role
- Transfer to wrong address gives attacker control over all index weight calculations
- Attacker can manipulate weights to trigger unfavorable rebalances across all gardens

---

### M-06: FacetRegistry `validateSelector()` Allows Bypass for Unregistered Garden Types

**Severity:** Medium
**File:** `src/facetRegistry/FacetRegistry.sol:658-662`
**Status:** Open

#### Description

```solidity
function validateSelector(bytes4 selector, bytes32 gardenType)
    external view returns (address registeredFacet, bool moduleAllowed)
{
    // ...
    if (moduleId == BASE_MODULE) {
        moduleAllowed = true;
    } else if (gardenType != bytes32(0) && _gardenTypeExists[gardenType]) {
        moduleAllowed = _gardenTypeModuleIndex[gardenType][moduleId] != 0;
    } else {
        moduleAllowed = true; // <-- Unregistered garden types bypass module check
    }
}
```

If a garden type is non-zero but not registered, `moduleAllowed` defaults to `true`, bypassing module restrictions.

#### Impact

A garden with a crafted non-registered gardenType value could execute selectors from any module, bypassing module-based access control.

#### Root Cause

The fallback case is too permissive. It should return `false` for non-registered garden types.

---

### M-07: GmxV2 `positionKeys` Array Grows Unboundedly

**Severity:** Medium
**File:** `src/garden/facets/utilityFacets/arbitrumOne/gmxV2/GmxV2Base.sol:175, 257-273`
**Status:** Open

#### Description

Position keys are pushed to the `positionKeys` array but never removed, even when positions are closed. The `_getActivePositions()` function iterates over all historical keys:

```solidity
for (uint256 i = 0; i < s.positionKeys.length && index < activeCount; i++) {
    // iterates ALL keys to find active ones
}
```

#### Impact

Over time, gas costs for `_getActivePositions()` increase linearly. Eventually, the function may exceed block gas limits, causing a DoS on position queries.

---

### L-01: CCTP `_sendUsdc()` Uses `transferFrom(msg.sender)` Inconsistent With Diamond Pattern

**Severity:** Low
**File:** `src/garden/facets/utilityFacets/arbitrumOne/cctp/CCTPBase.sol:100`
**Status:** Open

#### Description

`_sendUsdc()` does `usdc.safeTransferFrom(msg.sender, address(this), amount)` which pulls USDC from `msg.sender` (the garden owner). All other facets operate on the garden's own balance. This requires the owner to separately approve the diamond for USDC spending, which is inconsistent with the protocol pattern.

---

### L-02: Unused `BASE_MODULE` Constant in Garden Contract

**Severity:** Low
**File:** `src/garden/Garden.sol:86`
**Status:** Open (Confirmed by Slither `unused-state` detector)

#### Description

`bytes32 private constant BASE_MODULE = keccak256("BASE")` is declared but never referenced in the Garden contract.

---

### L-03: Missing `updatedAt == 0` Check in MarketCapWeighted Oracle Validation

**Severity:** Low
**File:** `src/indices/indexCalculations/MarketCapWeighted.sol:114`
**Status:** Open

#### Description

The `_getComponentPrice()` function calls `IndexMath.validateOracleData()` which checks `price <= 0`, staleness, and round completeness, but the `MarketCapWeighted` contract destructures `latestRoundData()` and discards the `startedAt` return value. While `IndexMath.validateOracleData` doesn't check `updatedAt == 0` (which could indicate an uninitialized feed), the `IndexBase._getPrice()` function does check this. Inconsistent validation across oracle consumers.

---

### L-04: Missing Event Emission in `CirculatingSupply.setUpdater()`

**Severity:** Low
**File:** `src/indices/CirculatingSupply.sol:23-26`
**Status:** Open

#### Description

Updater address changes are not logged via events, making it difficult to monitor for unauthorized changes.

---

### L-05: `Index.connectGardenToIndex()` Has No Permission Check

**Severity:** Low
**File:** `src/indices/Index.sol:142-148`
**Status:** Open

#### Description

Any address can call `connectGardenToIndex()`, not just registered gardens. While this doesn't directly affect fund safety (it only adds the caller to an `EnumerableSet`), it could pollute the connected gardens set with arbitrary addresses.

---

### I-01: Unused Return Values From `EnumerableSet` Operations

**Severity:** Informational
**Status:** Open (Confirmed by Slither, 20+ instances)

Multiple contracts ignore the boolean return value from `EnumerableSet.add()` and `EnumerableSet.remove()`. While not exploitable (the operations are idempotent), checking return values is best practice.

---

### I-02: State Variables Should Be Declared Immutable

**Severity:** Informational
**Status:** Open (Confirmed by Slither)

Several state variables set only in constructors should use the `immutable` keyword for gas optimization: `GardenFactory._facetRegistry`, `GardenFactory._protocolStatus`, `GardenFactory._sbtRegistry`, `UniversalSBTCollection.factory`, `UniversalSBTCollection.maxSupply`, SBT collection `parentPass` variables.

---

### I-03: `DiamondCut` Event Not Indexed

**Severity:** Informational
**File:** `src/garden/facets/baseFacets/cut/IDiamondCut.sol:44`

The `DiamondCut` event has address parameters but none are indexed, making it harder to filter events off-chain.

---

### I-04: GMX V2 Constants Use Arbitrum Sepolia Testnet Addresses

**Severity:** Informational
**File:** `src/garden/facets/utilityFacets/arbitrumOne/gmxV2/GmxV2Base.sol:107-116`

The GMX V2 ExchangeRouter, OrderVault, Reader, and DataStore addresses are Arbitrum Sepolia testnet addresses, not Arbitrum One mainnet.

---

### I-05: Naming Convention Violations

**Severity:** Informational
**Status:** Open (Confirmed by Slither)

Multiple `private immutable` variables use `SCREAMING_SNAKE_CASE` (e.g., `INDEX_CALCULATION_REGISTRY`) which is conventionally reserved for `constant` variables. Immutables should use `mixedCase` per Solidity style guide.

---

## 4. Systemic Risks

### 4.1 Centralization Risks

| Component | Risk | Impact |
|-----------|------|--------|
| FacetRegistry owner | Can modify all facet registrations, add/remove modules | Can brick all gardens by removing critical facets |
| ProtocolStatus owner | Can activate/deactivate protocol, manage security council | Can freeze all garden operations |
| CirculatingSupply updater | Controls all supply data for index calculations | Can manipulate all index weights |
| IndexFactory owner | Can deploy/remove indices | Can disrupt index-connected gardens |
| LiquidityPoolRegistry owner | Can add/remove pool registrations | Can disable DEX swaps by removing pool registrations |

**Recommendation:** Consider timelock mechanisms for FacetRegistry, ProtocolStatus, and IndexFactory owner operations. The CirculatingSupply updater should be migrated to a multi-sig or DAO-controlled address.

### 4.2 Upgrade Risks

- The Diamond upgrade system is well-designed with FacetRegistry validation
- `DiamondCutFacet.diamondCut()` is intentionally blocked (always reverts), forcing upgrades through `UpgradeFacet.upgrade()`
- Upgrade hash verification prevents frontrunning of upgrade transactions
- However, the FacetRegistry owner can silently change facet implementations that will be applied on next upgrade

### 4.3 External Dependency Risks

- **Chainlink oracles**: 1-hour staleness threshold is used. A Chainlink outage > 1 hour would block all rebalancing operations
- **ENS resolution**: ProtocolStatus security council depends on ENS resolution. ENS registry compromise could affect protocol governance
- **DEX protocol risk**: Direct integration with Uniswap, Camelot, Aave, GMX means bugs in those protocols cascade here

### 4.4 Cross-Contract Interaction Risks

The `_executeSwapCalls()` in IndexBase uses `address(this).call()` to invoke DEX facets. This:
- Bypasses the fallback function's FacetRegistry validation (since the call goes through the fallback, it IS validated)
- Creates a self-call context where `msg.sender == address(this)`, which bypasses `onlyGardenOwner` and `ifIndexNotConnected` modifiers (by design, per `Facet.sol:53-54`)

This design pattern is intentional for rebalancing but creates a trust boundary: **whoever can trigger `_rebalance()` effectively has owner-level access to DEX operations.**

---

## 5. Recommendations

### 5.1 Suggested Invariant Tests

#### Test for C-01: Access Control on Rebalance

```solidity
function testFuzz_onlyOwnerCanRebalance(address caller) public {
    vm.assume(caller != gardenOwner);
    vm.assume(caller != address(garden));

    // Connect garden to index
    vm.prank(gardenOwner);
    IndexFacet(address(garden)).connectToIndex(indexAddress);

    // Non-owner should not be able to create intent
    vm.prank(caller);
    vm.expectRevert(Garden_UnauthorizedCaller.selector);
    IndexFacet(address(garden)).rebalanceIntent();
}
```

#### Test for H-02: Ownership Transfer Safety

```solidity
function testFuzz_ownershipTransferToZeroLocksFunds(uint256 depositAmount) public {
    vm.assume(depositAmount > 0 && depositAmount < type(uint128).max);

    // Deposit funds
    deal(USDC, address(garden), depositAmount);

    // Transfer ownership to address(0)
    vm.prank(gardenOwner);
    OwnershipFacet(address(garden)).transferOwnership(address(0));

    // Owner is now address(0) - verify no one can withdraw
    vm.prank(gardenOwner);
    vm.expectRevert(Garden_UnauthorizedCaller.selector);
    WithdrawFacet(address(garden)).withdrawUsdc(depositAmount);
}
```

#### Test for M-01: ETH Locking

```solidity
function testFuzz_ethLockedInGarden(uint256 ethAmount) public {
    vm.assume(ethAmount > 0 && ethAmount < 100 ether);
    vm.deal(address(this), ethAmount);

    // Send ETH to garden
    (bool success,) = address(garden).call{value: ethAmount}("");
    assertTrue(success);

    // Verify ETH is locked (no withdrawal function exists)
    assertEq(address(garden).balance, ethAmount);
    // There should be a withdrawEth function - this test documents the gap
}
```

#### Invariant: Garden Balance Integrity

```solidity
function invariant_gardenBalanceNeverDecreaseWithoutOwnerAction() public {
    // Track USDC balance before and after any non-owner transaction
    uint256 balanceBefore = IERC20(USDC).balanceOf(address(garden));

    // ... execute random transactions from non-owner addresses ...

    uint256 balanceAfter = IERC20(USDC).balanceOf(address(garden));
    assertGe(balanceAfter, balanceBefore,
        "Garden balance decreased without owner authorization");
}
```

### 5.2 Monitoring Recommendations

1. **Monitor `rebalanceIntent()` and `rebalance()` calls** - Alert on calls from non-owner addresses (until C-01 is fixed)
2. **Monitor `OwnershipTransferred` events** - Alert on ownership changes, especially to address(0) or contracts
3. **Monitor CirculatingSupply `updater` changes** - Alert on `setUpdater()` calls
4. **Monitor ProtocolStatus changes** - Alert on `deactivateProtocol()` and `disableUpgrades()` calls
5. **Monitor large swap slippage** - Alert when `amountOutMinimum` is set to 0 or near-zero in DEX facet calls

### 5.3 Operational Security

1. **FacetRegistry owner**: Should be a multi-sig with timelock (e.g., Gnosis Safe + 48h timelock)
2. **ProtocolStatus owner**: Should be the DAO governance contract
3. **Upgrade process**: Consider adding a mandatory delay between `upgradeDetails()` query and `upgrade()` execution
4. **CRE automation**: If keeper bots are used for rebalancing, authenticate them via on-chain registry rather than making functions permissionless

---

## 6. Static Analysis Summary (Slither)

**Tool:** Slither v0.11.5
**Total findings:** 260
**After triage:**

| Category | Count | Status |
|----------|-------|--------|
| High (reentrancy-balance in CCTP) | 1 | Triaged as Low - balance check after external call is intentional |
| Medium (locked-ether) | 1 | Confirmed as M-01 |
| Medium (divide-before-multiply) | 1 | False positive - assembly power function is correct |
| Medium (incorrect-equality) | 3 | False positive - SBT balance check `== 0` is intentional |
| Medium (unused-return) | 25+ | Confirmed as I-01 |
| Low/Informational | 230+ | Naming, immutability, caching suggestions |

---

*Report generated following Trail of Bits audit methodology. All findings verified through manual code review. No false positives included - uncertain findings are clearly marked.*
