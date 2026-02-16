//SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    @title IndexComponentRegistry
    @author BLOK Capital DAO
    @notice Registry for approved index components and their Chainlink price feeds
    @dev Manages a whitelist of ERC20 tokens that can be included in indices.
         Each component is paired with a Chainlink price feed for accurate pricing.
         This is NOT upgradeable - it's a simple Ownable contract.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
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

contract IndexComponentRegistry is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct Component {
        string symbol;
        address tokenAddress;
        address priceFeedAddress;
        uint256 heartbeat;
    }

    struct FeedResponse {
        uint80 roundId;
        int256 answer;
        uint256 timestamp;
        bool success;
    }

    struct OracleRecord {
        uint96 price;
        uint32 timestamp;
        uint32 lastUpdated;
        uint80 roundId;
        uint8 decimals;
        bool isFeedWorking;
    }

    mapping(string => Component) private _components;
    mapping(address => OracleRecord) private oracleRecords;

    /// @notice Set of all registered component token addresses
    /// @dev Provides efficient lookup and iteration
    EnumerableSet.AddressSet private _componentAddresses;

    uint256 public constant MAX_PRICE_DEVIATION_FROM_PREVIOUS_ROUND = 5000; // 50%

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
        }
    }

    /// @notice Unregisters multiple components from the registry
    /// @param symbols Array of component symbols to unregister
    /// @dev Only callable by owner. All components must be registered.
    function unregisterComponents(string[] memory symbols) public onlyOwner {
        uint256 totalSymbols = symbols.length;
        for (uint256 i = 0; i < totalSymbols; i++) {
            string memory symbol = symbols[i];
            address tokenAddress = _components[symbol].tokenAddress;
            if (tokenAddress == address(0)) {
                revert IndexComponentRegistry_ComponentNotRegistered();
            }
            _componentAddresses.remove(tokenAddress);
            delete oracleRecords[tokenAddress];
            delete _components[symbol];
        }
    }

    function fetchPrice(address _token, string memory _symbol) public returns (uint256 price) {
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
                if (_isPriceStale(oracleInfo.timestamp, componentInfo.heartbeat)) {
                    revert IndexComponentRegistry__FeedFrozenError(_token);
                }
                price = oracleInfo.price;
            } else {
                price = _processFeedResponses(_token, componentInfo, currResponse, prevResponse, oracleInfo);
            }
        }
    }

    function _fetchFeedResponses(
        AggregatorV3Interface oracle,
        uint80 lastRoundId
    )
        internal
        view
        returns (FeedResponse memory currResponse, FeedResponse memory prevResponse, bool updated)
    {
        try oracle.latestRoundData() returns (
            uint80 roundId,
            int256 answer,
            uint256, /* startedAt */
            uint256 timestamp,
            uint80 /* answeredInRound */
        ) {
            currResponse.roundId = roundId;
            currResponse.answer = answer;
            currResponse.timestamp = timestamp;
            currResponse.success = true;
        } catch {
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
                        uint80 /* answeredInRound */
                    ) {
                        prevResponse.roundId = prevRoundId;
                        prevResponse.answer = prevAnswer;
                        prevResponse.timestamp = prevTimestamp;
                        prevResponse.success = true;
                    } catch { }
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
            && (_response.timestamp <= block.timestamp) && (_response.answer != 0);
    }

    function _isPriceStale(uint256 _priceTimestamp, uint256 _heartbeat) internal view returns (bool isPriceStale) {
        isPriceStale = block.timestamp - _priceTimestamp > _heartbeat;
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
        bool isValidResponse = _isFeedWorking(_currResponse, _prevResponse)
            && !_isPriceStale(_currResponse.timestamp, componentInfo.heartbeat)
            && !_isPriceChangeAboveMaxDeviation(_currResponse, _prevResponse);

        if (isValidResponse) {
            if (!oracleRecord.isFeedWorking) {
                _updateFeedStatus(_token, oracleRecord, true);
            }
            _storePrice(_token, uint256(_currResponse.answer), _currResponse.timestamp, _currResponse.roundId);
            price = uint256(_currResponse.answer);
        } else {
            if (oracleRecord.isFeedWorking) {
                _updateFeedStatus(_token, oracleRecord, false);
            }
            if (_isPriceStale(oracleRecord.timestamp, componentInfo.heartbeat)) {
                revert IndexComponentRegistry__FeedFrozenError(_token);
            }
            price = oracleRecord.price;
        }
    }

    function _isPriceChangeAboveMaxDeviation(
        FeedResponse memory _currResponse,
        FeedResponse memory _prevResponse
    )
        internal
        pure
        returns (bool isPriceChangeAboveMaxDeviation)
    {
        uint256 minPrice = Math.min(uint256(_currResponse.answer), uint256(_prevResponse.answer));
        uint256 maxPrice = Math.max(uint256(_currResponse.answer), uint256(_prevResponse.answer));
        // q
        /*
         * Use the larger price as the denominator:
         * - If price decreased, the percentage deviation is in relation to the previous price.
         * - If price increased, the percentage deviation is in relation to the current price.
         */
        uint256 percentDeviation = ((maxPrice - minPrice) * 1e4) / maxPrice;

        isPriceChangeAboveMaxDeviation = percentDeviation > MAX_PRICE_DEVIATION_FROM_PREVIOUS_ROUND;
    }

    function _updateFeedStatus(address _token, OracleRecord memory _oracle, bool _isWorking) internal {
        oracleRecords[_token].isFeedWorking = _isWorking;
    }

    function _storePrice(address _token, uint256 _price, uint256 _timestamp, uint80 roundId) internal {
        OracleRecord storage record = oracleRecords[_token];
        record.price = uint96(_price);
        record.timestamp = uint32(_timestamp);
        record.lastUpdated = uint32(block.timestamp);
        record.roundId = roundId;
    }

    /// @notice Checks if a component is registered
    /// @param symbol Symbol to check
    /// @return True if the component is registered, false otherwise
    function isComponentRegistered(string memory symbol) public view returns (bool) {
        return _components[symbol].tokenAddress != address(0);
    }

    /// @notice Returns the price feed address for a specific component
    /// @param symbol The component symbol
    /// @return The Chainlink price feed address for the component
    function getComponentSymbolToPriceFeedAddress(string memory symbol) public view returns (address) {
        if (_components[symbol].tokenAddress == address(0)) revert IndexComponentRegistry_ComponentNotRegistered();
        return _components[symbol].priceFeedAddress;
    }

    /// @notice Returns price feed addresses for multiple components
    /// @param symbols Array of component symbols
    /// @return priceFeedAddresses Array of corresponding Chainlink price feed addresses
    /// @dev All components must be registered. Returns parallel array to input.
    function getPriceFeedAddresses(string[] memory symbols) public view returns (address[] memory) {
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
    function getComponentAddress(string memory symbol) public view returns (address) {
        address tokenAddress = _components[symbol].tokenAddress;
        if (tokenAddress == address(0)) revert IndexComponentRegistry_ComponentNotRegistered();
        return tokenAddress;
    }
    function getOracleRecord(string memory symbol) public view returns (OracleRecord memory) {
        address _token = _components[symbol].tokenAddress;
        return oracleRecords[_token];
    }
    
}
