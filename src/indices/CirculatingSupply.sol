// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when supply data has not been set for a symbol
error CirculatingSupply_SupplyNotAvailable(string symbol);

/// @notice Thrown when supply data is older than the staleness threshold
error CirculatingSupply_StaleSupplyData(string symbol, uint256 lastUpdatedAt, uint256 currentTime);

/// @notice Thrown when attempting to set updater to the zero address
error CirculatingSupply_InvalidUpdater();

/// @notice Thrown when array lengths do not match
error CirculatingSupply_LengthMismatch();

/// @notice Thrown when a non-updater tries to call an updater-only function
error CirculatingSupply_OnlyUpdater();

/**
 * @title CirculatingSupply
 * @notice A simple contract to track the circulating supply of various tokens, allowing an authorized updater to set
 * supply values. This contract maintains a mapping of token symbols to their circulating supply and the last update
 * timestamp. It includes access control to restrict updates to an authorized address and provides a function for
 * retrieving the current supply for a given token symbol. The contract emits an event whenever a supply update occurs,
 * allowing off-chain services to listen for changes.
 */
contract CirculatingSupply {
    /// @notice Circulating supply for each token symbol (raw token units)
    mapping(string => uint256) public supply;

    /// @notice Block timestamp of the last supply update for each token symbol
    mapping(string => uint256) public lastUpdated;

    /// @notice Address authorized to push supply updates
    address public updater;

    /// @dev Sum of all token supplies. Anyone can read via getTotalSupply() (minimal gas).
    uint256 private totalCirculatingSupply;

    /// @notice Emitted when a token's circulating supply is updated
    /// @param symbol Token symbol that was updated
    /// @param newSupply New circulating supply value
    /// @param timestamp Block timestamp of the update
    event SupplyUpdated(string indexed symbol, uint256 newSupply, uint256 timestamp);
    event UpdaterChanged(address indexed oldUpdater, address indexed newUpdater);

    /// @notice Restricts access to the authorized updater
    modifier onlyUpdater() {
        if (msg.sender != updater) {
            revert CirculatingSupply_OnlyUpdater();
        }
        _;
    }

    /// @notice Constructor sets the initial updater address
    /// @param _updater Address authorized to push supply updates
    constructor(address _updater) {
        updater = _updater;
    }

    ///@dev Anyone can call this to get the circulating supply for a token by symbol.
    ///     Reverts if the adapter has never updated that symbol.
    ///@param symbol Token symbol (e.g. "ETH", "BTC") as used when the adapter called updateBatch
    ///@return Circulating supply in wei/smallest unit (uint256)
    function getSupply(string calldata symbol) external view returns (uint256) {
        if (lastUpdated[symbol] == 0) {
            revert CirculatingSupply_SupplyNotAvailable(symbol);
        }
        return supply[symbol];
    }

    /// @notice Updates circulating supply for multiple tokens in a single transaction
    /// @param symbols Array of token symbols to update
    /// @param supplies Array of new circulating supply values (parallel to symbols)
    function updateBatch(string[] calldata symbols, uint256[] calldata supplies) external onlyUpdater {
        if (symbols.length != supplies.length) revert CirculatingSupply_LengthMismatch();
        uint256 time = block.timestamp;
        for (uint256 i = 0; i < symbols.length; i++) {
            uint256 oldSupply = supply[symbols[i]];
            totalCirculatingSupply = totalCirculatingSupply - oldSupply + supplies[i];
            supply[symbols[i]] = supplies[i];
            lastUpdated[symbols[i]] = time;
            emit SupplyUpdated(symbols[i], supplies[i], time);
        }
    }
}
