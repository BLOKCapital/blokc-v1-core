// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { IndexFactory } from "src/indices/IndexFactory.sol";
import { Index } from "src/indices/Index.sol";
import { IndexStorage } from "src/garden/facets/indexFacets/IndexStorage.sol";
import { FeeStorage } from "src/garden/facets/indexFacets/FeeStorage.sol";
import { FeeBase } from "src/garden/facets/feeBase/FeeBase.sol";
import {
    FeeFacet_FeeModuleNotConfigured,
    FeeFacet_FeeBasisNotRecorded,
    FeeFacet_UnwindReentrancy
} from "src/garden/facets/feeBase/FeeBase.sol";
import { IndexComponentRegistry } from "src/indices/IndexComponentRegistry.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { LibDiamond } from "src/garden/libraries/LibDiamond.sol";
import { IIndex, SwapStep, PendingIntent } from "src/garden/facets/indexFacets/IIndex.sol";
import { SwapInstruction } from "src/interfaces/ISwapInstruction.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";
import { IFeeRegistry } from "src/interfaces/IFeeRegistry.sol";
import { ITreasuryRegistry } from "src/interfaces/ITreasuryRegistry.sol";
import { IOnboarderRegistry } from "src/interfaces/IOnboarderRegistry.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when garden is not connected to an index
error IndexFacet_NotConnectedToIndex();

/// @notice Thrown when garden is already connected to an index
error IndexFacet_AlreadyConnectedToIndex();

/// @notice Thrown when index is not registered
error IndexFacet_IndexNotRegistered(address indexAddress);

/// @notice Thrown when pending intent interval hasn't passed
error IndexFacet_IntentIntervalNotPassed();

/// @notice Thrown when rebalance interval hasn't passed
error IndexFacet_RebalanceIntervalNotPassed();

/// @notice Thrown when no pending intent exists
error IndexFacet_NoPendingIntent();

/// @notice Thrown when balance is outside threshold after rebalance
error IndexFacet_BalanceOutsideThreshold(bytes32 symbol, uint256 current, uint256 target);

/// @notice Thrown when a swap call fails
error IndexFacet_SwapCallFailed(uint256 index, bytes reason);

/// @notice Thrown when swap selector is not whitelisted
error IndexFacet_SelectorNotWhitelisted(bytes4 selector);

/// @notice Thrown when swap call returns no data (selector not found)
error IndexFacet_SelectorNotFound(bytes4 selector);

/// @notice Thrown when a swap produces less output than the specified minimum
/// @param index The index of the swap call in the array
/// @param outputToken The expected output token
/// @param received The actual output received
/// @param minRequired The minimum output required
error IndexFacet_InsufficientSwapOutput(uint256 index, address outputToken, uint256 received, uint256 minRequired);

/// @notice Thrown when the pending intent has expired
error IndexFacet_IntentExpired();

/// @notice Thrown when total garden value decreased beyond acceptable threshold
error IndexFacet_ExcessiveValueLoss(uint256 valueBefore, uint256 valueAfter);

/// @notice Thrown when the unwind's cached price snapshot and the session's weight list
///         disagree in length (defensive — cannot happen with a deterministic getWeights())
error IndexFacet_OracleSnapshotMismatch();

/// @notice Thrown when a swap step's first or last path token is neither USDC nor a symbol
///         of the active session/intent — value moved there is invisible to the fee and
///         unwind accounting (external audit M02: off-universe value parking)
/// @param token The disallowed endpoint token
error IndexFacet_SwapTokenNotAllowed(address token);

/// @notice Thrown when a rebalance's cumulative declared input value exceeds 1.5x the
///         weight gap — honest routes turn over ~the gap, so anything beyond the margin
///         is churn (external audit C01: round-trip fee burn through one pool)
/// @param turnover The cumulative declared input value (USD 8 decimals)
/// @param cap The turnover cap (USD 8 decimals)
error IndexFacet_TurnoverCapExceeded(uint256 turnover, uint256 cap);

/// @notice Thrown on reentrant call to _rebalance
error IndexFacet_RebalanceReentrancy();

/// @notice Thrown when attempting to create a rebalance intent with zero total garden value
error IndexFacet_ZeroTotalValue();

/// @notice Thrown when rebalance is attempted in the same block as intent creation (flash loan protection)
error IndexFacet_IntentBlockDelayNotPassed();

/// @notice Thrown when the index module's protocol addresses have not been configured
error IndexFacet_ModuleNotConfigured();

/// @notice Thrown when configureIndexModule is called while the garden is connected to an index
///         or has a pending intent — re-pointing must happen on a disconnected garden
error IndexFacet_ConfigureRequiresDisconnected();

/// @notice Thrown when configureIndexModule is attempted before the FacetRegistry has
///         published the DAO's canonical index registries (fail-closed)
error IndexFacet_CanonicalIndexRegistriesNotSet();

/// @notice Thrown when configureIndexModule is called with an address that is not the DAO's
///         canonical registry (external audit H02: owner-chosen registries controlled the
///         fee layer's identity and price reads)
/// @param provided The address that was passed in
/// @param canonical The canonical address it must match
error IndexFacet_IndexRegistryNotCanonical(address provided, address canonical);

/// @notice Thrown when an onboarder address is not allowlisted in the OnboarderRegistry
/// @param onboarder The ineligible address
error IndexFacet_OnboarderNotEligible(address onboarder);

/// @notice Thrown when the fee module has not been configured but the operation requires it
error IndexFacet_FeeModuleNotConfigured();

/// @notice Thrown when the legacy fee-free disconnect is attempted on a session that has a
///         recorded fee basis — such sessions must exit through unwindAndDisconnect
error IndexFacet_UnwindRequired();

/// @notice Thrown when an unwind leaves a non-USDC component balance behind — the whole unwind
///         aborts (garden stays connected, basis untouched) rather than settle on a partial unwind
/// @param symbol The component symbol that remained
/// @param remaining The remaining balance
error IndexFacet_ComponentRemained(bytes32 symbol, uint256 remaining);

/**
 * @title IndexBase
 * @author BLOK Capital DAO
 * @notice Base contract for Index Facet, containing shared logic and internal functions for managing index connections
 * and rebalancing.
 * Handles interactions with the Index contract, retrieves target weights, and calculates rebalance actions.
 * The external functions are defined in the IndexFacet contract, which calls these internal functions to perform the
 * operations.
 *
 * @dev IMPORTANT: Index-type gardens hold index component tokens AND a deposit token (USDC).
 *      Value calculations (_calculateTotalValue, _calculateRebalanceValues, _verifyBalancesMatchTargets)
 *      account for both index component tokens and the USDC deposit token. USDC is not an index component
 *      (it has no target weight), but its balance is included in total portfolio value so that target
 *      allocations are computed against the full garden value. During rebalancing, USDC is swapped into
 *      index components, driving its balance toward zero. Any other non-index, non-USDC tokens held by the
 *      garden are invisible to these calculations and will NOT be protected by the MAX_VALUE_LOSS_BPS check.
 *
 *      Fee lifecycle: this module is the FIRST consumer of the garden-level fee layer (FeeBase).
 *      connectToIndex records the fee basis; unwindAndDisconnect sells all components to USDC and
 *      settles fees through the shared layer. The fee session itself (FeeStorage) is tool-agnostic —
 *      future wealth-management modules record and settle their own sessions the same way.
 */
abstract contract IndexBase is FeeBase {
    /// @notice Reads the deployer-configured protocol addresses, reverting loudly if the
    ///         module was never configured instead of silently calling address(0).
    function _protocolAddresses()
        internal
        view
        returns (address indexFactory, address indexComponentRegistry, address poolRegistry)
    {
        IndexStorage.Layout storage s = IndexStorage.layout();
        indexFactory = s.indexFactory;
        indexComponentRegistry = s.indexComponentRegistry;
        poolRegistry = s.poolRegistry;
        if (indexFactory == address(0) || indexComponentRegistry == address(0) || poolRegistry == address(0)) {
            revert IndexFacet_ModuleNotConfigured();
        }

        // Registry containment (external audit H02): the component registry drives the fee
        // layer's identity AND price reads (basis, unwind guard, residue check), so the
        // fee payer must never be able to choose it. Validate against the DAO's canonical
        // index registries published on the FacetRegistry — fail-closed while unset.
        (address canonicalFactory, address canonicalRegistry, address canonicalPool) =
            IFacetRegistry(LibDiamond.layout().facetRegistry).getCanonicalIndexRegistries();
        if (canonicalFactory == address(0)) revert IndexFacet_CanonicalIndexRegistriesNotSet();
        if (indexFactory != canonicalFactory) {
            revert IndexFacet_IndexRegistryNotCanonical(indexFactory, canonicalFactory);
        }
        if (indexComponentRegistry != canonicalRegistry) {
            revert IndexFacet_IndexRegistryNotCanonical(indexComponentRegistry, canonicalRegistry);
        }
        if (poolRegistry != canonicalPool) revert IndexFacet_IndexRegistryNotCanonical(poolRegistry, canonicalPool);
    }

    /// @notice Sets the protocol addresses the index module talks to. Owner-only (see IndexFacet),
    ///         called once by the deployer right after the facet is cut in. Re-configuring is only
    ///         allowed on a disconnected, intent-free garden so a live one can never be silently
    ///         re-pointed at different protocol components.
    function _configureIndexModule(
        address indexFactory,
        address indexComponentRegistry,
        address poolRegistry
    )
        internal
    {
        if (indexFactory == address(0) || indexComponentRegistry == address(0) || poolRegistry == address(0)) {
            revert IndexFacet_ModuleNotConfigured();
        }

        // Registry containment (external audit H02): the component registry drives the fee
        // layer's identity AND price reads (basis, unwind guard, residue check), so the
        // fee payer must never be able to choose it. Validate against the DAO's canonical
        // index registries published on the FacetRegistry — fail-closed while unset.
        (address canonicalFactory, address canonicalRegistry, address canonicalPool) =
            IFacetRegistry(LibDiamond.layout().facetRegistry).getCanonicalIndexRegistries();
        if (canonicalFactory == address(0)) revert IndexFacet_CanonicalIndexRegistriesNotSet();
        if (indexFactory != canonicalFactory) {
            revert IndexFacet_IndexRegistryNotCanonical(indexFactory, canonicalFactory);
        }
        if (indexComponentRegistry != canonicalRegistry) {
            revert IndexFacet_IndexRegistryNotCanonical(indexComponentRegistry, canonicalRegistry);
        }
        if (poolRegistry != canonicalPool) revert IndexFacet_IndexRegistryNotCanonical(poolRegistry, canonicalPool);
        IndexStorage.Layout storage s = IndexStorage.layout();
        if (s.indexAddress != address(0) || s.pendingIntent.active) {
            revert IndexFacet_ConfigureRequiresDisconnected();
        }
        s._storageLayoutVersion = IndexStorage.STORAGE_LAYOUT_VERSION;
        s.indexFactory = indexFactory;
        s.indexComponentRegistry = indexComponentRegistry;
        s.poolRegistry = poolRegistry;
    }

    /// @notice Connects the garden to an index for automated rebalancing (no onboarder bound).
    /// @param indexAddress The address of the index contract to connect to.
    function _connectToIndex(address indexAddress) internal {
        _connectToIndex(indexAddress, address(0));
    }

    /// @notice Connects the garden to an index, records the fee basis, and binds the onboarder.
    /// @param indexAddress The address of the index contract to connect to.
    /// @param onboarder The onboarder to bind for this session (address(0) = none). Must be
    ///        allowlisted in the OnboarderRegistry — this is what prevents an investor writing
    ///        arbitrary addresses (including their own) in as onboarder.
    function _connectToIndex(address indexAddress, address onboarder) internal {
        (address indexFactory,,) = _protocolAddresses();
        if (!IndexFactory(indexFactory).isIndexRegistered(indexAddress)) {
            revert IndexFacet_IndexNotRegistered(indexAddress);
        }

        FeeStorage.Layout storage fs = FeeStorage.layout();

        // Fee sessions are mandatory: every new session must record a basis and settle
        // through the fee layer. Without this, an unconfigured garden could connect, profit,
        // and exit fee-free via the legacy disconnect (audit: opt-out cycle).
        if (fs.feeRegistry == address(0)) revert FeeFacet_FeeModuleNotConfigured();

        // Onboarder eligibility is DAO-gated: only allowlisted addresses may be bound
        if (onboarder != address(0)) {
            if (!IOnboarderRegistry(fs.onboarderRegistry).isOnboarderEligible(onboarder)) {
                revert IndexFacet_OnboarderNotEligible(onboarder);
            }
        }

        // Store the connected index address FIRST — the fee basis's NAV hook reads it
        // (state writes before external call — checks-effects-interactions)
        IndexStorage.layout().indexAddress = indexAddress;
        LibDiamond.layout().isConnectedToIndex = true;

        // Record the fee basis (no-op-safe when the fee module is unconfigured: the session
        // stays legacy — basisRecorded stays false — and exits fee-free via disconnectFromIndex)
        _recordBasis(indexAddress, onboarder);

        Index(indexAddress).connectGardenToIndex();
        emit IIndex.IndexConnected(indexAddress);
    }

    /// @notice Disconnects the garden from its currently connected index. Feeable sessions
    ///         (with a recorded basis) must exit through unwindAndDisconnect — this legacy
    ///         fee-free path exists only for sessions recorded before the fee layer existed.
    function _disconnectFromIndex() internal {
        IndexStorage.Layout storage s = IndexStorage.layout();
        address indexAddress = s.indexAddress;
        if (indexAddress == address(0)) revert IndexFacet_NotConnectedToIndex();

        if (FeeStorage.layout().basisRecorded) revert IndexFacet_UnwindRequired();

        // Clear pending intent so a stale intent cannot be executed after reconnecting to a different index
        s.pendingIntent.active = false;

        // Clear the connected index address (state writes before external call — checks-effects-interactions)
        s.indexAddress = address(0);
        LibDiamond.layout().isConnectedToIndex = false;

        Index(indexAddress).disconnectGardenFromIndex();
        emit IIndex.IndexDisconnected(indexAddress);
    }

    /// @notice Unwinds every non-USDC index component to USDC, settles the fee session
    ///         (performance/protocol fees + onboarder cut), and disconnects the garden — atomic
    ///         from the investor's point of view. If any stage aborts (value loss, residual
    ///         component, failed swap), the whole tx reverts and the garden stays connected with
    ///         its basis untouched.
    /// @param steps The unwind swap steps (caller/CRE-supplied; PoolRegistry-resolved, DEX-
    ///        allowlisted, per-swap min-out enforced, batch value-loss capped at 0.5%).
    function _unwindAndDisconnect(SwapStep[] calldata steps) internal {
        FeeStorage.Layout storage fs = FeeStorage.layout();

        if (fs.unwinding) revert FeeFacet_UnwindReentrancy();
        fs.unwinding = true;

        IndexStorage.Layout storage s = IndexStorage.layout();
        address indexAddress = s.indexAddress;
        if (indexAddress == address(0)) revert IndexFacet_NotConnectedToIndex();
        if (!fs.basisRecorded) revert FeeFacet_FeeBasisNotRecorded();
        if (fs.feeRegistry == address(0)) revert FeeFacet_FeeModuleNotConfigured();

        (, address componentRegistryAddress,) = _protocolAddresses();
        IndexComponentRegistry componentRegistry = IndexComponentRegistry(componentRegistryAddress);

        (bytes32[] memory symbols,) = Index(indexAddress).getWeights();

        // Cache component prices once (same-block oracle snapshot for the whole unwind).
        // Strict reads: a deviation-rejected or stale feed reverts the unwind up front with
        // the true reason instead of silently pricing the exit guard off a stale-high value.
        uint256[] memory cachedPrices = new uint256[](symbols.length);
        for (uint256 i = 0; i < symbols.length; i++) {
            cachedPrices[i] = componentRegistry.fetchPriceStrict(symbols[i]);
        }

        // Basis snapshot before the unwind (USDC-denominated) — valued from the same snapshot
        // as the guard (mirrors the _rebalance M4 fix: no Chainlink round can land mid-NAV)
        uint256 valueBefore = _calculateSessionUsdcNav(cachedPrices);

        // Sell every non-USDC component to USDC. Endpoints restricted to weight symbols +
        // USDC (M02); turnover exempt — the unwind legitimately converts 100% of NAV and
        // is already bounded by its own 0.5% exit guard + the residue check.
        (address[] memory allowedTokens, uint256[] memory allowedPrices) =
            _allowedEndpoints(componentRegistry, symbols, cachedPrices);
        _executeSwapSteps(steps, allowedTokens, allowedPrices, type(uint256).max);

        // Residue check: every non-USDC component must be fully converted, otherwise fees
        // would settle on a partial unwind (safe direction: revert → garden stays connected)
        for (uint256 i = 0; i < symbols.length; i++) {
            if (symbols[i] == _USDC_SYMBOL) continue;
            address token = componentRegistry.getComponentAddress(symbols[i]);
            uint256 remaining = IERC20(token).balanceOf(address(this));
            if (remaining != 0) revert IndexFacet_ComponentRemained(symbols[i], remaining);
        }

        // Realized USDC at exit — the unwind must not lose more than MAX_VALUE_LOSS_BPS
        uint256 exitUSDC = IERC20(IndexStorage.USDC_ADDRESS).balanceOf(address(this));
        uint256 minAcceptableExit =
            Math.mulDiv(valueBefore, 10_000 - IndexStorage.MAX_VALUE_LOSS_BPS, 10_000, Math.Rounding.Floor);
        if (exitUSDC < minAcceptableExit) {
            revert IndexFacet_ExcessiveValueLoss(valueBefore, exitUSDC);
        }

        // Fee split — rates per the session's applyRateAt snapshot (ConnectLock default: the
        // schedule locked at connect; DisconnectLive: live registry rates read now)
        FeeStorage.FeeSchedule memory schedule = fs.lockedSchedule;
        if (schedule.applyRateAtMode == FeeStorage.APPLY_RATE_DISCONNECT_LIVE) {
            (uint256 performanceFeeBps, uint256 protocolFeeBps, uint256 onboarderShareBps,,) =
                IFeeRegistry(fs.feeRegistry).getFeeSchedule();
            schedule = FeeStorage.FeeSchedule({
                performanceFeeBps: uint16(performanceFeeBps),
                protocolFeeBps: uint16(protocolFeeBps),
                onboarderShareBps: uint16(onboarderShareBps),
                applyRateAtMode: FeeStorage.APPLY_RATE_DISCONNECT_LIVE
            });
        }

        (uint256 profit, uint256 performanceFee, uint256 protocolFee, uint256 onboarderCut, uint256 treasuryTotal) =
            _computeFeeSplit(exitUSDC, fs.entryUSDC, schedule, fs.onboarderAddress);

        // Settle fees BEFORE clearing session state (checks-effects-interactions)
        _settleFees(profit, performanceFee, protocolFee, onboarderCut, treasuryTotal);

        // Clear index session state + fee session state
        s.pendingIntent.active = false;
        s.indexAddress = address(0);
        LibDiamond.layout().isConnectedToIndex = false;
        _clearBasis(exitUSDC);
        fs.unwinding = false;

        Index(indexAddress).disconnectGardenFromIndex();

        emit IIndex.GardenUnwound(address(this), exitUSDC);
        emit IIndex.FeesSettled(address(this), profit, performanceFee, protocolFee, onboarderCut, treasuryTotal);
        emit IIndex.Disconnected(address(this), indexAddress);
    }

    /// @notice Creates a rebalance intent by computing current vs target allocations.
    /// @dev Enforces both intent and rebalance interval cooldowns before allowing a new intent.
    function _rebalanceIntent() internal {
        IndexStorage.Layout storage s = IndexStorage.layout();

        // Check connected
        if (s.indexAddress == address(0)) {
            revert IndexFacet_NotConnectedToIndex();
        }

        // Check intent interval (INTENT_INTERVAL > INTENT_EXPIRY so a still-valid pending
        // intent can never be overwritten at the expiry boundary)
        if (block.timestamp < s.lastIntentTimestamp + IndexStorage.INTENT_INTERVAL) {
            revert IndexFacet_IntentIntervalNotPassed();
        }

        // Check rebalance interval
        if (block.timestamp < s.lastRebalanceTimestamp + IndexStorage.REBALANCE_INTERVAL) {
            revert IndexFacet_RebalanceIntervalNotPassed();
        }

        (, address componentRegistryAddress,) = _protocolAddresses();
        IndexComponentRegistry componentRegistry = IndexComponentRegistry(componentRegistryAddress);

        // Get target weights from index
        (bytes32[] memory symbols, uint256[] memory weights) = Index(s.indexAddress).getWeights();

        (uint256[] memory currentValues, uint256[] memory targetValues, uint256 totalValueUsd) =
            _calculateRebalanceValues(componentRegistry, symbols, weights);

        if (totalValueUsd == 0) revert IndexFacet_ZeroTotalValue();

        // Store pending intent (slimmed: only symbols + targetValues stored)
        s.pendingIntent.active = true;
        s.pendingIntent.totalValueUsd = totalValueUsd;
        s.pendingIntent.symbols = symbols;
        s.pendingIntent.targetValues = targetValues;
        s.lastIntentTimestamp = block.timestamp;
        s.lastIntentBlock = block.number;

        emit IIndex.RebalanceIntentCreated(
            address(this), s.indexAddress, symbols, currentValues, targetValues, totalValueUsd
        );
    }

    /// @notice Execute rebalance by calling DEX facets directly
    /// @dev Callers provide swap steps with dexId + SwapInstruction. The selector is resolved
    ///      from the PoolRegistry at execution time. Uses a custom rebalancing flag instead
    ///      of OZ ReentrancyGuard to avoid conflicts with nonReentrant on DEX facets.
    /// @param steps Array of swap steps to execute
    function _rebalance(SwapStep[] calldata steps) internal {
        IndexStorage.Layout storage s = IndexStorage.layout();

        // Custom reentrancy guard (separate from OZ ReentrancyGuard to avoid conflict with DEX facets)
        if (s.rebalancing) revert IndexFacet_RebalanceReentrancy();
        s.rebalancing = true;

        // Check connected
        if (s.indexAddress == address(0)) {
            revert IndexFacet_NotConnectedToIndex();
        }

        // Check pending intent
        if (!s.pendingIntent.active) {
            revert IndexFacet_NoPendingIntent();
        }

        // Flash loan protection: intent and rebalance must be in different blocks
        if (block.number <= s.lastIntentBlock) {
            revert IndexFacet_IntentBlockDelayNotPassed();
        }

        // Check rebalance interval
        if (block.timestamp < s.lastRebalanceTimestamp + IndexStorage.REBALANCE_INTERVAL) {
            revert IndexFacet_RebalanceIntervalNotPassed();
        }

        if (block.timestamp > s.lastIntentTimestamp + IndexStorage.INTENT_EXPIRY) {
            // Note: no state writes needed here — revert undoes all changes including s.rebalancing = true above
            revert IndexFacet_IntentExpired();
        }

        (, address componentRegistryAddress,) = _protocolAddresses();
        IndexComponentRegistry componentRegistry = IndexComponentRegistry(componentRegistryAddress);

        // Cache all component prices once to ensure valueBefore and valueAfter
        // use the same oracle snapshot. This prevents a Chainlink round update
        // between the two reads from falsely triggering or suppressing the
        // MAX_VALUE_LOSS_BPS guard (M4 fix).
        uint256 len = s.pendingIntent.symbols.length;
        uint256[] memory cachedPrices = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            cachedPrices[i] = componentRegistry.fetchPrice(s.pendingIntent.symbols[i]);
        }

        uint256 valueBefore = _calculateTotalValue(componentRegistry, cachedPrices);

        // Endpoints restricted to intent symbols + USDC (M02); cumulative declared input
        // capped at 1.5x the weight gap (C01): honest routes turn over ~the gap (each
        // excess sold once, each deficit bought once, hub routes re-spend proceeds within
        // the same sum), so a round trip far beyond the margin is churn, not rebalancing.
        (address[] memory allowedTokens, uint256[] memory allowedPrices) =
            _allowedEndpoints(componentRegistry, s.pendingIntent.symbols, cachedPrices);
        uint256 turnoverCapUsd8 = _rebalanceTurnoverCapUsd8(componentRegistry, cachedPrices);
        _executeSwapSteps(steps, allowedTokens, allowedPrices, turnoverCapUsd8);

        // Verify final balances match targets within threshold and get post-swap total value
        uint256 valueAfter = _verifyBalancesMatchTargets(componentRegistry, cachedPrices);

        uint256 minAcceptableValue =
            Math.mulDiv(valueBefore, 10_000 - IndexStorage.MAX_VALUE_LOSS_BPS, 10_000, Math.Rounding.Floor);

        if (valueAfter < minAcceptableValue) {
            revert IndexFacet_ExcessiveValueLoss(valueBefore, valueAfter);
        }

        // Clear pending state and update timestamp
        s.pendingIntent.active = false;
        s.lastRebalanceTimestamp = block.timestamp;
        s.rebalancing = false;

        uint256 nextRebalanceTimestamp = block.timestamp + IndexStorage.REBALANCE_INTERVAL;

        emit IIndex.RebalanceCompleted(address(this), s.indexAddress, block.timestamp, nextRebalanceTimestamp);
    }

    /// @dev Turnover margin over the weight gap: honest multi-hop/hub routes re-spend swap
    ///      proceeds but never exceed ~the gap in declared inputs; 1.5x covers per-leg fees,
    ///      intent-to-execution drift, and partial-fill sizing. A reverting attempt is
    ///      retryable after INTENT_INTERVAL — a false positive costs gas, not liveness.
    uint256 internal constant TURNOVER_MARGIN_NUM = 15_000;
    uint256 internal constant TURNOVER_MARGIN_DEN = 10_000;

    /// @notice Execute swap steps by resolving selectors from PoolRegistry and delegating to
    ///         DEX facets, with swap-endpoint and turnover containment (external audits M02+C01).
    /// @dev For each step: validates both path endpoints against the allowed token list, tracks
    ///      the cumulative declared input value against the turnover cap, resolves the swap
    ///      selector from PoolRegistry via dexId, validates it belongs to the DEX module, then
    ///      calls the DEX facet with the SwapInstruction. Output token balance is verified
    ///      after each swap. Intermediate path tokens are unconstrained (multi-hop routes
    ///      legitimately traverse non-endpoint tokens within one instruction).
    /// @param steps Array of swap steps to execute
    /// @param allowedTokens Endpoint allowlist: USDC + the active session's/intent's symbols
    /// @param allowedPrices Oracle prices for allowedTokens (USD 8 decimals; USDC = 1e8),
    ///        same index order — used to price each step's declared input against the cap
    /// @param maxTurnoverUsd8 Cumulative declared-input cap in USD 8 decimals
    ///        (type(uint256).max exempts the caller, e.g. the unwind's own exit guard)
    function _executeSwapSteps(
        SwapStep[] calldata steps,
        address[] memory allowedTokens,
        uint256[] memory allowedPrices,
        uint256 maxTurnoverUsd8
    )
        internal
    {
        (,, address poolRegistryAddress) = _protocolAddresses();
        ILiquidityPoolRegistry poolReg = ILiquidityPoolRegistry(poolRegistryAddress);

        uint256 turnoverUsd8 = 0;

        for (uint256 i = 0; i < steps.length; i++) {
            // Resolve selector from PoolRegistry
            bytes4 selector = poolReg.getSwapSelectorForDex(steps[i].dexId);

            // Validate selector belongs to DEX module
            if (!_isDexFunction(selector)) revert IndexFacet_SelectorNotWhitelisted(selector);

            SwapInstruction calldata instruction = steps[i].instruction;
            if (instruction.tokens.length < 2) revert IndexFacet_SwapTokenNotAllowed(address(0));

            // Endpoint containment (M02): value must only move between USDC and the active
            // session's/intent's tokens — anything else is invisible to the fee accounting
            address inputToken = instruction.tokens[0];
            address outputToken = instruction.tokens[instruction.tokens.length - 1];
            uint256 inputPrice = _allowedEndpointPrice(inputToken, allowedTokens, allowedPrices);
            _allowedEndpointPrice(outputToken, allowedTokens, allowedPrices); // reverts when disallowed

            // Turnover containment (C01): charge the declared input at the same oracle
            // snapshot the value guard uses. exactOutput steps declare their max spend,
            // so this bounds them conservatively.
            if (maxTurnoverUsd8 != type(uint256).max && instruction.amountIn != 0) {
                uint8 decimals = IERC20Metadata(inputToken).decimals();
                turnoverUsd8 += Math.mulDiv(instruction.amountIn, inputPrice, 10 ** decimals, Math.Rounding.Floor);
                if (turnoverUsd8 > maxTurnoverUsd8) {
                    revert IndexFacet_TurnoverCapExceeded(turnoverUsd8, maxTurnoverUsd8);
                }
            }

            uint256 balanceBefore = IERC20(outputToken).balanceOf(address(this));

            // Call the DEX facet's swap function with the SwapInstruction
            (bool success, bytes memory returnData) = address(this).call(abi.encodeWithSelector(selector, instruction));

            if (!success) {
                if (returnData.length == 0) revert IndexFacet_SelectorNotFound(selector);
                revert IndexFacet_SwapCallFailed(i, returnData);
            }

            // Verify minimum output received
            uint256 received = IERC20(outputToken).balanceOf(address(this)) - balanceBefore;
            uint256 minOutput = instruction.amountOut;
            if (received < minOutput) {
                revert IndexFacet_InsufficientSwapOutput(i, outputToken, received, minOutput);
            }
        }
    }

    /// @dev Endpoint allowlist + parallel price list: USDC (priced 1e8) first, then the
    ///      given symbols' token addresses with their snapshot prices. `snapshotPrices`
    ///      must be indexed exactly like `symbols` (the rebalance's intent prices or the
    ///      unwind's weight prices).
    function _allowedEndpoints(
        IndexComponentRegistry componentRegistry,
        bytes32[] memory symbols,
        uint256[] memory snapshotPrices
    )
        internal
        view
        returns (address[] memory allowedTokens, uint256[] memory allowedPrices)
    {
        allowedTokens = new address[](symbols.length + 1);
        allowedPrices = new uint256[](symbols.length + 1);
        allowedTokens[0] = IndexStorage.USDC_ADDRESS;
        allowedPrices[0] = 1e8; // USDC = $1 (6 decimals: 1e6 raw * 1e8 / 1e6 = 1e8 per unit)
        for (uint256 i = 0; i < symbols.length; i++) {
            if (symbols[i] == _USDC_SYMBOL) continue; // already covered as slot 0
            allowedTokens[i + 1] = componentRegistry.getComponentAddress(symbols[i]);
            allowedPrices[i + 1] = i < snapshotPrices.length ? snapshotPrices[i] : 0;
        }
    }

    /// @dev Price of an endpoint token from the allowlist; reverts when the token is not an
    ///      allowed endpoint. Returns 0 for an allowlisted-but-unpriced slot (only possible
    ///      for the skipped USDC-duplicate slot, which real paths never name).
    function _allowedEndpointPrice(
        address token,
        address[] memory allowedTokens,
        uint256[] memory allowedPrices
    )
        internal
        pure
        returns (uint256)
    {
        for (uint256 i = 0; i < allowedTokens.length; i++) {
            if (allowedTokens[i] == token) {
                if (allowedPrices[i] == 0) revert IndexFacet_SwapTokenNotAllowed(token);
                return allowedPrices[i];
            }
        }
        revert IndexFacet_SwapTokenNotAllowed(token);
    }

    /// @dev Turnover cap for a rebalance: 1.5x the weight gap between the stored intent's
    ///      target values and the current balances, priced with the same cached snapshot
    ///      the value guard uses.
    function _rebalanceTurnoverCapUsd8(
        IndexComponentRegistry componentRegistry,
        uint256[] memory cachedPrices
    )
        internal
        view
        returns (uint256)
    {
        IndexStorage.Layout storage s = IndexStorage.layout();
        uint256 gapUsd8 = 0;
        for (uint256 i = 0; i < s.pendingIntent.symbols.length; i++) {
            address token = componentRegistry.getComponentAddress(s.pendingIntent.symbols[i]);
            uint256 current = Math.mulDiv(
                IERC20(token).balanceOf(address(this)),
                cachedPrices[i],
                10 ** IERC20Metadata(token).decimals(),
                Math.Rounding.Floor
            );
            uint256 target = s.pendingIntent.targetValues[i];
            gapUsd8 += current > target ? current - target : target - current;
        }
        return Math.mulDiv(gapUsd8, TURNOVER_MARGIN_NUM, TURNOVER_MARGIN_DEN, Math.Rounding.Floor);
    }

    /// @dev Checks whether a selector belongs to the DEX module by querying the FacetRegistry.
    /// @param selector The four-byte function selector to check.
    /// @return `true` if the selector belongs to the DEX module.
    function _isDexFunction(bytes4 selector) internal view returns (bool) {
        IFacetRegistry registry = IFacetRegistry(LibDiamond.layout().facetRegistry);
        bytes32 moduleId = registry.getModuleIdBySelector(selector);
        return moduleId == IndexStorage.DEX_MODULE_ID;
    }

    // ========================================================================
    // Internal Functions - Calculations
    // ========================================================================

    /// @dev Calculates current token values and target values for each component in the index.
    /// @param componentRegistry The IndexComponentRegistry instance (passed to avoid redundant instantiation).
    /// @param symbols Array of component symbols to evaluate (bytes32 encoded).
    /// @param weights Array of target weights (normalized to 1e18) corresponding to each symbol.
    /// @return currentValues Current USD values per component (8 decimals).
    /// @return targetValues Target USD values per component (8 decimals).
    /// @return totalValueUsd Total portfolio value in USD (8 decimals).
    function _calculateRebalanceValues(
        IndexComponentRegistry componentRegistry,
        bytes32[] memory symbols,
        uint256[] memory weights
    )
        internal
        returns (uint256[] memory currentValues, uint256[] memory targetValues, uint256 totalValueUsd)
    {
        currentValues = new uint256[](symbols.length);
        targetValues = new uint256[](symbols.length);
        totalValueUsd = 0;

        // Calculate current values
        for (uint256 i = 0; i < symbols.length; i++) {
            address token = componentRegistry.getComponentAddress(symbols[i]);

            uint256 balance = IERC20(token).balanceOf(address(this));
            uint256 price = componentRegistry.fetchPrice(symbols[i]);
            uint8 decimals = IERC20Metadata(token).decimals();

            // Value in USD with 8 decimals (Chainlink standard)
            currentValues[i] = Math.mulDiv(balance, price, 10 ** decimals, Math.Rounding.Floor);
            totalValueUsd += currentValues[i];
        }

        // Add USDC deposit token value to total (USDC is not an index component but contributes to portfolio value)
        totalValueUsd += _getUsdcValueUsd(componentRegistry, symbols);

        // Calculate target values based on weights
        for (uint256 i = 0; i < symbols.length; i++) {
            targetValues[i] = Math.mulDiv(totalValueUsd, weights[i], IndexStorage.PRECISION, Math.Rounding.Floor);
        }
    }

    /// @dev Verifies that post-rebalance balances match stored target values within the allowed threshold.
    ///      Uses stored targetValues from the pending intent to prevent target drift from oracle manipulation.
    ///      Also computes and returns the fresh total portfolio value (combining verify + value calculation
    ///      into a single loop for gas efficiency). Uses cached prices to avoid a second oracle round read.
    /// @param componentRegistry The IndexComponentRegistry instance.
    /// @param cachedPrices Pre-fetched prices for each component symbol (parallel to pendingIntent.symbols).
    /// @return freshTotalValueUsd The fresh total portfolio value in USD (8 decimals).
    function _verifyBalancesMatchTargets(
        IndexComponentRegistry componentRegistry,
        uint256[] memory cachedPrices
    )
        internal
        returns (uint256 freshTotalValueUsd)
    {
        IndexStorage.Layout storage s = IndexStorage.layout();

        uint256 len = s.pendingIntent.symbols.length;
        freshTotalValueUsd = 0;

        for (uint256 i = 0; i < len; i++) {
            bytes32 symbol = s.pendingIntent.symbols[i];
            address token = componentRegistry.getComponentAddress(symbol);

            uint256 balance = IERC20(token).balanceOf(address(this));
            uint256 price = cachedPrices[i];
            uint8 decimals = IERC20Metadata(token).decimals();

            uint256 currentValue = Math.mulDiv(balance, price, 10 ** decimals, Math.Rounding.Floor);
            freshTotalValueUsd += currentValue;

            // Use STORED targetValues from intent creation (prevents target drift)
            uint256 targetValue = s.pendingIntent.targetValues[i];

            // Calculate threshold
            uint256 threshold = Math.mulDiv(targetValue, IndexStorage.BALANCE_THRESHOLD_BPS, 10_000, Math.Rounding.Ceil);

            // Verify within threshold (use abs diff to avoid underflow)
            uint256 diff = currentValue > targetValue ? currentValue - targetValue : targetValue - currentValue;
            if (diff > threshold) {
                revert IndexFacet_BalanceOutsideThreshold(symbol, currentValue, targetValue);
            }
        }

        // Add USDC deposit token value to fresh total
        freshTotalValueUsd += _getUsdcValueUsd(componentRegistry, s.pendingIntent.symbols);
    }

    /// @notice Calculate total garden value in USD using cached oracle prices.
    /// @param componentRegistry The IndexComponentRegistry instance.
    /// @param cachedPrices Pre-fetched prices for each component symbol (parallel to pendingIntent.symbols).
    function _calculateTotalValue(
        IndexComponentRegistry componentRegistry,
        uint256[] memory cachedPrices
    )
        internal
        returns (uint256 totalValueUsd)
    {
        IndexStorage.Layout storage s = IndexStorage.layout();

        for (uint256 i = 0; i < s.pendingIntent.symbols.length; i++) {
            bytes32 symbol = s.pendingIntent.symbols[i];
            address token = componentRegistry.getComponentAddress(symbol);

            uint256 balance = IERC20(token).balanceOf(address(this));
            uint256 price = cachedPrices[i];
            uint8 decimals = IERC20Metadata(token).decimals();

            totalValueUsd += Math.mulDiv(balance, price, 10 ** decimals, Math.Rounding.Floor);
        }

        // Add USDC deposit token value to total
        totalValueUsd += _getUsdcValueUsd(componentRegistry, s.pendingIntent.symbols);
    }

    /// @dev Returns the USD value of USDC held by the garden (8 decimals).
    ///      Uses the Chainlink oracle via IndexComponentRegistry for accurate pricing.
    ///      Returns 0 if the garden holds no USDC, if USDC is already an index component
    ///      (to avoid double-counting), or if USDC is not registered in the ComponentRegistry.
    function _getUsdcValueUsd(
        IndexComponentRegistry componentRegistry,
        bytes32[] memory symbols
    )
        internal
        returns (uint256)
    {
        // Skip if USDC is already counted as an index component (simple bytes32 comparison)
        for (uint256 i = 0; i < symbols.length; i++) {
            if (symbols[i] == _USDC_SYMBOL) {
                return 0;
            }
        }

        uint256 usdcBalance = IERC20(IndexStorage.USDC_ADDRESS).balanceOf(address(this));
        if (usdcBalance == 0) return 0;

        // Gracefully return 0 if USDC is not registered in the ComponentRegistry,
        // so an unregistered USDC doesn't brick the entire rebalance flow.
        if (!componentRegistry.isComponentRegistered(_USDC_SYMBOL)) return 0;

        uint256 usdcPrice = componentRegistry.fetchPrice(_USDC_SYMBOL);
        uint8 usdcDecimals = IERC20Metadata(IndexStorage.USDC_ADDRESS).decimals();

        return Math.mulDiv(usdcBalance, usdcPrice, 10 ** usdcDecimals, Math.Rounding.Floor);
    }

    // ========================================================================
    // Internal Functions - View
    // ========================================================================

    /// @dev Returns whether the garden is currently connected to an index.
    /// @return `true` if connected.
    function _isConnectedToIndex() internal view returns (bool) {
        return LibDiamond.layout().isConnectedToIndex;
    }

    /// @dev Returns the address of the connected index contract.
    /// @return The connected index address, or `address(0)` if not connected.
    function _getConnectedIndex() internal view returns (address) {
        return IndexStorage.layout().indexAddress;
    }

    /// @dev Returns whether there is an active pending rebalance intent.
    /// @return `true` if a pending intent exists.
    function _hasPendingIntent() internal view returns (bool) {
        return IndexStorage.layout().pendingIntent.active;
    }

    /// @dev Returns the current pending rebalance intent details.
    /// @return active Whether a pending intent is active.
    /// @return totalValueUsd Total portfolio value in USD at intent creation.
    /// @return symbols Array of component symbols (bytes32 encoded).
    /// @return targetValues Array of target USD values per component.
    function _getPendingIntent()
        internal
        view
        returns (bool active, uint256 totalValueUsd, bytes32[] memory symbols, uint256[] memory targetValues)
    {
        IndexStorage.Layout storage s = IndexStorage.layout();
        return (
            s.pendingIntent.active, s.pendingIntent.totalValueUsd, s.pendingIntent.symbols, s.pendingIntent.targetValues
        );
    }

    // ========================================================================
    // Fee layer — INDEX session valuation hook
    // ========================================================================

    /// @notice INDEX session valuation: every index component valued at its oracle USDC price
    ///         plus the raw USDC balance (8-dec USD converted to 6-dec USDC). This is the
    ///         fee layer's session NAV hook for the INDEX tool — future wealth-management
    ///         modules override it with their own accounting in their own bases.
    /// @return The garden's USDC-denominated NAV (6 decimals)
    function _calculateSessionUsdcNav() internal override returns (uint256) {
        IndexStorage.Layout storage s = IndexStorage.layout();
        (, address componentRegistryAddress,) = _protocolAddresses();
        IndexComponentRegistry componentRegistry = IndexComponentRegistry(componentRegistryAddress);

        (bytes32[] memory symbols,) = Index(s.indexAddress).getWeights();

        uint256 componentUsd8 = 0; // 8-decimal USD (Chainlink convention)
        for (uint256 i = 0; i < symbols.length; i++) {
            if (symbols[i] == _USDC_SYMBOL) continue; // raw USDC counted directly below
            address token = componentRegistry.getComponentAddress(symbols[i]);
            uint256 balance = IERC20(token).balanceOf(address(this));
            // Strict read: connect-time basis must not be priced off a deviation-rejected
            // or stale feed (the basis is persisted and never re-validated)
            uint256 price = componentRegistry.fetchPriceStrict(symbols[i]);
            uint8 decimals = IERC20Metadata(token).decimals();
            componentUsd8 += Math.mulDiv(balance, price, 10 ** decimals, Math.Rounding.Floor);
        }

        // Convert USD(8dec) → USDC(6dec) and add raw USDC
        uint256 nav = Math.mulDiv(componentUsd8, 1e6, 1e8, Math.Rounding.Floor);
        return nav + IERC20(IndexStorage.USDC_ADDRESS).balanceOf(address(this));
    }

    /// @notice Snapshot variant: values from the unwind's pre-fetched same-block price cache
    ///         (mirrors the _rebalance M4 fix) instead of re-fetching per symbol — a Chainlink
    ///         round landing mid-NAV can no longer shift the exit guard's reference.
    function _calculateSessionUsdcNav(uint256[] memory cachedPrices) internal override returns (uint256) {
        IndexStorage.Layout storage s = IndexStorage.layout();
        (, address componentRegistryAddress,) = _protocolAddresses();
        IndexComponentRegistry componentRegistry = IndexComponentRegistry(componentRegistryAddress);

        (bytes32[] memory symbols,) = Index(s.indexAddress).getWeights();
        if (symbols.length != cachedPrices.length) revert IndexFacet_OracleSnapshotMismatch();

        uint256 componentUsd8 = 0; // 8-decimal USD (Chainlink convention)
        for (uint256 i = 0; i < symbols.length; i++) {
            if (symbols[i] == _USDC_SYMBOL) continue; // raw USDC counted directly below
            address token = componentRegistry.getComponentAddress(symbols[i]);
            uint256 balance = IERC20(token).balanceOf(address(this));
            uint8 decimals = IERC20Metadata(token).decimals();
            componentUsd8 += Math.mulDiv(balance, cachedPrices[i], 10 ** decimals, Math.Rounding.Floor);
        }

        // Convert USD(8dec) → USDC(6dec) and add raw USDC
        uint256 nav = Math.mulDiv(componentUsd8, 1e6, 1e8, Math.Rounding.Floor);
        return nav + IERC20(IndexStorage.USDC_ADDRESS).balanceOf(address(this));
    }
}
