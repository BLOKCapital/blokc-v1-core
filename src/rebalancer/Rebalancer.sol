// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { IndexFactory } from "src/indices/IndexFactory.sol";
import { IndexComponentRegistry } from "src/indices/IndexComponentRegistry.sol";
import { IIndex } from "src/interfaces/IIndex.sol";
import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { QuoteInstruction } from "src/interfaces/ISwapInstruction.sol";

// ============================================================================
// Errors
// ============================================================================

error Rebalancer_NotOwner();
error Rebalancer_NoIndicesRegistered(bytes32 indexTypeId);
error Rebalancer_IndexAlreadyInType(bytes32 indexTypeId, address index);
error Rebalancer_IndexNotInType(bytes32 indexTypeId, address index);
error Rebalancer_IndexNotRegistered(address index);
error Rebalancer_NoGardensFound(bytes32 indexTypeId);
error Rebalancer_RebalanceIntervalNotPassed(bytes32 indexTypeId, uint256 lastRebalance, uint256 nextAllowed);
error Rebalancer_RebalanceReentrancy(bytes32 indexTypeId);
error Rebalancer_ZeroTotalValue(bytes32 indexTypeId);
error Rebalancer_ExcessiveValueLoss(uint256 valueBefore, uint256 valueAfter);
error Rebalancer_SwapFailed(address tokenIn, address tokenOut, bytes reason);
error Rebalancer_NoPoolsFound(address tokenIn, address tokenOut);
error Rebalancer_InsufficientSwapOutput(address tokenOut, uint256 received, uint256 minExpected);
error Rebalancer_DexNotConfigured(bytes32 dexId);
error Rebalancer_DexTypeNotSupported(uint8 dexType);
error Rebalancer_InvalidConfig();
error Rebalancer_UnapprovedSwapSelector(bytes4 selector);
error Rebalancer_DeadlineExpired(uint256 deadline, uint256 blockTimestamp);
error Rebalancer_BatchSizeNotSet(bytes32 indexTypeId);

/// @notice Thrown when renounceOwnership is called (disabled to prevent permanent lockout)
error Rebalancer_CannotRenounceOwnership();

/**
 * @title Rebalancer
 * @author BLOK Capital DAO
 * @notice Aggregates all gardens of a given Index type (e.g. all BLOKC2 gardens) into a single
 *         atomic rebalance transaction. Fully registry-driven — DEXs are discovered and used
 *         through the LiquidityPoolRegistry and FacetRegistry, with no hardcoded DEX logic.
 *
 *         To add a new DEX, the DAO calls:
 *         1. Register the DEX in the FacetRegistry (deploy facet, add to DEX module)
 *         2. Register the DEX in the LiquidityPoolRegistry (dexId + swapSelector + quoteSelector)
 *         3. Call setDexConfig(dexId, router, quoteFacet, dexType) on this contract
 *
 *         No code changes are required to support new V2 or V3-style DEXs.
 */
contract Rebalancer is Ownable {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    // ========================================================================
    // Constants
    // ========================================================================

    uint256 public constant PRECISION = 1e18;
    uint256 public constant BALANCE_THRESHOLD_BPS = 200; // 2%
    uint256 public constant MAX_VALUE_LOSS_BPS = 50; // 0.5%
    uint256 public constant REBALANCE_INTERVAL = 24 hours;
    bytes32 private constant _USDC_SYMBOL = bytes32("USDC");

    /// @notice Router swap selectors permitted in setDexConfig. Restricts the DAO-configurable
    ///         routerSwapSelector to known DEX router swap functions so a compromised owner
    ///         cannot set an arbitrary selector (e.g. IERC20.transfer.selector on the USDC
    ///         contract) and drain all pooled tokens on the next rebalance.
    ///
    ///         Whitelisted selectors (router swap functions):
    ///         0x38ed1739 — swapExactTokensForTokens (Uniswap V2, SushiSwap V2, Trader Joe V2)
    ///         0xac3893ba — swapExactTokensForTokensSupportingFeeOnTransferTokens (Camelot V2)
    ///         0x6c42f2b1 — swapExactTokensForTokensSupportingFeeOnTransferTokensV2 (Camelot V2 router)
    ///         0x414bf389 — exactInputSingle (Uniswap V3, SushiSwap V3)
    ///         0xbc651188 — exactInputSingle (Camelot V3, 7-param variant)

    // ========================================================================
    // DexType enum — determines how the router is called
    // ========================================================================

    /// @notice DEX category determining the router's swap interface.
    ///         V2_STANDARD:         swapExactTokensForTokens (5-param; Uniswap V2, SushiSwap V2)
    ///         V2_CONSTANT_PRODUCT: swapExactTokensForTokensSupportingFeeOnTransferTokens (6-param; Camelot V2)
    ///         V3_CONCENTRATED:     exactInputSingle (Uniswap V3, Camelot V3, SushiSwap V3)
    enum DexType {
        V2_STANDARD,
        V2_CONSTANT_PRODUCT,
        V3_CONCENTRATED
    }

    /// @notice Per-DEX configuration set by the DAO. No DEX-specific code lives in this contract.
    struct DexConfig {
        address router; // DEX router address for swap execution
        address quoteFacet; // DEX facet address for generic quoting (via quoteSelector)
        bytes4 routerSwapSelector; // Router's own swap function selector (e.g. swapExactTokensForTokens.selector)
        DexType dexType; // How to encode the calldata (V2 vs V3 parameter layout)
    }

    /// @notice Oracle prices cached once at the start of cumulativeRebalance and reused for
    ///         every valuation and amount conversion in the transaction, so valueBefore and
    ///         valueAfter are computed against the SAME snapshot.
    struct PriceSnapshot {
        /// @dev Prices parallel to the index component `symbols` array (Chainlink raw units, 8 decimals).
        uint256[] components;
        /// @dev Cached USDC/USD price (8 decimals). 0 when USDC is neither an index component
        ///      nor registered in the ComponentRegistry (no USDC feed available).
        uint256 usdc;
    }

    // ========================================================================
    // Immutables — Protocol Registries
    // ========================================================================

    IndexFactory public immutable INDEX_FACTORY;
    IndexComponentRegistry public immutable COMPONENT_REGISTRY;
    ILiquidityPoolRegistry public immutable POOL_REGISTRY;
    IFacetRegistry public immutable FACET_REGISTRY;
    address public immutable USDC;

    // ========================================================================
    // State — DAO-managed DEX configuration
    // ========================================================================

    /// @notice dexId → DexConfig. Populated by the DAO for each registered DEX.
    mapping(bytes32 dexId => DexConfig config) public dexConfigs;

    /// @notice Index type identifier → set of Index contract addresses belonging to that type
    mapping(bytes32 indexTypeId => EnumerableSet.AddressSet indices) private _indexTypeIndices;

    /// @notice Timestamp of the last cumulative rebalance per index type
    mapping(bytes32 indexTypeId => uint256 timestamp) public lastRebalanceTimestamp;

    /// @notice Global reentrancy guard — prevents cross-type reentrancy via DEX router callbacks
    bool private _locked;

    /// @notice Cursor tracking how many gardens have been processed in the current batch round.
    ///         0 means either no round is in progress or the last round just finished.
    mapping(bytes32 indexTypeId => uint256 cursor) public gardenCursor;

    /// @notice Max gardens per batch for each index type. Set by the DAO.
    mapping(bytes32 indexTypeId => uint256 batchSize) public maxGardensPerBatch;

    // ========================================================================
    // Events
    // ========================================================================

    event DexConfigSet(bytes32 indexed dexId, address indexed router, DexType dexType);
    event IndexTypeRegistered(bytes32 indexed indexTypeId, address indexed indexAddress);
    event IndexTypeRemoved(bytes32 indexed indexTypeId, address indexed indexAddress);
    event CumulativeRebalanceStarted(bytes32 indexed indexTypeId, uint256 gardenCount, uint256 totalValueUsd);
    event CumulativeSwapExecuted(
        bytes32 indexed dexId,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address pool
    );
    event CumulativeRebalanceCompleted(
        bytes32 indexed indexTypeId, uint256 gardenCount, uint256 timestamp, uint256 nextRebalanceTimestamp
    );
    event GardenRedistributed(address indexed garden, uint256 shareValueUsd);
    event MaxGardensPerBatchSet(bytes32 indexed indexTypeId, uint256 batchSize);
    event BatchRebalanceCompleted(bytes32 indexed indexTypeId, uint256 cursor, uint256 totalGardens);

    // ========================================================================
    // Constructor
    // ========================================================================

    /**
     * @param initialOwner DAO address (admin functions)
     * @param indexFactory IndexFactory contract
     * @param componentRegistry IndexComponentRegistry contract
     * @param poolRegistry LiquidityPoolRegistry contract
     * @param facetRegistry FacetRegistry contract
     * @param usdc USDC token address
     */
    constructor(
        address initialOwner,
        address indexFactory,
        address componentRegistry,
        address poolRegistry,
        address facetRegistry,
        address usdc
    )
        Ownable(initialOwner)
    {
        INDEX_FACTORY = IndexFactory(indexFactory);
        COMPONENT_REGISTRY = IndexComponentRegistry(componentRegistry);
        POOL_REGISTRY = ILiquidityPoolRegistry(poolRegistry);
        FACET_REGISTRY = IFacetRegistry(facetRegistry);
        USDC = usdc;
    }

    // ========================================================================
    // Admin: DEX Configuration (DAO only)
    // ========================================================================

    /**
     * @notice Configure a DEX for use in cumulative rebalances.
     *         The DEX must already be registered in the FacetRegistry (as a DEX module facet)
     *         and in the LiquidityPoolRegistry (with swapSelector + quoteSelector).
     *
     *         After calling this, the DEX is immediately usable — no code changes.
     *
     * @param dexId DEX identifier from LiquidityPoolRegistry (e.g. keccak256("UNISWAP_V3"))
     * @param router DEX router contract address (executes swaps)
     * @param quoteFacet DEX facet contract address (provides generic QuoteInstruction-based quoting)
     * @param routerSwapSelector The router's own swap function selector (e.g. swapExactTokensForTokens.selector)
     * @param dexType Router interface type (V2_CONSTANT_PRODUCT or V3_CONCENTRATED)
     */
    function setDexConfig(
        bytes32 dexId,
        address router,
        address quoteFacet,
        bytes4 routerSwapSelector,
        DexType dexType
    )
        external
        onlyOwner
    {
        if (router == address(0) || quoteFacet == address(0) || routerSwapSelector == bytes4(0)) {
            revert Rebalancer_InvalidConfig();
        }
        if (!POOL_REGISTRY.isDexRegistered(dexId)) {
            revert Rebalancer_DexNotConfigured(dexId);
        }

        // Validate the router address has code (is a contract, not an EOA)
        if (router.code.length == 0 || quoteFacet.code.length == 0) revert Rebalancer_InvalidConfig();

        // Only allow known DEX router swap functions. Without this, a compromised owner
        // could set router = a token contract and routerSwapSelector = its transfer selector,
        // causing the next rebalance's forceApprove + router.call to move all pooled tokens.
        if (!_isApprovedSwapSelector(routerSwapSelector)) {
            revert Rebalancer_UnapprovedSwapSelector(routerSwapSelector);
        }

        dexConfigs[dexId] = DexConfig({
            router: router, quoteFacet: quoteFacet, routerSwapSelector: routerSwapSelector, dexType: dexType
        });
        emit DexConfigSet(dexId, router, dexType);
    }

    // ========================================================================
    // Admin: Batch Configuration (DAO only)
    // ========================================================================

    /// @notice Sets the max gardens per batch for a given index type.
    /// @param indexTypeId The index type identifier
    /// @param batchSize Number of gardens to process per cumulativeRebalance call
    function setMaxGardensPerBatch(bytes32 indexTypeId, uint256 batchSize) external onlyOwner {
        if (batchSize == 0) revert Rebalancer_InvalidConfig();
        maxGardensPerBatch[indexTypeId] = batchSize;
        emit MaxGardensPerBatchSet(indexTypeId, batchSize);
    }

    // ========================================================================
    // Admin: Index Type Management (DAO only)
    // ========================================================================

    function addIndexToType(bytes32 indexTypeId, address indexAddress) external onlyOwner {
        if (!INDEX_FACTORY.isIndexRegistered(indexAddress)) {
            revert Rebalancer_IndexNotRegistered(indexAddress);
        }
        if (!_indexTypeIndices[indexTypeId].add(indexAddress)) {
            revert Rebalancer_IndexAlreadyInType(indexTypeId, indexAddress);
        }
        emit IndexTypeRegistered(indexTypeId, indexAddress);
    }

    function removeIndexFromType(bytes32 indexTypeId, address indexAddress) external onlyOwner {
        if (!_indexTypeIndices[indexTypeId].remove(indexAddress)) {
            revert Rebalancer_IndexNotInType(indexTypeId, indexAddress);
        }
        emit IndexTypeRemoved(indexTypeId, indexAddress);
    }

    /// @notice Renounce ownership is disabled to prevent permanent lockout
    /// @inheritdoc Ownable
    function renounceOwnership() public pure override {
        revert Rebalancer_CannotRenounceOwnership();
    }

    function getIndicesForType(bytes32 indexTypeId) external view returns (address[] memory) {
        return _indexTypeIndices[indexTypeId].values();
    }

    function getIndexCountForType(bytes32 indexTypeId) external view returns (uint256) {
        return _indexTypeIndices[indexTypeId].length();
    }

    // ========================================================================
    // Core: Cumulative Rebalance (permissionless, time-gated)
    // ========================================================================

    /**
     * @notice Executes a cumulative rebalance. Permissionless — anyone can call after cooldown.
     * @param indexTypeId The index type to rebalance (e.g. keccak256("BLOKC2"))
     * @param deadline Unix timestamp after which swaps will revert. Set to block.timestamp + 60s
     *        to limit MEV exposure. The tx reverts if any swap's deadline has passed.
     */
    function cumulativeRebalance(bytes32 indexTypeId, uint256 deadline) external {
        if (deadline < block.timestamp) revert Rebalancer_DeadlineExpired(deadline, block.timestamp);
        if (deadline > block.timestamp + 1 hours) revert Rebalancer_DeadlineExpired(deadline, block.timestamp);

        // -- Pre-validate --
        if (_indexTypeIndices[indexTypeId].length() == 0) {
            revert Rebalancer_NoIndicesRegistered(indexTypeId);
        }

        uint256 batchSize = maxGardensPerBatch[indexTypeId];
        if (batchSize == 0) revert Rebalancer_BatchSizeNotSet(indexTypeId);

        uint256 cursor = gardenCursor[indexTypeId];

        // Only enforce 24h cooldown when starting a new round (cursor == 0)
        if (cursor == 0) {
            uint256 lastRebalance = lastRebalanceTimestamp[indexTypeId];
            uint256 nextAllowed = lastRebalance + REBALANCE_INTERVAL;
            if (block.timestamp < nextAllowed) {
                revert Rebalancer_RebalanceIntervalNotPassed(indexTypeId, lastRebalance, nextAllowed);
            }
        }

        if (_locked) revert Rebalancer_RebalanceReentrancy(indexTypeId);
        _locked = true;

        (address[] memory batch, uint256 totalGardens) = _collectGardens(indexTypeId, cursor, batchSize);
        if (totalGardens == 0) revert Rebalancer_NoGardensFound(indexTypeId);

        // If cursor is past the end (gardens were removed), reset to start a fresh round
        if (cursor >= totalGardens) cursor = 0;

        uint256 end = cursor + batchSize;
        if (end > totalGardens) end = totalGardens;

        (bytes32[] memory symbols, uint256[] memory weights) = IIndex(_indexTypeIndices[indexTypeId].at(0)).getWeights();

        bool usdcIsComponent = _isSymbolInSet(symbols, _USDC_SYMBOL);

        // Cache every price once before any valuation or swap so that valueBefore and
        // valueAfter (and all amount conversions) use the SAME oracle snapshot. Without
        // this, a Chainlink round updating between the pre-swap and post-swap reads makes
        // the MAX_VALUE_LOSS_BPS guard compare inconsistently-priced values — it could
        // falsely pass (masking loss) or falsely revert (M4 fix, mirrors IndexBase).
        // fetchPrice is non-view (writes the oracle cache) so it is called exactly once
        // per symbol, before any swaps execute.
        PriceSnapshot memory snapshot = _cachePrices(symbols, usdcIsComponent);

        (uint256[] memory contributions, uint256 totalValueUsd) =
            _snapshotAndPullTokens(batch, symbols, usdcIsComponent, snapshot);

        if (totalValueUsd == 0) revert Rebalancer_ZeroTotalValue(indexTypeId);

        if (cursor == 0) {
            emit CumulativeRebalanceStarted(indexTypeId, totalGardens, totalValueUsd);
        }

        _executeBatchRebalance(symbols, weights, usdcIsComponent, snapshot, totalValueUsd, deadline);

        _redistribute(batch, symbols, usdcIsComponent, contributions, totalValueUsd);

        // Advance cursor or complete round (before dropping lock for defense-in-depth)
        if (end >= totalGardens) {
            gardenCursor[indexTypeId] = 0;
            lastRebalanceTimestamp[indexTypeId] = block.timestamp;
            emit CumulativeRebalanceCompleted(
                indexTypeId, totalGardens, block.timestamp, block.timestamp + REBALANCE_INTERVAL
            );
        } else {
            gardenCursor[indexTypeId] = end;
            emit BatchRebalanceCompleted(indexTypeId, end, totalGardens);
        }

        _locked = false;
    }

    // ========================================================================
    // Internal: Garden Collection & Token Pulling
    // ========================================================================

    /// @notice Collects a batch of gardens for the given index type using paginated queries.
    ///         Returns the batch slice and the total count across all indices.
    function _collectGardens(
        bytes32 indexTypeId,
        uint256 cursor,
        uint256 batchSize
    )
        private
        view
        returns (address[] memory batch, uint256 totalGardens)
    {
        EnumerableSet.AddressSet storage indices = _indexTypeIndices[indexTypeId];
        uint256 indexCount = indices.length();

        // Count total gardens across all indices, caching per-index totals to avoid
        // redundant getConnectedGardens(0,0) calls in the second loop.
        uint256[] memory indexTotals = new uint256[](indexCount);
        for (uint256 i = 0; i < indexCount; i++) {
            (, uint256 idxTotal) = IIndex(indices.at(i)).getConnectedGardens(0, 0);
            indexTotals[i] = idxTotal;
            totalGardens += idxTotal;
        }

        if (totalGardens == 0) return (new address[](0), 0);
        if (cursor >= totalGardens) cursor = 0;

        uint256 end = cursor + batchSize;
        if (end > totalGardens) end = totalGardens;
        uint256 needed = end - cursor;

        batch = new address[](needed);
        uint256 filled = 0;
        uint256 globalCursor = 0;

        for (uint256 i = 0; i < indexCount && filled < needed; i++) {
            uint256 idxTotal = indexTotals[i];

            // Skip indices entirely before cursor
            if (globalCursor + idxTotal <= cursor) {
                globalCursor += idxTotal;
                continue;
            }

            uint256 idxStart = globalCursor < cursor ? cursor - globalCursor : 0;
            uint256 remaining = needed - filled;
            uint256 take = idxStart + remaining > idxTotal ? idxTotal - idxStart : remaining;
            if (take == 0) {
                globalCursor += idxTotal;
                continue;
            }

            (address[] memory page,) = IIndex(indices.at(i)).getConnectedGardens(idxStart, take);
            for (uint256 j = 0; j < page.length && filled < needed; j++) {
                // Dedup: skip gardens already in the batch (from a prior index)
                bool seen = false;
                for (uint256 k = 0; k < filled; k++) {
                    if (batch[k] == page[j]) {
                        seen = true;
                        break;
                    }
                }
                if (!seen) batch[filled++] = page[j];
            }

            globalCursor += idxTotal;
        }

        // Trim if we couldn't fill the entire batch
        if (filled < needed) {
            assembly { mstore(batch, filled) }
        }
    }

    /// @notice Fetches every oracle price needed by the rebalance exactly once and returns
    ///         them as a snapshot. All subsequent valuations reuse this snapshot.
    /// @param symbols The index component symbols (all registered components).
    /// @param usdcIsComponent Whether USDC is one of the index components.
    function _cachePrices(
        bytes32[] memory symbols,
        bool usdcIsComponent
    )
        private
        returns (PriceSnapshot memory snapshot)
    {
        snapshot.components = new uint256[](symbols.length);
        snapshot.usdc = 0;

        for (uint256 i = 0; i < symbols.length; i++) {
            snapshot.components[i] = COMPONENT_REGISTRY.fetchPrice(symbols[i]);
            if (usdcIsComponent && symbols[i] == _USDC_SYMBOL) snapshot.usdc = snapshot.components[i];
        }

        // USDC is not an index component but its value still counts toward the portfolio
        // (and it funds deficit purchases). Cache its price too when a feed is registered.
        if (!usdcIsComponent && COMPONENT_REGISTRY.isComponentRegistered(_USDC_SYMBOL)) {
            snapshot.usdc = COMPONENT_REGISTRY.fetchPrice(_USDC_SYMBOL);
        }
    }

    function _snapshotAndPullTokens(
        address[] memory gardens,
        bytes32[] memory symbols,
        bool usdcIsComponent,
        PriceSnapshot memory snapshot
    )
        private
        returns (uint256[] memory contributions, uint256 totalValueUsd)
    {
        contributions = new uint256[](gardens.length);
        totalValueUsd = 0;

        for (uint256 i = 0; i < gardens.length; i++) {
            uint256 gardenTotal = 0;
            for (uint256 j = 0; j < symbols.length; j++) {
                address token = COMPONENT_REGISTRY.getComponentAddress(symbols[j]);
                uint256 balance = IERC20(token).balanceOf(gardens[i]);
                if (balance > 0) {
                    uint256 price = snapshot.components[j];
                    uint8 decimals = IERC20Metadata(token).decimals();
                    gardenTotal += Math.mulDiv(balance, price, 10 ** decimals, Math.Rounding.Floor);
                }
            }
            if (!usdcIsComponent && snapshot.usdc > 0) {
                uint256 usdcBalance = IERC20(USDC).balanceOf(gardens[i]);
                if (usdcBalance > 0) {
                    uint8 usdcDecimals = IERC20Metadata(USDC).decimals();
                    gardenTotal += Math.mulDiv(usdcBalance, snapshot.usdc, 10 ** usdcDecimals, Math.Rounding.Floor);
                }
            }
            contributions[i] = gardenTotal;
            totalValueUsd += gardenTotal;
        }

        // gardens[] is built from DAO-registered Index contracts and contains only BLOK vault
        // contracts that have explicitly approved this Rebalancer to pull tokens (Slither: arbitrary-send-erc20, false
        // positive).
        for (uint256 i = 0; i < gardens.length; i++) {
            for (uint256 j = 0; j < symbols.length; j++) {
                address token = COMPONENT_REGISTRY.getComponentAddress(symbols[j]);
                uint256 balance = IERC20(token).balanceOf(gardens[i]);
                if (balance > 0) IERC20(token).safeTransferFrom(gardens[i], address(this), balance);
            }
            if (!usdcIsComponent) {
                uint256 usdcBalance = IERC20(USDC).balanceOf(gardens[i]);
                if (usdcBalance > 0) IERC20(USDC).safeTransferFrom(gardens[i], address(this), usdcBalance);
            }
        }
    }

    // ========================================================================
    // Internal: Cumulative State Computation
    // ========================================================================

    function _computeCumulativeState(
        bytes32[] memory symbols,
        uint256[] memory weights,
        uint256 totalValueUsd,
        bool usdcIsComponent,
        PriceSnapshot memory snapshot
    )
        private
        returns (uint256[] memory currentValues, uint256[] memory targetValues, uint256 recomputedTotal)
    {
        currentValues = new uint256[](symbols.length);
        targetValues = new uint256[](symbols.length);
        recomputedTotal = 0;

        for (uint256 i = 0; i < symbols.length; i++) {
            address token = COMPONENT_REGISTRY.getComponentAddress(symbols[i]);
            uint256 balance = IERC20(token).balanceOf(address(this));
            uint256 price = snapshot.components[i];
            uint8 decimals = IERC20Metadata(token).decimals();
            currentValues[i] = Math.mulDiv(balance, price, 10 ** decimals, Math.Rounding.Floor);
            recomputedTotal += currentValues[i];
        }

        if (!usdcIsComponent && snapshot.usdc > 0) {
            uint256 usdcBalance = IERC20(USDC).balanceOf(address(this));
            if (usdcBalance > 0) {
                uint8 usdcDecimals = IERC20Metadata(USDC).decimals();
                recomputedTotal += Math.mulDiv(usdcBalance, snapshot.usdc, 10 ** usdcDecimals, Math.Rounding.Floor);
            }
        }

        uint256 effectiveTotal = recomputedTotal > 0 ? recomputedTotal : totalValueUsd;
        for (uint256 i = 0; i < symbols.length; i++) {
            targetValues[i] = Math.mulDiv(effectiveTotal, weights[i], PRECISION, Math.Rounding.Floor);
        }
    }

    function _computeTotalValue(
        bytes32[] memory symbols,
        bool usdcIsComponent,
        PriceSnapshot memory snapshot
    )
        private
        returns (uint256 total)
    {
        total = 0;
        for (uint256 i = 0; i < symbols.length; i++) {
            address token = COMPONENT_REGISTRY.getComponentAddress(symbols[i]);
            uint256 balance = IERC20(token).balanceOf(address(this));
            if (balance > 0) {
                uint256 price = snapshot.components[i];
                uint8 decimals = IERC20Metadata(token).decimals();
                total += Math.mulDiv(balance, price, 10 ** decimals, Math.Rounding.Floor);
            }
        }
        if (!usdcIsComponent && snapshot.usdc > 0) {
            uint256 usdcBalance = IERC20(USDC).balanceOf(address(this));
            if (usdcBalance > 0) {
                uint8 usdcDecimals = IERC20Metadata(USDC).decimals();
                total += Math.mulDiv(usdcBalance, snapshot.usdc, 10 ** usdcDecimals, Math.Rounding.Floor);
            }
        }
    }

    /// @notice Runs the post-pull phase of a cumulative rebalance: computes the current
    ///         state, executes the surplus/deficit swaps, and enforces the MAX_VALUE_LOSS_BPS
    ///         guard (reverting on excessive loss). Isolated so cumulativeRebalance stays
    ///         within EVM stack limits; all pricing uses the cached snapshot.
    function _executeBatchRebalance(
        bytes32[] memory symbols,
        uint256[] memory weights,
        bool usdcIsComponent,
        PriceSnapshot memory snapshot,
        uint256 totalValueUsd,
        uint256 deadline
    )
        private
    {
        (uint256[] memory currentValues, uint256[] memory targetValues, uint256 totalValueAfterPull) =
            _computeCumulativeState(symbols, weights, totalValueUsd, usdcIsComponent, snapshot);

        (TokenExcess[] memory excess, TokenDeficit[] memory deficit) =
            _identifyExcessAndDeficit(symbols, currentValues, targetValues, snapshot);

        if (deficit.length > 0) {
            if (excess.length > 0) {
                _executeSwaps(excess, deficit, deadline, snapshot.usdc);
            } else {
                _sweepUsdcToDeficits(deficit, deadline, snapshot.usdc);
            }
        }

        uint256 valueAfter = _computeTotalValue(symbols, usdcIsComponent, snapshot);
        if (valueAfter < Math.mulDiv(totalValueAfterPull, 10_000 - MAX_VALUE_LOSS_BPS, 10_000, Math.Rounding.Floor)) {
            revert Rebalancer_ExcessiveValueLoss(totalValueAfterPull, valueAfter);
        }
    }

    // ========================================================================
    // Internal: Excess/Deficit Identification
    // ========================================================================

    struct TokenExcess {
        bytes32 symbol;
        address token;
        uint256 sellAmount;
        uint256 sellValueUsd;
        uint256 price; // cached oracle price (same snapshot as valueBefore/valueAfter)
    }

    struct TokenDeficit {
        bytes32 symbol;
        address token;
        uint256 buyValueUsd;
        uint256 price; // cached oracle price (same snapshot as valueBefore/valueAfter)
    }

    function _identifyExcessAndDeficit(
        bytes32[] memory symbols,
        uint256[] memory currentValues,
        uint256[] memory targetValues,
        PriceSnapshot memory snapshot
    )
        private
        returns (TokenExcess[] memory excess, TokenDeficit[] memory deficit)
    {
        uint256 excessCount = 0;
        uint256 deficitCount = 0;

        for (uint256 i = 0; i < symbols.length; i++) {
            uint256 threshold = Math.mulDiv(targetValues[i], BALANCE_THRESHOLD_BPS, 10_000, Math.Rounding.Ceil);
            if (currentValues[i] > targetValues[i] + threshold) excessCount++;
            else if (currentValues[i] + threshold < targetValues[i]) deficitCount++;
        }

        excess = new TokenExcess[](excessCount);
        deficit = new TokenDeficit[](deficitCount);
        uint256 ei = 0;
        uint256 di = 0;

        for (uint256 i = 0; i < symbols.length; i++) {
            uint256 threshold = Math.mulDiv(targetValues[i], BALANCE_THRESHOLD_BPS, 10_000, Math.Rounding.Ceil);
            if (currentValues[i] > targetValues[i] + threshold) {
                uint256 sellValueUsd = currentValues[i] - targetValues[i];
                address token = COMPONENT_REGISTRY.getComponentAddress(symbols[i]);
                uint256 price = snapshot.components[i];
                uint8 decimals = IERC20Metadata(token).decimals();
                uint256 sellAmount = Math.mulDiv(sellValueUsd, 10 ** decimals, price, Math.Rounding.Floor);
                excess[ei++] = TokenExcess({
                    symbol: symbols[i], token: token, sellAmount: sellAmount, sellValueUsd: sellValueUsd, price: price
                });
            } else if (currentValues[i] + threshold < targetValues[i]) {
                uint256 buyValueUsd = targetValues[i] - currentValues[i];
                deficit[di++] = TokenDeficit({
                    symbol: symbols[i],
                    token: COMPONENT_REGISTRY.getComponentAddress(symbols[i]),
                    buyValueUsd: buyValueUsd,
                    price: snapshot.components[i]
                });
            }
        }
    }

    // ========================================================================
    // Internal: Swap Execution (registry-driven, no DEX-specific code)
    // ========================================================================

    struct SwapRoute {
        bytes32 dexId;
        address pool;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 expectedOut;
    }

    function _executeSwaps(
        TokenExcess[] memory excess,
        TokenDeficit[] memory deficit,
        uint256 deadline,
        uint256 usdcPrice
    )
        private
    {
        // Phase 1: Direct swaps — excess → deficit via direct pools only
        for (uint256 ei = 0; ei < excess.length; ei++) {
            uint256 remainingSellAmount = excess[ei].sellAmount;
            uint256 remainingSellValue = excess[ei].sellValueUsd;
            uint256 sellPrice = excess[ei].price;

            for (uint256 di = 0; di < deficit.length; di++) {
                if (remainingSellAmount == 0) break;
                if (deficit[di].buyValueUsd == 0) continue;

                address[] memory directPools = POOL_REGISTRY.getPoolsForPair(excess[ei].token, deficit[di].token);
                if (directPools.length == 0) continue;

                uint8 sellDecimals = IERC20Metadata(excess[ei].token).decimals();
                uint256 swapValueUsd =
                    remainingSellValue < deficit[di].buyValueUsd ? remainingSellValue : deficit[di].buyValueUsd;
                uint256 swapAmountIn = Math.mulDiv(swapValueUsd, 10 ** sellDecimals, sellPrice, Math.Rounding.Floor);
                if (swapAmountIn > remainingSellAmount) swapAmountIn = remainingSellAmount;
                if (swapAmountIn == 0) continue;

                SwapRoute memory route = _evaluatePools(directPools, excess[ei].token, deficit[di].token, swapAmountIn);
                if (route.pool == address(0)) continue;

                uint256 minOut = Math.mulDiv(route.expectedOut, 95, 100);
                uint256 actualAmountOut = _executeSwapRoute(route, minOut, deadline);

                remainingSellAmount -= route.amountIn;
                remainingSellValue -= Math.mulDiv(route.amountIn, sellPrice, 10 ** sellDecimals, Math.Rounding.Floor);

                uint256 buyPrice = deficit[di].price;
                uint8 buyDecimals = IERC20Metadata(deficit[di].token).decimals();
                uint256 boughtValueUsd = Math.mulDiv(actualAmountOut, buyPrice, 10 ** buyDecimals, Math.Rounding.Floor);
                if (boughtValueUsd < deficit[di].buyValueUsd) {
                    deficit[di].buyValueUsd -= boughtValueUsd;
                } else {
                    deficit[di].buyValueUsd = 0;
                }
            }

            // Phase 2: Remaining excess → consolidated to USDC in one swap per token.
            if (remainingSellAmount > 0 && excess[ei].token != USDC) {
                uint256 balance = IERC20(excess[ei].token).balanceOf(address(this));
                uint256 sellAmount = remainingSellAmount < balance ? remainingSellAmount : balance;
                if (sellAmount > 0) {
                    address[] memory usdcPools = POOL_REGISTRY.getPoolsForPair(excess[ei].token, USDC);
                    SwapRoute memory usdcRoute = _evaluatePools(usdcPools, excess[ei].token, USDC, sellAmount);
                    if (usdcRoute.pool != address(0)) {
                        uint256 minOut = Math.mulDiv(usdcRoute.expectedOut, 95, 100);
                        _executeSwapRoute(usdcRoute, minOut, deadline);
                    }
                }
            }
        }

        // Phase 3: Buy deficits with USDC
        _sweepUsdcToDeficits(deficit, deadline, usdcPrice);
    }

    function _sweepUsdcToDeficits(TokenDeficit[] memory deficit, uint256 deadline, uint256 usdcPrice) private {
        uint256 usdcBalance = IERC20(USDC).balanceOf(address(this));
        if (usdcBalance == 0) return;

        uint8 usdcDecimals = IERC20Metadata(USDC).decimals();

        for (uint256 di = 0; di < deficit.length; di++) {
            if (usdcBalance == 0) break;
            if (deficit[di].buyValueUsd == 0 || deficit[di].token == USDC) continue;

            uint256 usdcNeeded;
            if (usdcPrice > 0) {
                // Convert the 8-decimal USD deficit value into USDC token units using the
                // actual cached USDC/USD oracle price. Fixes the hardcoded /100 assumption
                // (USDC == exactly $1.00), which under-covers deficits during any depeg.
                usdcNeeded = Math.mulDiv(deficit[di].buyValueUsd, 10 ** usdcDecimals, usdcPrice, Math.Rounding.Ceil);
            } else {
                // No USDC/USD feed registered in the ComponentRegistry — fall back to the
                // legacy assumption that 1 USDC == $1.00 (8-decimal USD value / 100 == USDC
                // units). Only reachable when USDC is neither an index component nor a
                // registered component.
                usdcNeeded = deficit[di].buyValueUsd / 100;
            }
            uint256 swapAmount = usdcBalance < usdcNeeded ? usdcBalance : usdcNeeded;
            if (swapAmount == 0) continue;

            SwapRoute memory route = _findBestSwapRoute(USDC, deficit[di].token, swapAmount);
            if (route.pool == address(0)) continue;

            uint256 minOut = Math.mulDiv(route.expectedOut, 95, 100);
            uint256 actualAmountOut = _executeSwapRoute(route, minOut, deadline);

            uint256 buyPrice = deficit[di].price;
            uint8 buyDecimals = IERC20Metadata(deficit[di].token).decimals();
            uint256 boughtValueUsd = Math.mulDiv(actualAmountOut, buyPrice, 10 ** buyDecimals, Math.Rounding.Floor);
            if (boughtValueUsd < deficit[di].buyValueUsd) {
                deficit[di].buyValueUsd -= boughtValueUsd;
            } else {
                deficit[di].buyValueUsd = 0;
            }

            usdcBalance = IERC20(USDC).balanceOf(address(this));
        }
    }

    // ========================================================================
    // Internal: Pool Discovery & Comparison (registry-driven)
    // ========================================================================

    function _findBestSwapRoute(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    )
        private
        view
        returns (SwapRoute memory bestRoute)
    {
        address[] memory pools = POOL_REGISTRY.getPoolsForPair(tokenIn, tokenOut);
        bestRoute = _evaluatePools(pools, tokenIn, tokenOut, amountIn);

        if (bestRoute.pool == address(0) && tokenIn != USDC && tokenOut != USDC) {
            address[] memory poolsToUsdc = POOL_REGISTRY.getPoolsForPair(tokenIn, USDC);
            bestRoute = _evaluatePools(poolsToUsdc, tokenIn, USDC, amountIn);
        }
    }

    /**
     * @dev Evaluates pools by calling each DEX's generic quote function via the
     *      quoteSelector from the LiquidityPoolRegistry. Fully modular — works
     *      with any DEX that registers a quoteSelector with a QuoteInstruction interface.
     */
    function _evaluatePools(
        address[] memory pools,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    )
        private
        view
        returns (SwapRoute memory bestRoute)
    {
        for (uint256 i = 0; i < pools.length; i++) {
            address pool = pools[i];
            ILiquidityPoolRegistry.PoolInfo memory info = POOL_REGISTRY.getPool(pool);
            bytes32 dexId = info.dexId;

            if (!POOL_REGISTRY.isDexActive(dexId)) continue;

            bytes4 quoteSelector = POOL_REGISTRY.getQuoteSelectorForDex(dexId);
            if (quoteSelector == bytes4(0)) continue;

            DexConfig memory cfg = dexConfigs[dexId];
            if (cfg.quoteFacet == address(0)) continue;

            address[] memory tokens = new address[](2);
            tokens[0] = tokenIn;
            tokens[1] = tokenOut;
            address[] memory pathPools = new address[](1);
            pathPools[0] = pool;

            QuoteInstruction memory qInst =
                QuoteInstruction({ amount: amountIn, tokens: tokens, pools: pathPools, exactOutput: false });

            uint256 expectedOut;
            (bool ok, bytes memory data) = cfg.quoteFacet.staticcall(abi.encodeWithSelector(quoteSelector, qInst));
            if (ok && data.length >= 32) {
                expectedOut = abi.decode(data, (uint256));
            } else {
                continue;
            }

            if (expectedOut > bestRoute.expectedOut) {
                bestRoute = SwapRoute({
                    dexId: dexId,
                    pool: pool,
                    tokenIn: tokenIn,
                    tokenOut: tokenOut,
                    amountIn: amountIn,
                    expectedOut: expectedOut
                });
            }
        }
    }

    // ========================================================================
    // Internal: Swap Execution (DexType-driven, no DEX-specific code)
    // ========================================================================

    function _executeSwapRoute(
        SwapRoute memory route,
        uint256 minOut,
        uint256 deadline
    )
        private
        returns (uint256 amountOut)
    {
        DexConfig memory cfg = dexConfigs[route.dexId];
        if (cfg.router == address(0)) {
            revert Rebalancer_DexNotConfigured(route.dexId);
        }

        IERC20(route.tokenIn).forceApprove(cfg.router, route.amountIn);

        if (cfg.dexType == DexType.V2_STANDARD) {
            amountOut = _swapV2Standard(cfg.router, cfg.routerSwapSelector, route, minOut, deadline);
        } else if (cfg.dexType == DexType.V2_CONSTANT_PRODUCT) {
            amountOut = _swapV2Style(cfg.router, cfg.routerSwapSelector, route, minOut, deadline);
        } else if (cfg.dexType == DexType.V3_CONCENTRATED) {
            amountOut = _swapV3Style(cfg.router, cfg.routerSwapSelector, route, minOut, deadline);
        } else {
            revert Rebalancer_DexTypeNotSupported(uint8(cfg.dexType));
        }

        if (amountOut < minOut) {
            revert Rebalancer_InsufficientSwapOutput(route.tokenOut, amountOut, minOut);
        }

        emit CumulativeSwapExecuted(route.dexId, route.tokenIn, route.tokenOut, route.amountIn, amountOut, route.pool);
    }

    /**
     * @dev V2-standard swap (5-param): swapExactTokensForTokens(amountIn, minOut, path, to, deadline).
     *      Works for Uniswap V2, SushiSwap V2, and any DEX following the standard Uniswap V2 interface.
     */
    function _swapV2Standard(
        address router,
        bytes4 selector,
        SwapRoute memory route,
        uint256 minOut,
        uint256 deadline
    )
        private
        returns (uint256 amountOut)
    {
        address[] memory path = new address[](2);
        path[0] = route.tokenIn;
        path[1] = route.tokenOut;

        uint256 balanceBefore = IERC20(route.tokenOut).balanceOf(address(this));

        (bool success, bytes memory ret) =
            router.call(abi.encodeWithSelector(selector, route.amountIn, minOut, path, address(this), deadline));
        if (!success) {
            bytes memory reason = ret.length > 0 ? ret : bytes("V2 swap failed");
            revert Rebalancer_SwapFailed(route.tokenIn, route.tokenOut, reason);
        }

        amountOut = IERC20(route.tokenOut).balanceOf(address(this)) - balanceBefore;
    }

    /**
     * @dev V2-style swap (6-param): swapExactTokensForTokensSupportingFeeOnTransferTokens.
     *      Used for Camelot V2. The extra referrer param is included in the encoding.
     */
    function _swapV2Style(
        address router,
        bytes4 selector,
        SwapRoute memory route,
        uint256 minOut,
        uint256 deadline
    )
        private
        returns (uint256 amountOut)
    {
        address[] memory path = new address[](2);
        path[0] = route.tokenIn;
        path[1] = route.tokenOut;

        uint256 balanceBefore = IERC20(route.tokenOut).balanceOf(address(this));

        (bool success, bytes memory ret) = router.call(
            abi.encodeWithSelector(selector, route.amountIn, minOut, path, address(this), address(0), deadline)
        );
        if (!success) {
            bytes memory reason = ret.length > 0 ? ret : bytes("V2 swap failed");
            revert Rebalancer_SwapFailed(route.tokenIn, route.tokenOut, reason);
        }

        amountOut = IERC20(route.tokenOut).balanceOf(address(this)) - balanceBefore;
    }

    /**
     * @dev V3-style swap: calls the router using the configured selector.
     *      Encodes as exactInputSingle(tokenIn, tokenOut, fee, recipient, deadline,
     *      amountIn, minOut, sqrtPriceLimitX96). Fee is read from the pool on-chain.
     *      Works for any DEX that follows Uniswap V3's exactInputSingle struct layout
     *      (8 params with uint24 fee). For DEXs with a different struct (e.g. Camelot V3's
     *      7-param variant), the DAO should configure a V2_CONSTANT_PRODUCT type and provide
     *      the correct selector + encoding via routerSwapSelector.
     */
    function _swapV3Style(
        address router,
        bytes4 selector,
        SwapRoute memory route,
        uint256 minOut,
        uint256 deadline
    )
        private
        returns (uint256 amountOut)
    {
        // Read fee tier from the pool on-chain (works for V3-style pools; reverts on failure)
        (bool feeOk, bytes memory feeData) = route.pool.staticcall(abi.encodeWithSignature("fee()"));
        if (!feeOk || feeData.length < 32) {
            revert Rebalancer_SwapFailed(route.tokenIn, route.tokenOut, "V3 pool fee() lookup failed");
        }
        uint24 fee = abi.decode(feeData, (uint24));

        uint256 balanceBefore = IERC20(route.tokenOut).balanceOf(address(this));

        (bool success, bytes memory ret) = router.call(
            abi.encodeWithSelector(
                selector,
                route.tokenIn,
                route.tokenOut,
                fee,
                address(this),
                deadline,
                route.amountIn,
                minOut,
                uint160(0)
            )
        );
        if (!success) {
            bytes memory reason = ret.length > 0 ? ret : bytes("V3 swap failed");
            revert Rebalancer_SwapFailed(route.tokenIn, route.tokenOut, reason);
        }

        amountOut = IERC20(route.tokenOut).balanceOf(address(this)) - balanceBefore;
    }

    // ========================================================================
    // Internal: Redistribution
    // ========================================================================

    function _redistribute(
        address[] memory gardens,
        bytes32[] memory symbols,
        bool usdcIsComponent,
        uint256[] memory contributions,
        uint256 totalValueUsd
    )
        private
    {
        bytes32[] memory allSymbols = symbols;
        if (!usdcIsComponent) {
            allSymbols = new bytes32[](symbols.length + 1);
            for (uint256 i = 0; i < symbols.length; i++) {
                allSymbols[i] = symbols[i];
            }
            allSymbols[symbols.length] = _USDC_SYMBOL;
        }

        address[] memory tokenAddrs = new address[](allSymbols.length);
        for (uint256 j = 0; j < allSymbols.length; j++) {
            if (allSymbols[j] == _USDC_SYMBOL) {
                tokenAddrs[j] = USDC;
            } else {
                tokenAddrs[j] = COMPONENT_REGISTRY.getComponentAddress(allSymbols[j]);
            }
        }

        uint256[] memory originalBalances = new uint256[](allSymbols.length);
        for (uint256 j = 0; j < allSymbols.length; j++) {
            originalBalances[j] = IERC20(tokenAddrs[j]).balanceOf(address(this));
        }

        for (uint256 i = 0; i < gardens.length; i++) {
            uint256 share = Math.mulDiv(contributions[i], PRECISION, totalValueUsd, Math.Rounding.Floor);
            bool isLast = (i == gardens.length - 1);

            for (uint256 j = 0; j < allSymbols.length; j++) {
                if (originalBalances[j] == 0) continue;

                uint256 gardenAllocation;
                if (isLast) {
                    gardenAllocation = IERC20(tokenAddrs[j]).balanceOf(address(this));
                } else {
                    gardenAllocation = Math.mulDiv(originalBalances[j], share, PRECISION, Math.Rounding.Floor);
                }
                if (gardenAllocation > 0) {
                    IERC20(tokenAddrs[j]).safeTransfer(gardens[i], gardenAllocation);
                }
            }

            emit GardenRedistributed(gardens[i], contributions[i]);
        }
    }

    // ========================================================================
    // Internal: Helpers
    // ========================================================================

    function _isSymbolInSet(bytes32[] memory symbols, bytes32 target) private pure returns (bool) {
        for (uint256 i = 0; i < symbols.length; i++) {
            if (symbols[i] == target) return true;
        }
        return false;
    }

    /// @dev Returns true if the selector matches a known DEX router swap function.
    function _isApprovedSwapSelector(bytes4 selector) private pure returns (bool) {
        return selector == bytes4(0x38ed1739) // swapExactTokensForTokens
            || selector == bytes4(0xac3893ba) // swapExactTokensForTokensSupportingFeeOnTransferTokens
            || selector == bytes4(0x6c42f2b1) // swapExactTokensForTokensSupportingFeeOnTransferTokensV2
            || selector == bytes4(0x414bf389) // exactInputSingle (Uniswap V3 struct)
            || selector == bytes4(0xbc651188); // exactInputSingle (Camelot V3 7-param struct)
    }
}
