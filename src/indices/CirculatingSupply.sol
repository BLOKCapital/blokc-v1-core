// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CirculatingSupply {
    mapping(string => uint256) public supply;
    mapping(string => uint256) public lastUpdated;

    ///@dev my address will be the updater initially
    address public updater;

    event SupplyUpdated(string indexed symbol, uint256 newSupply, uint256 timestamp);

    modifier onlyUpdater() {
        require(msg.sender == updater, "Not updater");
        _;
    }

    constructor() {
        updater = msg.sender; // change later with setUpdater() if needed
    }

    ///@dev in case we need to change the updater address
    function setUpdater(address newUpdater) external {
        require(msg.sender == updater, "Not updater");
        updater = newUpdater;
    }

    ///@dev call the individual function to get the supply of a specific token
    ///@return supply in bigint format
    function getSupply(string calldata symbol) external view returns (uint256) {
        uint256 tokenSupply = supply[symbol];
        require(tokenSupply != 0 || lastUpdated[symbol] != 0, "Supply not available");
        return tokenSupply;
    }

    ///@dev adapter will call this to update the supply of a specific token
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

// Address: 0x01590A36B357cc54d4c4DCA16631596E943C29FD
