// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

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

    /// @notice Emitted when a token's circulating supply is updated
    /// @param symbol Token symbol that was updated
    /// @param newSupply New circulating supply value
    /// @param timestamp Block timestamp of the update
    event SupplyUpdated(string indexed symbol, uint256 newSupply, uint256 timestamp);

    /// @notice Restricts access to the authorized updater
    modifier onlyUpdater() {
        require(msg.sender == updater, "Not updater");
        _;
    }

    /// @notice Sets the deployer as the initial updater
    constructor() {
        updater = msg.sender;
    }

    /// @notice Transfers the updater role to a new address
    /// @param newUpdater Address of the new updater
    function setUpdater(address newUpdater) external {
        require(msg.sender == updater, "Not updater");
        updater = newUpdater;
    }

    /// @notice Returns the circulating supply for a given token symbol
    /// @param symbol Token symbol to query
    /// @return The circulating supply in raw token units
    function getSupply(string calldata symbol) external view returns (uint256) {
        uint256 tokenSupply = supply[symbol];
        require(tokenSupply != 0 || lastUpdated[symbol] != 0, "Supply not available");
        return tokenSupply;
    }

    /// @notice Updates circulating supply for multiple tokens in a single transaction
    /// @param symbols Array of token symbols to update
    /// @param supplies Array of new circulating supply values (parallel to symbols)
    function updateBatch(string[] calldata symbols, uint256[] calldata supplies) external onlyUpdater {
        require(symbols.length == supplies.length, "Length mismatch");
        uint256 time = block.timestamp;
        for (uint256 i = 0; i < symbols.length; i++) {
            supply[symbols[i]] = supplies[i];
            lastUpdated[symbols[i]] = time;
            emit SupplyUpdated(symbols[i], supplies[i], time);
        }
    }
}
