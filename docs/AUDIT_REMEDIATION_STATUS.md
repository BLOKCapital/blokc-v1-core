# Audit Remediation Status — Vinay OnChain Audits (200c711)

| Item | Value |
|---|---|
| Source review | [`docs/AUDIT_REPORT_REVIEW.md`](./AUDIT_REPORT_REVIEW.md) |
| Audited commit | `200c711` |
| Baseline before this remediation | `4af5d77` |
| Branch | `feat/fees-performance-protocol-onboarder` |
| Remediation date | 26 October 2026 |
| Scope | The open/partial findings called out in the review's prioritised action list |

This document records the implementation status of the findings that remained open or
partial in the source review. It supplements, and does not replace, the review itself.
Commit hashes below are on the branch above; the review's own status table is a
point-in-time snapshot of `4af5d77`.

---

## 1. Status summary

| ID | Review status at `4af5d77` | Status after remediation | Commit |
|---|---|---|---|
| C01 | Partial | **Addressed with accepted residual** — per-step hop cap, path-shape checks, pool dedup, circular-swap rejection | `17a31bb` |
| C02 | Addressed for new gardens | **Addressed (hardened)** — tracked approvals, `revokeTokens`, transfer-time clearing, layout-version validation | `3879c0d`, `7cc51fe` |
| M04 | Open | **Addressed** — `INACTIVE` halts `cumulativeRebalance` | `64aa35d` |
| M05 | Open | **Addressed** — empty step sets revert before any state change | `17a31bb` |
| L02 | Open | **Addressed** — selectors moved to another module are not removed | `cd1cb69` |
| L03 | Open | **Addressed** — live owner getters + ownership-indexed views | `bc5a6bf` |
| I02 | Open | **Addressed** — registration rejects non-8-decimal feeds | `bc5a6bf` |
| I03 | Open | **Addressed and fork-validated** — Camelot exact-output ABI/path and Algebra fee/TWAP reads corrected | `b45afa5`, `705338c` |
| I04 | Open | **Addressed in code** — Uniswap V3 exact-output path reversed | `b45afa5` |
| L01 | Addressed, liveness trade-off | **Policy accepted and documented** — exit freeze during stale feeds | this document + `docs/OPERATIONAL_RUNBOOK.md` |

At the baseline the review counted 10 addressed, 1 partial, and 7 open. After
this remediation, all 18 findings are either addressed or have an explicitly
documented residual/policy decision; no finding is silently marked closed.
Findings already addressed at `4af5d77` (H01, H02, H03, H04, M01, M02, M03, I01)
were not changed except where a shared code path required it.

---

## 2. Per-finding remediation

### C01 — Rebalance churn through a single pool

**Change.** `IndexBase._executeSwapSteps` now validates every swap step before
execution:

- `tokens.length == pools.length + 1` (one pool per hop; rejects empty paths);
- `MAX_HOPS_PER_STEP = 4`;
- no pool may appear twice within the same step;
- the step's first and last tokens may not be identical.

The existing cumulative turnover cap (1.5× the weight gap) remains the notional
bound. Together, these checks bound the number of fee-paying hops per unit of
declared notional and block the direct `A → B → A` round trip.

**Tests.** `test/IndexFacets/unit/IndexFacetTest.t.sol` and
`test/IndexFacets/invariant/IndexFacetInvariant.t.sol` cover the hop cap, duplicate
pools, circular endpoints, malformed path lengths, and the existing turnover-cap
cases.

**Accepted residual.**

- The number of steps in one rebalance is still unbounded. Each step's declared
  input is charged against the cumulative turnover cap, so splitting a capped
  notional across more steps does not increase the maximum fee leakage per unit of
  notional beyond the 4-hop allowance; it does increase gas and the number of
  fee-paying events for the same total notional.
- Pool uniqueness is enforced only within a step; the same pool may appear in
  different steps, but each appearance is charged against the cumulative cap.
- The cap remains notional-per-step, not notional-per-hop. With a 4-hop step the
  worst-case fee leakage per unit of charged notional is roughly four pool fees.
- Empty unwind step arrays are still permitted. `unwindAndDisconnect` then relies
  on its residue check, which reverts if any non-USDC component remains.

This residual is a deliberate trade-off: per-hop notional accounting would require
changing the swap-instruction semantics and every DEX facet, and the daily
value-loss guard already reverts rather than realising a loss above
`MAX_VALUE_LOSS_BPS`. It should be revisited if the turnover margin or the daily
guard is widened.

### C02 — Former owner allowance survives ownership transfer

**Change.**

- New `ApproveStorage` diamond storage tracks every `(token, spender)` pair
  granted through `ApproveFacet.approveTokens`.
- `ApproveFacet.revokeTokens(tokens, spender)` zeroes allowances and clears the
  tracked entries. It accepts any non-zero spender, so it can revoke a retired
  Rebalancer or a legacy arbitrary spender.
- `OwnershipBase._transferOwnership` clears every tracked approval before writing
  the new owner. Clearing is fail-closed: a token that rejects the zero approval
  blocks the transfer until the old owner cleans up.
- `storage-registry.json` registers the new `ApproveStorage` layout, and
  `UpgradeBase` validates its layout version during upgrades (`7cc51fe`). The
  version is initialised on the first `approveTokens` call.

**Tests.** `test/garden/utilityFacets/ApproveFacet.t.sol` covers grant/revoke,
re-approval, zero-address rejection, transfer-time clearing, and the former owner
being unable to pull after transfer.
`test/garden/facets/baseFacets/ownership/unit/OwnershipFacet.t.sol` covers the
transfer path. `test/garden/facets/baseFacets/upgrade/unit/Upgrade.t.sol` corrupts
the stored `ApproveStorage` layout version and asserts the upgrade reverts with
`UpgradeFacet_StorageLayoutMismatch`. Storage collision and registry scripts pass.

**Migration note.** Allowances granted by a facet that predates `ApproveStorage`
are not enumerable on-chain. Before upgrading a garden that was deployed under the
old facet, the owner must sweep known spenders with
`revokeTokens(tokens, oldSpender)`. Treat any garden with an unknown pre-upgrade
allowance as at risk. After an ownership transfer the new owner must re-approve the
canonical Rebalancer; the transfer intentionally clears that allowance too.

### M04 — INACTIVE does not stop `cumulativeRebalance`

**Change.** `Rebalancer` stores an immutable `IProtocolStatus PROTOCOL_STATUS`
(final constructor argument, zero address rejected). `cumulativeRebalance` reverts
with `Rebalancer_ProtocolInactive` when the status is `INACTIVE`. `UPGRADES_DISABLED`
is treated as an active protocol and does not block rebalances.

**Tests.** `test/rebalancer/unit/RebalancerTest.t.sol` covers an inactive first
call, a pause between batches (cursor does not advance; the round resumes after
reactivation), `UPGRADES_DISABLED`, and the zero-address constructor guard.

**Residual.** The check runs at the start of each `cumulativeRebalance` call. A
batch already executing is not interrupted mid-call; the next batch call is
blocked. The cursor/round state is not advanced while paused.

### M05 — Empty rebalance burns the cooldown

**Change.** `_rebalance` reverts with `IndexFacet_EmptyRebalance` when
`steps.length == 0`. The check is placed after the existing intent, block-delay,
interval, and expiry guards, before any swap or state-clearing work, so the pending
intent and `lastRebalanceTimestamp` are untouched.

**Tests.** `test/IndexFacets/unit/IndexFacetTest.t.sol` asserts the revert and that
the intent/cooldown state is unchanged.

**Accepted residual.** A structurally valid but economically negligible step (for
example a 1-wei exact-input swap with `amountOut = 0`) still passes the empty-step
check and can clear the intent and start the 24-hour cooldown when the garden is
already within the 2% `BALANCE_THRESHOLD_BPS`. If the garden is outside that band,
the dust step fails `_verifyBalancesMatchTargets` and the transaction reverts
without changing state. This is the same griefing shape as the original M05, but
its effect is limited to gardens that are already within tolerance. A minimum
turnover rule would change the semantics for legitimate small rebalances and was
not added; revisit it if the 2% balance threshold is widened.

### L02 — Selector moved between modules bricks `upgrade()`

**Change.** `UpgradeBase._collectRemovedSelectors` now consults `FacetRegistry`
before emitting a diamond `Remove`. If a selector is still registered to any module
(including `BASE_MODULE`), it is skipped; only selectors fully unregistered from
the registry are removed from the diamond.

**Tests.** `test/garden/facets/baseFacets/upgrade/unit/Upgrade.t.sol` adds a
registry-move regression. A negative control against the old code reproduces the
permanent revert.

**Residual.** This is a pre-deployment fix. A garden that already entered the
broken state under the old facet cannot be repaired by calling the reverting
`upgrade()` path; deployment/migration must ensure no garden is in that state.

### L03 — Factory owner getters return the creator forever

**Change.**

- `getGardenOwner` and `getGardenInfo` read `IERC173(garden).owner()` live, falling
  back to the creator record only if the garden no longer exposes `owner()`.
- New `getGardensOwnedBy(user)` and `getGardensOwnedByCount(user)` enumerate
  gardens by current owner.
- `getUserGardens`, `getUserGardenCount`, `getUserGardensByType`, and
  `getUserGardensByTypeCount` remain creator-indexed; their interface
  documentation now says so explicitly.

**Tests.** `test/factory/unit/GardenTypeViews.t.sol` covers transfer visibility,
live owner enumeration, and the creation-time index semantics.

### I02 — Non-8-decimal feed inflates component value

**Change.** `IndexComponentRegistry.registerComponents` rejects any feed whose
`decimals()` is not exactly 8 with
`IndexComponentRegistry__InvalidPriceFeedDecimals`. The registry stores the
validated value.

**Tests.** `test/indices/unit/IndexComponentRegistry.t.sol` covers the rejection;
mock feeds and valuation fixtures were normalised to 8 decimals.

**Deployment gate.** Existing registry entries are not revalidated by the
registration gate. A migration/upgrade must verify every already-registered
component reports 8 decimals (or re-register it) before enabling valuation.

### I03 — Camelot V3 exact-output ABI

**Change.** The Camelot exact-output-single call now uses the router's 8-field ABI
with `uint24 fee`. The fee is read from the Algebra pool's `globalState()` third
field, not Uniswap V3's `fee()`, which the deployed Camelot pools do not implement.
The multi-hop exact-output path is encoded in reverse (`tokenOut … tokenIn`) for
the router. Quotes now also read the dynamic fee from `globalState()` and the TWAP
from `getTimepoints()` (the Algebra equivalent of `observe()`), so the quote path
no longer reverts on the deployed pools.

**Tests.** `test/garden/utilityFacets/arbitrumOne/camelotV3/CamelotV3PathEncoding.t.sol`
asserts the selector, struct field order, reversed path encoding, and the
`globalState()`/`getTimepoints()` reads.
`test/garden/utilityFacets/arbitrumOne/fork/DexFacetFork.t.sol` executes a real
exact-output single-hop WETH→USDC swap and a quoted exact-input swap against the
canonical Camelot V3 pool on an Arbitrum One fork; both pass.

### I04 — Uniswap V3 exact-output path order

**Change.** Both Arbitrum One and Ethereum `UniswapV3Base` encode exact-output
paths in reverse (`tokenN, feeN-1, …, token0`). Exact-input encoding is unchanged.

**Tests.** `test/garden/utilityFacets/arbitrumOne/uniswapV3/UniswapV3PathEncoding.t.sol`
and the Ethereum equivalent assert the reversed encoding.

**Residual.** I04 is validated by deterministic ABI/encoding tests only. No live
fork swap against the deployed Uniswap routers was run in this remediation. Run
the existing fork suites with an RPC endpoint before enabling exact-output routes
in production.

### L01 — Stale-feed liveness policy

**Decision.** Accept the exit freeze. Strict reads must not price a connection,
deposit, fee settlement, or exit from a stale or deviation-rejected record. During
a feed outage the affected operations revert until a fresh round lands or the DAO
force-resyncs. This is documented, with monitoring and recovery steps, in
[`docs/OPERATIONAL_RUNBOOK.md`](./OPERATIONAL_RUNBOOK.md).

No code change was made for L01 in this remediation; the strict-read behaviour was
already present at `4af5d77`. The policy choice is the remediation.

---

## 3. Verification

Targeted suites run on the merged branch:

| Suite | Result |
|---|---|
| Full non-fork suite (`--no-match-path 'test/{e2e,rebalancer/fork}/**'`) | 919 passed, 0 failed, 4 skipped |
| `test/IndexFacets/**` | 121 passed |
| `test/rebalancer/unit/**` | 80 passed |
| `test/rebalancer/fuzz/**` | 19 passed |
| `test/rebalancer/invariant/**` | 10 passed |
| `test/factory/**` | 113 passed |
| `test/indices/**` | 78 passed, 1 skipped |
| `test/garden/utilityFacets/**` | 25 passed, 3 skipped |
| `test/garden/utilityFacets/ApproveFacet.t.sol` | 15 passed |
| `test/garden/utilityFacets/arbitrumOne/camelotV3/CamelotV3PathEncoding.t.sol` | 6 passed |
| `test/garden/facets/baseFacets/upgrade/**` | 51 passed |
| `test/fizz/**` | 6 passed |
| Camelot V3 live fork (`testFork_CamelotV3_ExactOutputSingle`, `testFork_CamelotV3_SwapWithDeadlineZero`) | 2 passed |
| `test/check_storage_slot_collisions.sh src/` | pass |
| `test/check_storage_registry.sh` | pass |
| `forge fmt --check` on changed Solidity files | pass |

Fork tests (`test/rebalancer/fork/**`) and the E2E simulation were not run here
because they require an RPC endpoint / the `e2e` profile. They compile as part of
`forge build`. The two Camelot V3 fork tests listed above were run explicitly with
`RPC_URL_ARBITRUM=https://arb1.arbitrum.io/rpc`; the remaining fork tests skip
without that variable.

The full non-fork suite was run before the final three additive tests (the
`ApproveFacet` layout-version test and the two Camelot pool-state tests). Those
suites pass separately as listed above; the full-suite row is otherwise
representative of the final tree.

Reproduce with:

```bash
forge build
forge test --match-path 'test/IndexFacets/**'
forge test --match-path 'test/rebalancer/unit/**'
forge test --match-path 'test/rebalancer/fuzz/**'
forge test --match-path 'test/rebalancer/invariant/**'
forge test --match-path 'test/factory/**'
forge test --match-path 'test/indices/**'
forge test --match-path 'test/garden/utilityFacets/**'
forge test --match-path 'test/garden/utilityFacets/arbitrumOne/camelotV3/*.t.sol'
forge test --match-path 'test/garden/facets/baseFacets/upgrade/**'
forge test --match-path 'test/fizz/**'
RPC_URL_ARBITRUM=https://arb1.arbitrum.io/rpc forge test \
  --match-path 'test/garden/utilityFacets/arbitrumOne/fork/DexFacetFork.t.sol' \
  --match-test 'testFork_CamelotV3_(SwapWithDeadlineZero|ExactOutputSingle)'
bash test/check_storage_slot_collisions.sh src/
bash test/check_storage_registry.sh
```

---

## 4. Deployment checklist

1. Deploy `Rebalancer` with the new final `protocolStatus` argument.
2. Deploy the new `ApproveFacet` and register `ApproveStorage` (already in
   `storage-registry.json`).
3. For any garden upgraded from an older facet, enumerate known `Approval` logs
   and call `revokeTokens(tokens, oldSpender)` for every non-canonical spender.
4. Verify every registered price feed reports 8 decimals before enabling
   valuation; the registration gate does not retroactively validate entries.
5. Run the Uniswap V3 exact-output fork route before enabling it. The Camelot V3
   exact-output single-hop and quote paths were validated on a live Arbitrum fork.
6. Confirm `ProtocolStatus` ownership and pause runbook with the DAO; `INACTIVE`
   blocks all garden calls, not only rebalances.

---

## 5. Remaining risk register

| Risk | Status | Owner / trigger |
|---|---|---|
| C01 step-count and cross-step pool reuse residual | Accepted | Revisit if turnover margin or daily loss guard changes |
| C02 legacy allowances not enumerable | Migration action | Deployment/upgrade runbook |
| L01 exit freeze during stale feeds | Accepted policy | Operations runbook |
| I03/I04 not fork-tested | I03 exact-output/quote fork-validated; I04 still unit-only | Pre-enablement Uniswap fork run |
| L02 already-bricked gardens cannot be repaired on-chain | Pre-deployment only | Deployment gate |
| DAO key / timelock centralisation (review §4.4) | Out of scope of this remediation | Governance deployment |

---

## 6. Review action-list closure

| Priority | Action | Status |
|---|---|---|
| P0 | Re-test C01 with nonzero gap and long multi-hop path; add per-hop accounting or hop/pool cap | **Closed with accepted residual** — hop cap, pool dedup, circular rejection; tests added |
| P0 | Fix M04 and M05 | **Closed** |
| P0 | Fix L02 before deployment | **Closed** |
| P1 | Add `revokeTokens` and clear allowances on `transferOwnership` | **Closed** |
| P1 | Fix L03 and I02 | **Closed** |
| P2 | Decide the L01 liveness policy and document it | **Closed** — option (a) accepted and documented |
| P2 | Fix I03/I04 before enabling exact-output | **I03 closed and fork-validated; I04 code closed** — Uniswap fork verification remains |
| P2 | Request a retest addendum and a PoC repository link | External action; not a code change |
