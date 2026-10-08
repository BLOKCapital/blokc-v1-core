// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when component token address is zero
error IndexComponentRegistry_InvalidComponentAddress();

/// @notice Thrown when price feed address is zero
error IndexComponentRegistry_InvalidPriceFeedAddress();

/// @notice Thrown when attempting to register an already registered component
error IndexComponentRegistry_ComponentAlreadyRegistered();

/// @notice Thrown when attempting to operate on an unregistered component
error IndexComponentRegistry_ComponentNotRegistered();

/// @notice Thrown when component and price feed array lengths don't match
error IndexComponentRegistry_TotalComponentsAndPriceFeedsMismatch();

/// @notice Thrown when component and symbol array lengths don't match
error IndexComponentRegistry_TotalComponentsAndSymbolsMismatch();

error IndexComponentRegistry__FeedFrozenError(address token);

error IndexComponentRegistry__InvalidFeedResponseError(address token);

error IndexComponentRegistry__UnknownFeedError(address token);

/// @notice Thrown when renounceOwnership is called (disabled to prevent permanent lockout)
error IndexComponentRegistry_CannotRenounceOwnership();

/// @notice Thrown when component heartbeat is outside allowed bounds
/// @param heartbeat The invalid heartbeat value
error IndexComponentRegistry__InvalidHeartbeat(uint256 heartbeat);

/// @notice Thrown when a deviation band override is outside allowed bounds
/// @param bps The invalid band value
error IndexComponentRegistry__InvalidDeviationBps(uint256 bps);

/// @notice Thrown when the deviation auto-accept timeout is outside allowed bounds
/// @param durationSeconds The invalid timeout value
error IndexComponentRegistry__InvalidDeviationTimeout(uint256 durationSeconds);

/// @notice Thrown when a price deviates too far from the EMA (potential manipulation)
/// @param token The token address
/// @param price The current price
/// @param emaPrice The exponentially smoothed average price
error IndexComponentRegistry__PriceDeviationTooHigh(address token, uint256 price, uint256 emaPrice);

/**
 * @title IndexComponentRegistry
 * @notice Registry contract for managing index components and their associated price feeds. This contract allows the
 * owner to register and unregister components, which consist of a symbol, token address, and Chainlink price feed
 * address. The registry provides functions for retrieving component data and validating component registration status.
 * It uses OpenZeppelin's Ownable for access control and EnumerableSet for efficient management of registered component
 * addresses.
 */
contract IndexComponentRegistry is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Represents an index component with its symbol, token address, and price feed
    /// @param symbol Ticker symbol of the component encoded as bytes32 (e.g., bytes32("WETH"))
    /// @param tokenAddress ERC20 token contract address
    /// @param priceFeedAddress Chainlink AggregatorV3 price feed address
    struct Component {
        bytes32 symbol;
        address tokenAddress;
        address priceFeedAddress;
        uint256 heartbeat;
    }

    struct FeedResponse {
        uint80 roundId;
        int256 answer;
        uint256 timestamp;
        uint80 answeredInRound;
        bool success;
    }

    struct OracleRecord {
        uint128 price;
        uint48 timestamp;
        uint48 lastUpdated;
        uint8 decimals;
        bool isFeedWorking;
        // --- slot boundary (32 bytes above) ---
        uint80 roundId;
        // --- new slot ---
        uint128 emaPrice; // exponentially smoothed price (same decimals as price)
        uint48 emaUpdatedAt; // timestamp of last EMA update
        uint48 firstDeviationAt; // timestamp of the first consecutive deviation rejection (0 = none)
        uint32 consecutiveRejections; // consecutive deviation rejections (observability)
    }

    /// @notice Emitted when a component is registered
    /// @param symbol Ticker symbol of the component
    /// @param tokenAddress ERC20 token contract address
    /// @param priceFeedAddress Chainlink AggregatorV3 price feed address
    event ComponentRegistered(bytes32 indexed symbol, address indexed tokenAddress, address priceFeedAddress);

    /// @notice Emitted when a component is unregistered
    /// @param symbol Ticker symbol of the component
    /// @param tokenAddress ERC20 token contract address that was removed
    event ComponentUnregistered(bytes32 indexed symbol, address indexed tokenAddress);

    /// @notice Emitted when an oracle feed has failed consecutively beyond the failure threshold
    /// @param feed The price feed address that is consistently failing
    /// @param reason The revert reason from the latest failed call
    event OracleFailureThresholdReached(address indexed feed, bytes reason);

    /// @notice Emitted when a fresh round is rejected for deviating from the EMA beyond the band
    /// @param token The component token address
    /// @param price The rejected round's price
    /// @param emaPrice The EMA the price was compared against
    /// @param deviationBps The deviation in basis points
    /// @param maxDeviationBps The configured band for this symbol
    event PriceDeviationRejected(
        address indexed token, uint256 price, uint256 emaPrice, uint256 deviationBps, uint256 maxDeviationBps
    );

    /// @notice Emitted when a stale record's cached price is served instead of reverting
    /// @param token The component token address
    /// @param lastPriceTimestamp Chainlink round timestamp of the served (cached) price
    /// @param age Seconds since that round
    /// @param servedPrice The cached price being served
    event FeedStale(address indexed token, uint256 lastPriceTimestamp, uint256 age, uint256 servedPrice);

    /// @notice Emitted when a deviating market price is auto-accepted after the deviation timeout
    /// @param token The component token address
    /// @param price The accepted market price
    /// @param previousEmaPrice The EMA before the reseed
    event DeviationTimeoutAccepted(address indexed token, uint256 price, uint256 previousEmaPrice);

    /// @notice Emitted when the owner force-reseeds a component's EMA to the current round
    /// @param token The component token address
    /// @param price The accepted round's price
    /// @param previousEmaPrice The EMA before the reseed
    event FeedResynced(address indexed token, uint256 price, uint256 previousEmaPrice);

    /// @notice Emitted when the owner sets a per-symbol deviation band
    event MaxDeviationBpsSet(bytes32 indexed symbol, uint256 bps);

    /// @notice Emitted when the owner changes the deviation auto-accept timeout
    event DeviationTimeoutSet(uint256 durationSeconds);

    /// @notice Mapping from symbol to component data
    mapping(bytes32 => Component) private _components;
    mapping(address => OracleRecord) private oracleRecords;

    /// @notice Set of all registered component token addresses
    /// @dev Provides efficient lookup and iteration
    EnumerableSet.AddressSet private _componentAddresses;

    /// @notice Tracks consecutive failures per price feed for detecting permanently broken oracles
    mapping(address => uint256) private _feedFailures;

    /// @notice Per-symbol deviation band override in basis points (0 = use DEFAULT_MAX_DEVIATION_BPS)
    mapping(bytes32 => uint256) private _maxDeviationBps;

    /// @notice How long a deviating price must persist (since the last accepted round) before it
    ///      is auto-accepted and the EMA re-seeded to market — the self-healing bound that
    ///      replaces the old permanent freeze
    uint256 public deviationTimeout = DEFAULT_DEVIATION_TIMEOUT;

    // ============================================================================
    // Constants
    // ============================================================================

    /// @notice Minimum allowed heartbeat: 30 minutes (prevents DoS from overly tight checks)
    uint256 public constant MIN_HEARTBEAT = 30 minutes;

    /// @notice Maximum allowed heartbeat: 26 hours (Chainlink max is ~24h + buffer)
    uint256 public constant MAX_HEARTBEAT = 26 hours;

    /// @notice Number of consecutive oracle failures before emitting a warning event
    uint256 public constant FAILURE_THRESHOLD = 10;

    /// @notice EMA smoothing factor in basis points (200 = 2% per update)
    uint256 public constant EMA_ALPHA = 200;

    /// @notice Maximum allowed deviation from EMA in basis points (1000 = 10%)
    uint256 public constant MAX_EMA_DEVIATION = 1000;

    /// @notice Default deviation band applied when no per-symbol override is set
    uint256 public constant DEFAULT_MAX_DEVIATION_BPS = 1000;

    /// @notice Bounds for per-symbol deviation bands
    uint256 public constant MIN_MAX_DEVIATION_BPS = 100;
    uint256 public constant MAX_MAX_DEVIATION_BPS = 50_000;

    /// @notice A single-round deviation at or beyond this, measured RELATIVE TO THE EMA
    ///      (10_000 bps = price doubled, 5_000 bps = price halved), is treated as a broken feed
    ///      or unit change: rejected, never auto-accepted (owner must forceResync)
    uint256 public constant MAX_AUTO_ACCEPT_DEVIATION_BPS = 10_000;

    /// @notice Default deviation auto-accept timeout (matches the shortest component heartbeat)
    uint256 public constant DEFAULT_DEVIATION_TIMEOUT = 1 hours;

    /// @notice Bounds for the deviation auto-accept timeout
    uint256 public constant MIN_DEVIATION_TIMEOUT = 30 minutes;
    uint256 public constant MAX_DEVIATION_TIMEOUT = 24 hours;

    /// @notice Constructs the IndexComponentRegistry
    /// @param initialOwner Address of the contract owner
    constructor(address initialOwner) Ownable(initialOwner) { }

    /// @notice Registers multiple components with their corresponding price feeds
    /// @param components Array of Component structs to register
    /// @dev Only callable by owner. Components must not already be registered.
    function registerComponents(Component[] memory components) public onlyOwner {
        uint256 totalComponents = components.length;
        for (uint256 i = 0; i < totalComponents; i++) {
            Component memory component = components[i];
            if (component.tokenAddress == address(0)) revert IndexComponentRegistry_InvalidComponentAddress();
            if (component.priceFeedAddress == address(0)) revert IndexComponentRegistry_InvalidPriceFeedAddress();
            if (component.heartbeat < MIN_HEARTBEAT || component.heartbeat > MAX_HEARTBEAT) {
                revert IndexComponentRegistry__InvalidHeartbeat(component.heartbeat);
            }
            if (_components[component.symbol].tokenAddress != address(0)) {
                revert IndexComponentRegistry_ComponentAlreadyRegistered();
            }

            AggregatorV3Interface newFeed = AggregatorV3Interface(component.priceFeedAddress);

            (FeedResponse memory currResponse, FeedResponse memory prevResponse,) = _fetchFeedResponses(newFeed, 0);

            if (!_isFeedWorking(currResponse, prevResponse)) {
                revert IndexComponentRegistry__InvalidFeedResponseError(component.tokenAddress);
            }
            if (_isPriceStale(currResponse.timestamp, component.heartbeat)) {
                revert IndexComponentRegistry__FeedFrozenError(component.tokenAddress);
            }
            _componentAddresses.add(component.tokenAddress);
            _components[component.symbol] = component;
            oracleRecords[component.tokenAddress].decimals = newFeed.decimals();
            OracleRecord memory _oracleRecord = oracleRecords[component.tokenAddress];
            _processFeedResponses(component.tokenAddress, component, currResponse, prevResponse, _oracleRecord);
            emit ComponentRegistered(component.symbol, component.tokenAddress, component.priceFeedAddress);
        }
    }

    /// @notice Unregisters multiple components from the registry
    /// @param symbols Array of component symbols to unregister
    /// @dev Only callable by owner. All components must be registered.
    function unregisterComponents(bytes32[] memory symbols) public onlyOwner {
        uint256 totalSymbols = symbols.length;
        for (uint256 i = 0; i < totalSymbols; i++) {
            bytes32 symbol = symbols[i];
            address tokenAddress = _components[symbol].tokenAddress;
            if (tokenAddress == address(0)) {
                revert IndexComponentRegistry_ComponentNotRegistered();
            }
            address feedAddress = _components[symbol].priceFeedAddress;
            _componentAddresses.remove(tokenAddress);
            delete oracleRecords[tokenAddress];
            delete _feedFailures[feedAddress];
            delete _maxDeviationBps[symbol];
            delete _components[symbol];
            emit ComponentUnregistered(symbol, tokenAddress);
        }
    }

    /// @notice Renounce ownership is disabled to prevent permanent lockout
    /// @inheritdoc Ownable
    function renounceOwnership() public pure override {
        revert IndexComponentRegistry_CannotRenounceOwnership();
    }

    /// @notice Fetches and caches the latest oracle price for a registered component
    /// @param _symbol Component symbol (registry key; token address is derived from `_components[_symbol]`)
    /// @return price Latest or cached price (aggregator raw units; decimals in `getOracleRecord`)
    function fetchPrice(bytes32 _symbol) public returns (uint256 price) {
        address _token = _components[_symbol].tokenAddress;
        if (_token == address(0)) revert IndexComponentRegistry_ComponentNotRegistered();

        OracleRecord memory oracleInfo = oracleRecords[_token];
        Component memory componentInfo = _components[_symbol];

        if (oracleInfo.lastUpdated == block.timestamp) {
            price = oracleInfo.price;
        } else {
            if (oracleInfo.lastUpdated == 0) {
                revert IndexComponentRegistry__UnknownFeedError(_token);
            }

            (FeedResponse memory currResponse, FeedResponse memory prevResponse, bool updated) =
                _fetchFeedResponses(AggregatorV3Interface(componentInfo.priceFeedAddress), oracleInfo.roundId);

            if (!updated) {
                // No new round (feed down or carried-over price): serve the cached price instead
                // of reverting — a stale feed degrades gracefully rather than freezing consumers.
                if (_isPriceStale(oracleInfo.timestamp, componentInfo.heartbeat)) {
                    emit FeedStale(
                        _token, oracleInfo.timestamp, block.timestamp - oracleInfo.timestamp, oracleInfo.price
                    );
                }
                price = oracleInfo.price;
            } else {
                price = _processFeedResponses(_token, componentInfo, currResponse, prevResponse, oracleInfo);
            }
        }
    }

    /// @notice Returns the number of consecutive failures for a given price feed
    /// @param feed The price feed address
    /// @return The consecutive failure count
    function getFeedFailures(address feed) public view returns (uint256) {
        return _feedFailures[feed];
    }

    /// @notice Sets a per-symbol deviation band override in basis points
    /// @param _symbol Component symbol (must be registered)
    /// @param _bps Deviation band in basis points (100–50_000)
    function setMaxDeviationBps(bytes32 _symbol, uint256 _bps) external onlyOwner {
        if (_components[_symbol].tokenAddress == address(0)) {
            revert IndexComponentRegistry_ComponentNotRegistered();
        }
        if (_bps < MIN_MAX_DEVIATION_BPS || _bps > MAX_MAX_DEVIATION_BPS) {
            revert IndexComponentRegistry__InvalidDeviationBps(_bps);
        }
        _maxDeviationBps[_symbol] = _bps;
        emit MaxDeviationBpsSet(_symbol, _bps);
    }

    /// @notice Returns the effective deviation band for a symbol (override or default)
    function getMaxDeviationBps(bytes32 _symbol) public view returns (uint256) {
        return _bandFor(_symbol);
    }

    /// @notice Sets how long a deviating price must persist (since the last accepted round)
    ///      before it is auto-accepted and the EMA re-seeded to market
    function setDeviationTimeout(uint256 _seconds) external onlyOwner {
        if (_seconds < MIN_DEVIATION_TIMEOUT || _seconds > MAX_DEVIATION_TIMEOUT) {
            revert IndexComponentRegistry__InvalidDeviationTimeout(_seconds);
        }
        deviationTimeout = _seconds;
        emit DeviationTimeoutSet(_seconds);
    }

    /// @notice Returns the current deviation auto-accept timeout
    function getDeviationTimeout() external view returns (uint256) {
        return deviationTimeout;
    }

    /// @notice Owner escape hatch: re-seeds a component's price and EMA to the latest feed round,
    ///      bypassing the deviation guard. Use when a feed is reporting a genuine sustained move
    ///      beyond MAX_AUTO_ACCEPT_DEVIATION_BPS (which is never auto-accepted).
    /// @dev Reverts if the feed has no fresh valid round since the last accepted one — there is
    ///      then no market price to resync to.
    function forceResync(bytes32 _symbol) external onlyOwner {
        address _token = _components[_symbol].tokenAddress;
        if (_token == address(0)) {
            revert IndexComponentRegistry_ComponentNotRegistered();
        }

        OracleRecord memory oracleInfo = oracleRecords[_token];
        (FeedResponse memory currResponse,, bool updated) =
            _fetchFeedResponses(AggregatorV3Interface(_components[_symbol].priceFeedAddress), oracleInfo.roundId);

        if (!updated || !_isValidResponse(currResponse)) {
            revert IndexComponentRegistry__InvalidFeedResponseError(_token);
        }

        uint256 currentPrice = uint256(currResponse.answer);
        uint256 previousEma = uint256(oracleInfo.emaPrice);
        _storePrice(_token, currentPrice, currResponse.timestamp, currResponse.roundId);
        _reseedEma(_token, currentPrice);
        _updateFeedStatus(_token, oracleInfo, true);
        _resetDeviationTracking(_token);
        emit FeedResynced(_token, currentPrice, previousEma);
    }

    /// @notice Strict read: like `fetchPrice` but reverts while the symbol has an unresolved
    ///      deviation rejection (firstDeviationAt != 0). For consumers that prefer loud failure
    ///      over stale-price service.
    function fetchPriceStrict(bytes32 _symbol) external returns (uint256 price) {
        price = fetchPrice(_symbol);
        address _token = _components[_symbol].tokenAddress;
        OracleRecord memory record = oracleRecords[_token];
        if (record.firstDeviationAt != 0) {
            revert IndexComponentRegistry__PriceDeviationTooHigh(_token, record.price, record.emaPrice);
        }
    }

    function _fetchFeedResponses(
        AggregatorV3Interface oracle,
        uint80 lastRoundId
    )
        internal
        returns (FeedResponse memory currResponse, FeedResponse memory prevResponse, bool updated)
    {
        try oracle.latestRoundData() returns (
            uint80 roundId,
            int256 answer,
            uint256, /* startedAt */
            uint256 timestamp,
            uint80 answeredInRound
        ) {
            // Reject carried-over prices: per Chainlink, if answeredInRound < roundId,
            // the answer is from a previous round and the feed may be stale.
            if (answeredInRound < roundId) {
                return (currResponse, prevResponse, false);
            }
            // Reject malformed answers BEFORE any conversion consumes them: a negative answer
            // would panic the int→uint cast and an answer beyond uint128 would panic SafeCast
            // later, permanently bricking this symbol (record.roundId never advances). A
            // malformed round degrades to the cached-price path instead; the failure counter is
            // deliberately NOT reset so a persistently broken feed still trips the threshold.
            if (answer <= 0 || answer > int256(uint256(type(uint128).max))) {
                return (currResponse, prevResponse, false);
            }
            // Successful response: reset failure counter
            delete _feedFailures[address(oracle)];

            currResponse.roundId = roundId;
            currResponse.answer = answer;
            currResponse.timestamp = timestamp;
            currResponse.answeredInRound = answeredInRound;
            currResponse.success = true;
        } catch (bytes memory reason) {
            // Track consecutive failures; emit warning event at threshold
            uint256 failures = _feedFailures[address(oracle)] + 1;
            _feedFailures[address(oracle)] = failures;
            if (failures >= FAILURE_THRESHOLD) {
                emit OracleFailureThresholdReached(address(oracle), reason);
            }
            return (currResponse, prevResponse, false);
        }

        if (lastRoundId == 0 || currResponse.roundId > lastRoundId) {
            if (currResponse.roundId != 0) {
                unchecked {
                    try oracle.getRoundData(currResponse.roundId - 1) returns (
                        uint80 prevRoundId,
                        int256 prevAnswer,
                        uint256, /* startedAt */
                        uint256 prevTimestamp,
                        uint80 prevAnsweredInRound
                    ) {
                        // Reject carried-over prices in previous round too
                        if (prevAnsweredInRound < prevRoundId) return (currResponse, prevResponse, false);
                        prevResponse.roundId = prevRoundId;
                        prevResponse.answer = prevAnswer;
                        prevResponse.timestamp = prevTimestamp;
                        prevResponse.answeredInRound = prevAnsweredInRound;
                        prevResponse.success = true;
                    } catch {
                        // An UNREADABLE previous round (Chainlink phase boundary: roundId jumps
                        // phase and round-1 does not exist; pruned history) must not veto the
                        // already-validated current round — treating it as "prev = current" lets
                        // the standard validity checks run on the current round alone instead of
                        // freezing the registry on the cached price until the next round lands.
                        prevResponse = currResponse;
                    }
                }
            }
            updated = true;
        }
    }

    function _isFeedWorking(
        FeedResponse memory _currentResponse,
        FeedResponse memory _prevResponse
    )
        internal
        view
        returns (bool isFeedWorking)
    {
        isFeedWorking = _isValidResponse(_currentResponse) && _isValidResponse(_prevResponse);
    }

    function _isValidResponse(FeedResponse memory _response) internal view returns (bool isValidResponse) {
        isValidResponse = (_response.success) && (_response.roundId != 0) && (_response.timestamp != 0)
            && (_response.timestamp <= block.timestamp) && (_response.answer > 0);
    }

    /// @notice Checks if a price is stale relative to its heartbeat
    /// @dev Uses >= to match Chainlink's reference implementation: a price exactly at the
    ///      heartbeat boundary is considered stale (defense-in-depth).
    function _isPriceStale(uint256 _priceTimestamp, uint256 _heartbeat) internal view returns (bool isPriceStale) {
        isPriceStale = block.timestamp - _priceTimestamp >= _heartbeat;
    }

    function _processFeedResponses(
        address _token,
        Component memory componentInfo,
        FeedResponse memory _currResponse,
        FeedResponse memory _prevResponse,
        OracleRecord memory oracleRecord
    )
        internal
        returns (uint256 price)
    {
        bool feedWorking = _isFeedWorking(_currResponse, _prevResponse);
        bool roundFresh = !_isPriceStale(_currResponse.timestamp, componentInfo.heartbeat);
        uint256 currentPrice = uint256(_currResponse.answer);
        uint256 band = _bandFor(componentInfo.symbol);
        uint256 devBps = _deviationBps(currentPrice, uint256(oracleRecord.emaPrice));

        if (feedWorking && roundFresh && devBps <= band) {
            if (!oracleRecord.isFeedWorking) {
                _updateFeedStatus(_token, oracleRecord, true);
            }
            _storePrice(_token, currentPrice, _currResponse.timestamp, _currResponse.roundId);
            _updateEma(_token, currentPrice, oracleRecord);
            _resetDeviationTracking(_token);
            return currentPrice;
        }

        if (oracleRecord.isFeedWorking) {
            _updateFeedStatus(_token, oracleRecord, false);
        }

        if (feedWorking && devBps > band) {
            // Fresh but deviating round: track the rejection streak. The self-healing clock is
            // anchored to `firstDeviationAt` — the first read that observed THIS deviation — so
            // the market price is adopted only after it has genuinely persisted for
            // `deviationTimeout` across reads; the first deviating read can never satisfy it.
            // Until then every consumer is served the cached price; no keeper or owner action is
            // ever needed to recover from an ordinary market move.
            if (oracleRecords[_token].firstDeviationAt == 0) {
                oracleRecords[_token].firstDeviationAt = SafeCast.toUint48(block.timestamp);
            }
            oracleRecords[_token].consecutiveRejections = oracleRecords[_token].consecutiveRejections + 1;
            emit PriceDeviationRejected(_token, currentPrice, uint256(oracleRecord.emaPrice), devBps, band);

            if (
                devBps < MAX_AUTO_ACCEPT_DEVIATION_BPS
                    && block.timestamp - oracleRecords[_token].firstDeviationAt >= deviationTimeout
            ) {
                uint256 previousEma = uint256(oracleRecord.emaPrice);
                _storePrice(_token, currentPrice, _currResponse.timestamp, _currResponse.roundId);
                _reseedEma(_token, currentPrice);
                _updateFeedStatus(_token, oracleRecord, true);
                _resetDeviationTracking(_token);
                emit DeviationTimeoutAccepted(_token, currentPrice, previousEma);
                return currentPrice;
            }
        }

        // Stale-serve: every rejected/invalid path degrades to the cached price instead of
        // reverting — consumers stay live and monitoring gets the event. A feed that never
        // publishes fresh rounds is bounded by FeedStale events and isFeedWorking == false.
        if (_isPriceStale(oracleRecord.timestamp, componentInfo.heartbeat)) {
            emit FeedStale(_token, oracleRecord.timestamp, block.timestamp - oracleRecord.timestamp, oracleRecord.price);
        }
        return oracleRecord.price;
    }

    /// @notice Returns the deviation of a price from the EMA in basis points, measured RELATIVE
    ///      TO THE EMA (the trusted reference): a price doubled = 10_000 bps, halved = 5_000 bps,
    ///      and arbitrarily large deviations (broken feeds, unit changes) are representable so
    ///      MAX_AUTO_ACCEPT_DEVIATION_BPS can bind. (0 if the EMA is uninitialized, so first
    ///      registration always accepts.)
    function _deviationBps(uint256 _currentPrice, uint256 _emaPrice) internal pure returns (uint256) {
        if (_emaPrice == 0) {
            return 0;
        }
        uint256 delta = _currentPrice > _emaPrice ? _currentPrice - _emaPrice : _emaPrice - _currentPrice;
        return Math.mulDiv(delta, 1e4, _emaPrice, Math.Rounding.Floor);
    }

    /// @notice Returns the deviation band for a symbol (per-symbol override, else the default)
    function _bandFor(bytes32 _symbol) internal view returns (uint256) {
        uint256 bpsOverride = _maxDeviationBps[_symbol];
        return bpsOverride != 0 ? bpsOverride : DEFAULT_MAX_DEVIATION_BPS;
    }

    /// @notice Force-writes the EMA to a price, bypassing the deviation guard (auto-accept /
    ///      forceResync paths)
    function _reseedEma(address _token, uint256 _price) internal {
        oracleRecords[_token].emaPrice = SafeCast.toUint128(_price);
        oracleRecords[_token].emaUpdatedAt = SafeCast.toUint48(block.timestamp);
    }

    function _resetDeviationTracking(address _token) internal {
        oracleRecords[_token].firstDeviationAt = 0;
        oracleRecords[_token].consecutiveRejections = 0;
    }

    /// @notice Updates the EMA for a token's price.
    /// @dev EMA = (price * alpha) + (oldEma * (1 - alpha)), where alpha = EMA_ALPHA / 1e4.
    ///      On first call (emaPrice == 0), initializes to the current price.
    function _updateEma(address _token, uint256 _price, OracleRecord memory oracleRecord) internal {
        if (oracleRecord.emaPrice == 0) {
            // First update: initialize EMA to current price
            oracleRecords[_token].emaPrice = SafeCast.toUint128(_price);
            oracleRecords[_token].emaUpdatedAt = SafeCast.toUint48(block.timestamp);
        } else {
            // newEma = (price * alpha + oldEma * (1e4 - alpha)) / 1e4
            uint256 newEma =
                Math.mulDiv(_price, EMA_ALPHA, 1e4) + Math.mulDiv(uint256(oracleRecord.emaPrice), 1e4 - EMA_ALPHA, 1e4);
            oracleRecords[_token].emaPrice = SafeCast.toUint128(newEma);
            oracleRecords[_token].emaUpdatedAt = SafeCast.toUint48(block.timestamp);
        }
    }

    function _updateFeedStatus(address _token, OracleRecord memory _oracle, bool _isWorking) internal {
        oracleRecords[_token].isFeedWorking = _isWorking;
    }

    function _storePrice(address _token, uint256 _price, uint256 _timestamp, uint80 roundId) internal {
        OracleRecord storage record = oracleRecords[_token];
        record.price = SafeCast.toUint128(_price);
        record.timestamp = SafeCast.toUint48(_timestamp);
        record.lastUpdated = SafeCast.toUint48(block.timestamp);
        record.roundId = roundId;
    }

    /// @notice Checks if a component is registered
    /// @param symbol Symbol to check
    /// @return True if the component is registered, false otherwise
    function isComponentRegistered(bytes32 symbol) public view returns (bool) {
        return _components[symbol].tokenAddress != address(0);
    }

    /// @notice Returns the price feed address for a specific component
    /// @param symbol The component symbol
    /// @return The Chainlink price feed address for the component
    function getComponentSymbolToPriceFeedAddress(bytes32 symbol) public view returns (address) {
        if (_components[symbol].tokenAddress == address(0)) revert IndexComponentRegistry_ComponentNotRegistered();
        return _components[symbol].priceFeedAddress;
    }

    /// @notice Returns price feed addresses for multiple components
    /// @param symbols Array of component symbols
    /// @return priceFeedAddresses Array of corresponding Chainlink price feed addresses
    /// @dev All components must be registered. Returns parallel array to input.
    function getPriceFeedAddresses(bytes32[] memory symbols) public view returns (address[] memory) {
        uint256 totalSymbols = symbols.length;
        address[] memory priceFeedAddresses = new address[](totalSymbols);
        for (uint256 i = 0; i < totalSymbols; i++) {
            if (_components[symbols[i]].tokenAddress == address(0)) {
                revert IndexComponentRegistry_ComponentNotRegistered();
            }
            priceFeedAddresses[i] = _components[symbols[i]].priceFeedAddress;
            if (priceFeedAddresses[i] == address(0)) {
                revert IndexComponentRegistry_InvalidPriceFeedAddress();
            }
        }
        return priceFeedAddresses;
    }

    /// @notice Returns the token address for a specific component
    /// @param symbol The component symbol
    /// @return The token address for the component
    function getComponentAddress(bytes32 symbol) public view returns (address) {
        address tokenAddress = _components[symbol].tokenAddress;
        if (tokenAddress == address(0)) revert IndexComponentRegistry_ComponentNotRegistered();
        return tokenAddress;
    }

    /// @notice Returns the heartbeat (staleness threshold) for a specific component
    /// @param symbol The component symbol
    /// @return The heartbeat in seconds
    function getComponentHeartbeat(bytes32 symbol) public view returns (uint256) {
        if (_components[symbol].tokenAddress == address(0)) revert IndexComponentRegistry_ComponentNotRegistered();
        return _components[symbol].heartbeat;
    }

    function getOracleRecord(bytes32 symbol) public view returns (OracleRecord memory) {
        address _token = _components[symbol].tokenAddress;
        return oracleRecords[_token];
    }
}
