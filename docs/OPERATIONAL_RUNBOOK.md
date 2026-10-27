# Operational Runbook — Oracle Staleness and Exit Freeze (L01)

| Item | Value |
|---|---|
| Applies to | `IndexComponentRegistry`, index gardens, `Rebalancer`, fee settlement |
| Finding | L01 — strict price reads do not revert on a stale feed |
| Decision | **Option (a): accept the exit freeze during a stale or rejected feed** |
| Owner | DAO / protocol operations |
| Last updated | 26 October 2026 |

---

## 1. Policy

Strict price consumers must never price a persisted fee basis, a deposit, a fee
settlement, or an exit from a stale or deviation-rejected oracle record. If a
component feed is stale, the affected operation reverts and the garden stays in its
current state.

This is a deliberate liveness-for-safety trade-off:

- **Safety:** no user is exited, or charged a fee, at a price the protocol cannot
  validate. A stale price cannot silently become someone's fee basis.
- **Liveness:** during a feed outage, a connected user cannot exit that garden
  until the feed publishes a fresh round or the DAO force-resyncs a fresh but
  deviating round.
- **Scope:** the freeze is per component symbol and per operation. It is not a
  protocol-wide pause, and USDC-only actions remain available.

The alternative policies considered were a bounded grace period and a DAO-settled
fallback exit. Both would require new accounting and loss-allocation rules; option
(a) keeps the existing invariant that no exit is priced from an unvalidated
record.

---

## 2. What freezes and what stays live

### Frozen while a component feed is stale or deviation-rejected

| Operation | Reason |
|---|---|
| `connectToIndex` / `connectToIndexWithOnboarder` | Records the fee basis with `fetchPriceStrict` |
| Component-token deposit crediting (`recordDeposit` for a non-USDC symbol) | Persists the deposit's USDC value |
| `unwindAndDisconnect` (the only feeable exit) | Values the exit guard and settles fees from strict reads |
| Fee settlement / session NAV valuation | `FeeBase` uses `fetchPriceStrict` |
| `Rebalancer.cumulativeRebalance` | Snapshots component and USDC prices strictly |
| `forceResync` without a fresh valid round | There is no market price to resync to |

### Still live

- USDC-only deposits into an already-connected garden (USDC is valued at 1:1 and
  does not use a feed).
- Token transfers, `revokeTokens`, ownership transfer, and other non-oracle garden
  functions. `approveTokens` still follows its normal fee-session containment and
  may revert while a feeable session is active.
- User-initiated `rebalance` may still run on the registry's cached price: its
  intent snapshot uses the lenient `fetchPrice`. It is not an exit and does not
  persist a fee basis. If the cached price is stale, treat the resulting weights as
  indicative and avoid using that rebalance to justify an exit.
- Reading balances, weights, events, and registry state.

> **Do not call `ProtocolStatus.deactivateProtocol()` for a single feed outage.**
> `INACTIVE` makes the Garden fallback revert **all** calls, including transfers
> and exits, and is broader than the per-symbol strict-read freeze.

---

## 3. Detection and monitoring

### Events to alert on

| Event | Source | Meaning | Suggested alert |
|---|---|---|---|
| `FeedStale(token, lastPriceTimestamp, age, servedPrice)` | `IndexComponentRegistry` | Lenient read served a cached price older than the heartbeat | Page if `age >= heartbeat` for any component in an active index |
| `PriceDeviationRejected(token, price, emaPrice, deviationBps, maxDeviationBps)` | `IndexComponentRegistry` | Fresh round outside the deviation band; cached price served | Warn on first, page if `consecutiveRejections` grows or persists near `deviationTimeout` |
| `OracleFailureThresholdReached(feed, reason)` | `IndexComponentRegistry` | 10 consecutive `latestRoundData` failures | Page |
| `DeviationTimeoutAccepted(token, price, previousEmaPrice)` | `IndexComponentRegistry` | A sub-100% deviation persisted past `deviationTimeout` and was auto-accepted | Info; confirm the move was genuine |
| `FeedResynced(token, price, previousEmaPrice)` | `IndexComponentRegistry` | DAO force-resynced a fresh round | Info; confirm post-incident review |
| `Rebalancer_ProtocolInactive` / `Garden_ProtocolIsInactive` reverts | `Rebalancer` / `Garden` | Protocol is `INACTIVE` | Page; this is a governance action, not a feed symptom |

### Metrics to dashboard

For every registered component symbol:

- `age = block.timestamp - getOracleRecord(symbol).timestamp`
- `heartbeat = getComponentHeartbeat(symbol)`
- `age / heartbeat` ratio (alert at 0.8 and 1.0)
- `getOracleRecord(symbol).isFeedWorking`
- `getOracleRecord(symbol).consecutiveRejections`
- `getOracleRecord(symbol).firstDeviationAt` (non-zero = unresolved rejection)
- `getFeedFailures(feedAddress)`
- `getMaxDeviationBps(symbol)` and `getDeviationTimeout()`

Also monitor failed user transactions with `IndexComponentRegistry__FeedFrozenError`
or `IndexComponentRegistry__PriceDeviationTooHigh`; a cluster of these is the
first user-visible symptom of an exit freeze.

> Events emitted inside a reverted transaction are rolled back. If a feed is only
> touched by strict consumers, a failing `fetchPriceStrict` may leave no `FeedStale`
> log behind. Alert on the age/heartbeat metric and the failed-transaction cluster,
> not only on the event stream.

---

## 4. Triage

### Step 1 — Identify the affected symbol and state

```bash
# Replace with the deployed registry and the bytes32 symbol, e.g. bytes32("WETH")
REGISTRY=$INDEX_COMPONENT_REGISTRY
SYMBOL=$(cast format-bytes32-string WETH)

cast call "$REGISTRY" "getOracleRecord(bytes32)(uint128,uint48,uint48,uint8,bool,uint80,uint128,uint48,uint48,uint32)" "$SYMBOL"
cast call "$REGISTRY" "getComponentHeartbeat(bytes32)(uint256)" "$SYMBOL"
cast call "$REGISTRY" "getMaxDeviationBps(bytes32)(uint256)" "$SYMBOL"
cast call "$REGISTRY" "getDeviationTimeout()(uint256)"
cast call "$REGISTRY" "getComponentSymbolToPriceFeedAddress(bytes32)(address)" "$SYMBOL"
```

Classify:

| Observation | State | Go to |
|---|---|---|
| `timestamp` older than `heartbeat`, no fresh round | **Stale feed** | Step 2 |
| Fresh round, `firstDeviationAt != 0`, deviation within auto-accept bound | **Deviation pending** | Step 3 |
| Fresh round, deviation ≥ `MAX_AUTO_ACCEPT_DEVIATION_BPS` (10,000 bps / 100%) | **Large deviation** | Step 4 |
| `getFeedFailures(feed) >= FAILURE_THRESHOLD` or `latestRoundData` reverts | **Broken feed** | Step 5 |
| Fresh round within band | **Recovered** | Step 6 |

### Step 2 — Stale feed (no fresh round)

1. Check the aggregator directly:
   ```bash
   cast call "$FEED" "latestRoundData()(uint80,int256,uint256,uint256,uint80)"
   cast call "$FEED" "decimals()(uint8)"
   ```
   Confirm `decimals() == 8`. A non-8-decimal feed is a deployment error; do not
   widen bands to compensate.
2. Check the Chainlink status page and the aggregator's recent rounds. Common
   causes are a paused aggregator, a deprecated feed, or a transport delay.
3. If the feed is healthy but simply late, wait. `forceResync` cannot help: it
   requires a fresh valid round.
4. If the feed is deprecated or will not recover, go to Step 5.

**Do not** call `forceResync` repeatedly on a stale feed; it will revert with
`IndexComponentRegistry__InvalidFeedResponseError` and wastes gas.

### Step 3 — Deviation pending (fresh round, sub-100% deviation)

1. Confirm the move is genuine (market data, issuer event, split/redenomination).
2. If genuine, wait for `deviationTimeout` (default 1 hour; bounds 30 minutes to
   24 hours). The next read after the timeout auto-accepts the price and reseeds
   the EMA, emitting `DeviationTimeoutAccepted`.
3. If the band is genuinely misconfigured for this asset, the DAO may widen it with
   `setMaxDeviationBps(symbol, bps)` (100–50,000 bps). Do not widen it merely to
   clear an alert; document the rationale.
4. If the move is a unit change or broken feed, go to Step 4.

### Step 4 — Large deviation (≥100% relative to EMA)

The protocol never auto-accepts a deviation of 100% or more. A fresh valid round
must be force-resynced by the DAO:

```bash
# DAO only; requires a fresh valid round and bypasses the deviation guard
cast send "$REGISTRY" "forceResync(bytes32)" "$SYMBOL" --account "$DAO_ACCOUNT"
```

Before sending:

- Confirm the fresh round is valid (`answer > 0`, `answeredInRound >= roundId`,
  timestamp not in the future, feed `decimals() == 8`).
- Confirm the move is a genuine repricing, not a compromised or misconfigured
  feed. `forceResync` reseeds the EMA and cannot be undone by a simple revert.
- Announce the action in the incident channel; it changes the reference price for
  every garden holding that component.

### Step 5 — Broken or deprecated feed

Replacing a feed is a coordinated DAO action, not a hot fix:

1. Identify every index that references the symbol and every garden connected to
   those indices.
2. Prepare a replacement aggregator with 8 decimals and a heartbeat between 30
   minutes and 26 hours.
3. `unregisterComponents([symbol])` deletes the component and its oracle record;
   `registerComponents` then adds the replacement. This changes the symbol's feed
   for all consumers. Coordinate the transaction with index maintenance and
   communicate the maintenance window.
4. If the symbol must remain unavailable, users cannot exit that index until a
   feed is restored. This is the accepted L01 policy; do not deactivate the whole
   protocol.
5. After re-registration, verify a strict read succeeds before announcing recovery.

### Step 6 — Recovery verification

```bash
# Simulate a strict read (executes against current state; does not persist)
cast call "$REGISTRY" "fetchPriceStrict(bytes32)(uint256)" "$SYMBOL"

# Confirm the record is fresh
cast call "$REGISTRY" "getOracleRecord(bytes32)(uint128,uint48,uint48,uint8,bool,uint80,uint128,uint48,uint48,uint32)" "$SYMBOL"
```

Then run a small dry-run exit/deposit through the normal UI or a forked
simulation. Only announce recovery after:

- every affected symbol's `fetchPriceStrict` succeeds;
- `firstDeviationAt == 0` and `isFeedWorking == true`;
- a test exit and a test deposit both succeed; and
- the incident channel confirms no pending DAO action.

---

## 5. Communication templates

### Initial notice (internal)

> Oracle incident: `<SYMBOL>` feed is `<stale|deviating|failing>`. Strict reads are
> reverting, so exits and component deposits for gardens holding `<SYMBOL>` are
> temporarily unavailable. USDC-only actions and transfers remain available. We are
> monitoring the aggregator and will update within 30 minutes.

### User-facing notice

> Some index gardens are temporarily unable to process exits because a price feed
> is unavailable. Your balances and positions are unchanged. We are waiting for the
> oracle to publish a fresh price (or for the DAO to complete a verified resync).
> We will post an update by `<time>`.

### Recovery notice

> The `<SYMBOL>` price feed has recovered and strict pricing is passing. Exits and
> deposits for affected gardens are available again. A post-incident review will
> follow within five business days.

---

## 6. Escalation

| Condition | Escalate to | Target response |
|---|---|---|
| Any component `age >= heartbeat` in an active index | On-call operator | 15 minutes |
| `OracleFailureThresholdReached` or `latestRoundData` reverts | On-call + DAO signers | 30 minutes |
| Deviation ≥100% or suspected compromised feed | DAO signers + security lead | Immediate; do not force-resync before review |
| Feed deprecated / no replacement available | DAO + index maintenance | Same day; communicate exit freeze |
| Suspected exploit or unauthorized registry change | Security lead + DAO | Immediate; consider `deactivateProtocol` only with full impact review |

---

## 7. DAO action reference

| Function | Contract | Effect | Cautions |
|---|---|---|---|
| `forceResync(bytes32 symbol)` | `IndexComponentRegistry` | Reseeds price and EMA to the latest fresh round, bypassing the deviation guard | Requires a fresh valid round; changes the reference price for all consumers; emits `FeedResynced` |
| `setMaxDeviationBps(bytes32 symbol, uint256 bps)` | `IndexComponentRegistry` | Changes the per-symbol deviation band (100–50,000 bps) | Does not clear an existing rejection by itself; next fresh read applies the new band |
| `setDeviationTimeout(uint256 seconds)` | `IndexComponentRegistry` | Changes the auto-accept timeout (30 minutes–24 hours) | Applies globally; shorter timeouts accept genuine moves faster but also accept bad prints faster |
| `registerComponents(Component[])` | `IndexComponentRegistry` | Adds components; rejects non-8-decimal feeds and stale/frozen feeds | Cannot re-register an existing symbol |
| `unregisterComponents(bytes32[] symbols)` | `IndexComponentRegistry` | Deletes components and oracle records | Breaks consumers of the symbol until re-registration; coordinate with indices |
| `deactivateProtocol()` | `ProtocolStatus` | Blocks **all** Garden fallback calls | Not a feed-level tool; exits and transfers also stop |

All DAO actions should go through the timelock/multisig process. Record the
transaction hash, rationale, and affected symbols in the incident log.

---

## 8. Post-incident review

Within five business days, record:

- root cause (aggregator pause, deprecation, transport, misconfiguration, or
  genuine market move);
- duration of the strict-read freeze and which symbols/indices were affected;
- whether `forceResync` or a band/timeout change was used, and why;
- user communications sent;
- whether the heartbeat, deviation band, or feed provider should change;
- any code or runbook follow-up.

The review should explicitly confirm that no exit was priced from a stale record
and that no allowance or fee basis was persisted during the incident.
