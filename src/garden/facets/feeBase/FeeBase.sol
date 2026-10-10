// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▛▀▜▌▐▛▚▖     ▐▌   ▐▌ ▐▌▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { FeeStorage } from "src/garden/facets/indexFacets/FeeStorage.sol";
import { IndexStorage } from "src/garden/facets/indexFacets/IndexStorage.sol";
import { IFeeRegistry } from "src/interfaces/IFeeRegistry.sol";
import { ITreasuryRegistry } from "src/interfaces/ITreasuryRegistry.sol";
import { IOnboarderRegistry } from "src/interfaces/IOnboarderRegistry.sol";
import { IIndex } from "src/garden/facets/indexFacets/IIndex.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { IndexComponentRegistry } from "src/indices/IndexComponentRegistry.sol";
import { Index } from "src/indices/Index.sol";
import { LibDiamond } from "src/garden/libraries/LibDiamond.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when the fee module has not been configured on this garden
error FeeFacet_FeeModuleNotConfigured();

/// @notice Thrown when a zero address is passed into configureFeeModule
/// @param module The invalid address
error FeeFacet_InvalidFeeModuleAddress(address module);

/// @notice Thrown when an onboarder address is not allowlisted in the OnboarderRegistry
/// @param onboarder The ineligible address
error FeeFacet_OnboarderNotEligible(address onboarder);

/// @notice Thrown when a fee session has no recorded basis (legacy session) but the operation
///         requires one
error FeeFacet_FeeBasisNotRecorded();

/// @notice Thrown when the legacy fee-free disconnect is attempted on a session that has a
///         recorded basis — such sessions must exit through unwindAndDisconnect
error FeeFacet_UnwindRequired();

/// @notice Thrown on reentrant unwind attempts
error FeeFacet_UnwindReentrancy();

/// @notice Thrown when fee settlement is attempted while the Treasury Registry has no address
error FeeFacet_TreasuryNotSet();

/// @notice Thrown when an unwind leaves a non-USDC component balance behind — the whole unwind
///         aborts (garden stays connected) rather than settle fees on a partial unwind
/// @param symbol The component symbol that remained
/// @param remaining The remaining balance
error FeeFacet_ComponentRemained(bytes32 symbol, uint256 remaining);

/// @notice Thrown when a zero deposit amount is recorded
error FeeFacet_ZeroDepositAmount();

/// @notice Thrown when a module calls the session valuation hook without overriding it
error FeeFacet_NavHookNotImplemented();

/// @notice Thrown when configureFeeModule is attempted before the FacetRegistry has published
///         the DAO's canonical fee registries (fail-closed: no registries, no fee module)
error FeeFacet_CanonicalRegistriesNotSet();

/// @notice Thrown when configureFeeModule is called with an address that is not the DAO's
///         canonical registry published on the FacetRegistry
/// @param provided The address that was passed in
/// @param canonical The canonical address it must match
error FeeFacet_RegistryNotCanonical(address provided, address canonical);

/// @notice Thrown when a component deposit is for a symbol outside the active session's
///         valuation universe (the connected index's weight list) — credited basis could
///         never be realized into exit USDC
/// @param symbol The out-of-universe symbol
error FeeFacet_SymbolNotInIndex(bytes32 symbol);

/**
 * @title FeeBase
 * @author BLOK Capital DAO
 * @notice Tool-agnostic fee layer for BLOK gardens: fee-module configuration, session basis
 *         recording, deposit crediting, fee math, and settlement. Inherited by every
 *         wealth-management module that charges fees (the INDEX module is the first consumer);
 *         the active tool supplies its own session valuation by overriding
 *         _calculateSessionUsdcNav().
 *
 * @dev Fees settle ONLY in USDC, ONLY on realized profit (exitUSDC > entryUSDC), and are routed
 *      to the onboarder wallet and the Treasury Registry address. Nothing here can move
 *      principal: the investor invariant is onboarderCut + treasuryTotal + investorUSDC ==
 *      exitUSDC, with investorUSDC >= entryUSDC whenever profit > 0.
 */
abstract contract FeeBase {
    using SafeERC20 for IERC20;

    /// @dev Cached bytes32 symbol for USDC.
    bytes32 internal constant _USDC_SYMBOL = bytes32("USDC");

    // ========================================================================
    // Configuration
    // ========================================================================

    /// @notice Wires the fee registries into this garden. First-time configuration is allowed
    ///         in any garden state (live gardens must be able to adopt fees without
    ///         disconnecting); any re-configuration requires no active fee session.
    /// @dev All three addresses are validated against the DAO's canonical fee registries
    ///      published on the FacetRegistry (the garden's immutable trust anchor) — the fee
    ///      payer can never wire lookalike registries that zero the schedule or redirect
    ///      fees to themselves. Fail-closed while canonicals are unpublished.
    function _configureFeeModule(address feeRegistry, address treasuryRegistry, address onboarderRegistry) internal {
        if (feeRegistry == address(0) || treasuryRegistry == address(0) || onboarderRegistry == address(0)) {
            revert FeeFacet_InvalidFeeModuleAddress(feeRegistry == address(0)
                    ? feeRegistry
                    : treasuryRegistry == address(0) ? treasuryRegistry : onboarderRegistry);
        }
        (address canonicalFee, address canonicalTreasury, address canonicalOnboarder) =
            IFacetRegistry(LibDiamond.layout().facetRegistry).getCanonicalFeeRegistries();
        if (canonicalFee == address(0)) revert FeeFacet_CanonicalRegistriesNotSet();
        if (feeRegistry != canonicalFee) revert FeeFacet_RegistryNotCanonical(feeRegistry, canonicalFee);
        if (treasuryRegistry != canonicalTreasury) {
            revert FeeFacet_RegistryNotCanonical(treasuryRegistry, canonicalTreasury);
        }
        if (onboarderRegistry != canonicalOnboarder) {
            revert FeeFacet_RegistryNotCanonical(onboarderRegistry, canonicalOnboarder);
        }
        FeeStorage.Layout storage fs = FeeStorage.layout();
        if (fs.feeRegistry != address(0) && fs.basisRecorded) {
            revert FeeFacet_UnwindRequired(); // an active session must exit through the unwind first
        }
        fs._storageLayoutVersion = FeeStorage.STORAGE_LAYOUT_VERSION;
        fs.feeRegistry = feeRegistry;
        fs.treasuryRegistry = treasuryRegistry;
        fs.onboarderRegistry = onboarderRegistry;
    }

    /// @dev Guards value-egress primitives against active fee sessions: with a recorded basis
    ///      the unwind is the ONLY sanctioned exit, and any parallel rail (e.g. allowances to
    ///      external spenders) would drain the fee base before settlement. Used by
    ///      ApproveFacet.approveTokens and any future owner-callable egress facet.
    function _revertIfFeeSessionActive() internal view {
        if (FeeStorage.layout().basisRecorded) revert FeeFacet_UnwindRequired();
    }

    /// @dev Returns the configured fee registry, reverting loudly if the fee module was never
    ///      configured (same philosophy as IndexBase._protocolAddresses).
    function _feeRegistry() internal view returns (IFeeRegistry) {
        address feeRegistry = FeeStorage.layout().feeRegistry;
        if (feeRegistry == address(0)) revert FeeFacet_FeeModuleNotConfigured();
        return IFeeRegistry(feeRegistry);
    }

    // ========================================================================
    // Session basis
    // ========================================================================

    /// @notice Starts a fee session: values the garden in USDC via the active tool's NAV hook,
    ///         locks the DAO's fee schedule, and records the basis + onboarder binding.
    ///         No-op-safe when the fee module is unconfigured: the session simply stays
    ///         "legacy" (basisRecorded == false) and exits fee-free.
    /// @param sessionRef Reference to the active tool session (e.g. the connected index)
    /// @param onboarder The bound onboarder (address(0) = none)
    function _recordBasis(address sessionRef, address onboarder) internal {
        FeeStorage.Layout storage fs = FeeStorage.layout();

        // Legacy session: without a fee layer there is no basis to settle against — leave
        // basisRecorded false so the fee-free disconnectFromIndex exit stays available
        if (fs.feeRegistry == address(0)) return;

        {
            (uint256 performanceFeeBps, uint256 protocolFeeBps, uint256 onboarderShareBps,, uint8 applyRateAtMode) =
                IFeeRegistry(fs.feeRegistry).getFeeSchedule();
            fs.lockedSchedule = FeeStorage.FeeSchedule({
                performanceFeeBps: uint16(performanceFeeBps),
                protocolFeeBps: uint16(protocolFeeBps),
                onboarderShareBps: uint16(onboarderShareBps),
                applyRateAtMode: applyRateAtMode
            });
        }

        fs.basisRecorded = true;
        fs.entryUSDC = _calculateSessionUsdcNav();
        fs.depositUSDC = 0;
        fs.connectedAtBlock = uint64(block.number);
        fs.connectedAtTimestamp = uint64(block.timestamp);
        fs.onboarderAddress = onboarder;

        emit IIndex.BasisRecorded(address(this), fs.entryUSDC, sessionRef, onboarder);
    }

    /// @notice Records a deposit into an active fee session: pulls the token from the caller
    ///         and credits entryUSDC by the deposit's USDC value (no fee at deposit). USDC is
    ///         credited raw; other component tokens via their oracle USDC value.
    /// @param symbol The component symbol the deposit belongs to (keyed — the registry has no
    ///        reverse lookup)
    /// @param amount The deposit amount
    function _recordDeposit(bytes32 symbol, uint256 amount) internal {
        if (amount == 0) revert FeeFacet_ZeroDepositAmount();
        FeeStorage.Layout storage fs = FeeStorage.layout();
        if (!fs.basisRecorded) revert FeeFacet_FeeBasisNotRecorded();

        uint256 usdcValue;
        address token;
        if (symbol == _USDC_SYMBOL) {
            token = IndexStorage.USDC_ADDRESS;
            SafeERC20.safeTransferFrom(IERC20(token), msg.sender, address(this), amount);
            usdcValue = amount;
        } else {
            address componentRegistryAddress = IndexStorage.layout().indexComponentRegistry;
            if (componentRegistryAddress == address(0)) revert FeeFacet_FeeModuleNotConfigured();
            IndexComponentRegistry componentRegistry = IndexComponentRegistry(componentRegistryAddress);
            token = componentRegistry.getComponentAddress(symbol);

            // Deposit-universe check: credited basis must be realizable into exit USDC, and the
            // unwind only converts the active session's own symbols — a deposit outside that
            // universe would permanently suppress the feeable profit (audit: basis laundering)
            address indexAddress = IndexStorage.layout().indexAddress;
            if (indexAddress == address(0)) revert FeeFacet_SymbolNotInIndex(symbol);
            (bytes32[] memory sessionSymbols,) = Index(indexAddress).getWeights();
            bool inSession;
            for (uint256 i = 0; i < sessionSymbols.length; i++) {
                if (sessionSymbols[i] == symbol) {
                    inSession = true;
                    break;
                }
            }
            if (!inSession) revert FeeFacet_SymbolNotInIndex(symbol);

            SafeERC20.safeTransferFrom(IERC20(token), msg.sender, address(this), amount);
            uint8 decimals = IERC20Metadata(token).decimals();
            // Strict read: a deviation-rejected or stale feed must not price the basis (the
            // basis is the one transient oracle read that is persisted and never re-validated)
            uint256 usd8 =
                Math.mulDiv(amount, componentRegistry.fetchPriceStrict(symbol), 10 ** decimals, Math.Rounding.Floor);
            usdcValue = Math.mulDiv(usd8, 1e6, 1e8, Math.Rounding.Floor);
        }

        fs.entryUSDC += usdcValue;
        fs.depositUSDC += usdcValue;
        emit IIndex.DepositRecorded(address(this), token, amount, usdcValue);
    }

    /// @notice Session valuation hook — the active tool supplies its own USDC NAV.
    ///         The INDEX implementation values all index components at the oracle price plus
    ///         raw USDC; a future Yield module would override with its own accounting.
    ///         FeeFacet itself never calls this hook (only tool modules do).
    /// @return The garden's USDC-denominated NAV (6 decimals)
    function _calculateSessionUsdcNav() internal virtual returns (uint256) {
        revert FeeFacet_NavHookNotImplemented();
    }

    /// @notice Snapshot variant of the valuation hook: the caller supplies pre-fetched prices
    ///         (indexed like the symbols from Index.getWeights()) so the whole unwind values
    ///         from one same-block oracle snapshot — mirroring the _rebalance M4 fix.
    /// @param cachedPrices Pre-fetched component prices (8 decimals), same order as getWeights()
    /// @return The garden's USDC-denominated NAV (6 decimals)
    function _calculateSessionUsdcNav(uint256[] memory cachedPrices) internal virtual returns (uint256) {
        cachedPrices; // silence unused-param warning in the default (reverting) implementation
        revert FeeFacet_NavHookNotImplemented();
    }

    /// @notice Clears the fee session basis and records the settlement audit trail.
    /// @param exitUSDC The realized USDC balance at exit
    function _clearBasis(uint256 exitUSDC) internal {
        FeeStorage.Layout storage fs = FeeStorage.layout();
        fs.lastExitUSDC = exitUSDC;
        fs.lastRealizedProfitUSDC = int256(exitUSDC) - int256(fs.entryUSDC); // negative = loss recorded
        fs.basisRecorded = false;
        fs.entryUSDC = 0;
        fs.depositUSDC = 0;
        fs.onboarderAddress = address(0);
        delete fs.lockedSchedule;
    }

    // ========================================================================
    // Fee math + settlement
    // ========================================================================

    /// @dev Computes the fee split for a realized profit. Fees are charged only on profit
    ///      (never on a loss, never on basis). The DAO's schedule snapshot (or live rates,
    ///      per applyRateAt) drives the rates.
    /// @return profit max(exitUSDC - entryUSDC, 0)
    /// @return performanceFee profit * performanceFeeBps / 10_000
    /// @return protocolFee profit * protocolFeeBps / 10_000
    /// @return onboarderCut performanceFee * onboarderShareBps / 10_000 (0 when no onboarder)
    /// @return treasuryTotal (performanceFee - onboarderCut) + protocolFee
    function _computeFeeSplit(
        uint256 exitUSDC,
        uint256 entryUSDC,
        FeeStorage.FeeSchedule memory schedule,
        address onboarder
    )
        internal
        pure
        returns (
            uint256 profit,
            uint256 performanceFee,
            uint256 protocolFee,
            uint256 onboarderCut,
            uint256 treasuryTotal
        )
    {
        if (exitUSDC > entryUSDC) profit = exitUSDC - entryUSDC;
        if (profit == 0) return (0, 0, 0, 0, 0);

        performanceFee = Math.mulDiv(profit, schedule.performanceFeeBps, 10_000, Math.Rounding.Floor);
        protocolFee = Math.mulDiv(profit, schedule.protocolFeeBps, 10_000, Math.Rounding.Floor);
        if (onboarder != address(0)) {
            onboarderCut = Math.mulDiv(performanceFee, schedule.onboarderShareBps, 10_000, Math.Rounding.Floor);
        }
        treasuryTotal = (performanceFee - onboarderCut) + protocolFee;
    }

    /// @dev Settles fees: routes the onboarder cut to the onboarder wallet and the rest to the
    ///      Treasury Registry address. Skips transfers entirely when profit == 0 (spec: save
    ///      gas). An onboarder wallet that reverts on USDC receive must not brick settlement —
    ///      that cut is re-routed to the Treasury and OnboarderPayoutFailed is emitted. The
    ///      Treasury transfer failing bubbles up: with no settleable Treasury the whole exit
    ///      reverts and the garden stays connected.
    function _settleFees(
        uint256 profit,
        uint256 performanceFee,
        uint256 protocolFee,
        uint256 onboarderCut,
        uint256 treasuryTotal
    )
        internal
    {
        if (profit == 0) return;

        FeeStorage.Layout storage fs = FeeStorage.layout();
        address treasury = ITreasuryRegistry(fs.treasuryRegistry).getTreasuryAddress();
        if (treasury == address(0) && (treasuryTotal > 0 || onboarderCut > 0)) {
            revert FeeFacet_TreasuryNotSet();
        }

        if (onboarderCut > 0) {
            // Low-level call: a reverting onboarder receiver must not brick the exit (spec §10)
            (bool ok,) = IndexStorage.USDC_ADDRESS
                .call(abi.encodeWithSelector(IERC20.transfer.selector, fs.onboarderAddress, onboarderCut));
            if (!ok) {
                treasuryTotal += onboarderCut;
                emit IIndex.OnboarderPayoutFailed(address(this), fs.onboarderAddress, onboarderCut);
            }
        }

        if (treasuryTotal > 0) {
            IERC20(IndexStorage.USDC_ADDRESS).safeTransfer(treasury, treasuryTotal);
        }
    }
}
