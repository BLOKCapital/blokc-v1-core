// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CirculatingSupply
/// @notice Adapter (server) updates token supplies; anyone can read supply by symbol.
contract CirculatingSupply {
    ///////////////
    // Errors   ///
    ///////////////
    error NotUpdater();
    error SupplyNotAvailable();
    error LengthMismatch();

    mapping(string => uint256) private supply;
    mapping(string => uint256) private lastUpdated;

    /// @dev Sum of all token supplies. Anyone can read via getTotalSupply() (minimal gas).
    uint256 private totalCirculatingSupply;

    ///@dev my address will be the updater initially
    address private immutable updater; 

    event SupplyUpdated(string indexed symbol, uint256 newSupply, uint256 timestamp);

    modifier onlyUpdater() {
        if(msg.sender != updater) {
            revert NotUpdater();
        }
        _;
    }

    constructor(address _updater) {
        updater = _updater;
    }

    ///@dev Anyone can call this to get the circulating supply for a token by symbol.
    ///     Reverts if the adapter has never updated that symbol.
    ///@param symbol Token symbol (e.g. "ETH", "BTC") as used when the adapter called updateBatch
    ///@return Circulating supply in wei/smallest unit (uint256)
    function getSupply(string calldata symbol) external view returns (uint256) {
        if (lastUpdated[symbol] == 0) {
            revert SupplyNotAvailable();
        }
        return supply[symbol];
    }

    /// @dev Anyone can call to get the sum of circulating supply across all tokens. O(1) read, low gas.
    function getTotalSupply() external view returns (uint256) {
        return totalCirculatingSupply;
    }

    ///@dev Only the adapter (updater) can call this to update or add circulating supply for tokens.
    ///     Use the same symbol strings here that callers will use in getSupply(symbol).
    function updateBatch(string[] calldata symbols, uint256[] calldata supplies) external onlyUpdater {
        if(symbols.length != supplies.length) {
            revert LengthMismatch();
        }
        
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