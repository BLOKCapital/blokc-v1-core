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

/// @notice Stores circulating supply data for index components.
/// @dev Supply values MUST be in whole token units (NOT in native token decimals).
contract CirculatingSupply {
    /// @notice Maximum allowed age for supply data before it is considered stale
    uint256 public constant STALENESS_THRESHOLD = 24 hours;

    mapping(string => uint256) public supply;
    mapping(string => uint256) public lastUpdated;

    /// @dev The updater address — initially set to the deployer
    address public updater;

    event SupplyUpdated(string indexed symbol, uint256 newSupply, uint256 timestamp);
    event UpdaterChanged(address indexed oldUpdater, address indexed newUpdater);

    modifier onlyUpdater() {
        require(msg.sender == updater, "Not updater");
        _;
    }

    constructor() {
        updater = msg.sender;
    }

    /// @dev Transfer updater role. Cannot set to address(0) to prevent permanent lockout.
    function setUpdater(address newUpdater) external {
        require(msg.sender == updater, "Not updater");
        if (newUpdater == address(0)) revert CirculatingSupply_InvalidUpdater();
        address oldUpdater = updater;
        updater = newUpdater;
        emit UpdaterChanged(oldUpdater, newUpdater);
    }

    /// @dev Returns the circulating supply of a token. Reverts if data was never set
    ///      or if it is stale (older than STALENESS_THRESHOLD).
    /// @return supply in whole token units (not native decimals)
    function getSupply(string calldata symbol) external view returns (uint256) {
        uint256 lastUpdatedAt = lastUpdated[symbol];
        if (lastUpdatedAt == 0) revert CirculatingSupply_SupplyNotAvailable(symbol);
        if (block.timestamp - lastUpdatedAt > STALENESS_THRESHOLD) {
            revert CirculatingSupply_StaleSupplyData(symbol, lastUpdatedAt, block.timestamp);
        }
        return supply[symbol];
    }

    /// @dev Adapter calls this to batch-update supply data.
    ///      Supplies MUST be in whole token units (e.g., 120000000 for ETH, NOT 120000000e18).
    function updateBatch(string[] calldata symbols, uint256[] calldata supplies) external onlyUpdater {
        if (symbols.length != supplies.length) revert CirculatingSupply_LengthMismatch();
        uint256 time = block.timestamp;
        for (uint256 i = 0; i < symbols.length; i++) {
            supply[symbols[i]] = supplies[i];
            lastUpdated[symbols[i]] = time;
            emit SupplyUpdated(symbols[i], supplies[i], time);
        }
    }
}
