// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IndexComponentRegistry } from "src/indices/IndexComponentRegistry.sol";
import { ICirculatingSupply } from "src/interfaces/ICirculatingSupply.sol";

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
error CirculatingSupply_SupplyNotAvailable(bytes32 symbol);

/// @notice Thrown when supply data is older than the staleness threshold
error CirculatingSupply_StaleSupplyData(bytes32 symbol, uint256 lastUpdatedAt, uint256 currentTime);

/// @notice Thrown when attempting to set updater to the zero address
error CirculatingSupply_InvalidUpdater();

/// @notice Thrown when array lengths do not match
error CirculatingSupply_LengthMismatch();

/// @notice Thrown when a non-updater tries to call an updater-only function
error CirculatingSupply_OnlyUpdater();

/// @notice Thrown when a symbol is not registered in the component registry
error CirculatingSupply_SymbolNotRegistered(bytes32 symbol);

/**
 * @title CirculatingSupply
 * @notice A simple contract to track the circulating supply of various tokens, allowing an authorized updater to set
 * supply values. This contract maintains a mapping of token symbols to their circulating supply and the last update
 * timestamp. It includes access control to restrict updates to an authorized address and provides a function for
 * retrieving the current supply for a given token symbol. The contract emits an event whenever a supply update occurs,
 * allowing off-chain services to listen for changes.
 */
contract CirculatingSupply is ICirculatingSupply, Ownable {
    /// @notice Circulating supply for each token symbol (raw token units)
    mapping(bytes32 => uint256) private supply;

    /// @notice Block timestamp of the last supply update for each token symbol
    mapping(bytes32 => uint256) private lastUpdated;

    /// @notice Address authorized to push supply updates
    address public updater;

    /// @notice Registry used to validate symbols before accepting supply updates
    IndexComponentRegistry public immutable componentRegistry;

    /// @dev Sum of all token supplies. Anyone can read via getTotalSupply() (minimal gas).
    uint256 private totalCirculatingSupply;

    /// @dev Supply entries older than this threshold are rejected during index calculations
    uint256 public constant STALENESS_THRESHOLD = 24 hours;

    /// @notice Emitted when a token's circulating supply is updated
    /// @param symbol Token symbol that was updated
    /// @param newSupply New circulating supply value
    /// @param timestamp Block timestamp of the update
    event SupplyUpdated(bytes32 indexed symbol, uint256 newSupply, uint256 timestamp);

    /// @notice Emitted when the authorized updater address is changed
    /// @param oldUpdater Address of the previous updater
    /// @param newUpdater Address of the new updater
    event UpdaterChanged(address indexed oldUpdater, address indexed newUpdater);

    /// @notice Restricts access to the authorized updater
    modifier onlyUpdater() {
        if (msg.sender != updater) {
            revert CirculatingSupply_OnlyUpdater();
        }
        _;
    }

    /// @notice Constructor sets the initial owner and updater address
    /// @param initialOwner Address of the contract owner
    /// @param _updater Address authorized to push supply updates
    constructor(address initialOwner, address _updater, address _componentRegistry) Ownable(initialOwner) {
        updater = _updater;
        componentRegistry = IndexComponentRegistry(_componentRegistry);
    }

    ///@dev Anyone can call this to get the circulating supply for a token by symbol.
    ///     Reverts if the adapter has never updated that symbol.
    ///@param symbol Token symbol (e.g. bytes32("ETH")) as used when the adapter called updateBatch
    ///@return Circulating supply in wei/smallest unit (uint256)
    function getSupply(bytes32 symbol) external view override returns (uint256) {
        if (lastUpdated[symbol] == 0) {
            revert CirculatingSupply_SupplyNotAvailable(symbol);
        }

        if (block.timestamp - lastUpdated[symbol] > STALENESS_THRESHOLD) {
            revert CirculatingSupply_StaleSupplyData(symbol, lastUpdated[symbol], block.timestamp);
        }
        return supply[symbol];
    }

    /// @notice Updates circulating supply for multiple tokens in a single transaction
    /// @param symbols Array of token symbols to update
    /// @param supplies Array of new circulating supply values (parallel to symbols)
    function updateBatch(bytes32[] calldata symbols, uint256[] calldata supplies) external onlyUpdater {
        if (symbols.length != supplies.length) revert CirculatingSupply_LengthMismatch();
        uint256 time = block.timestamp;
        for (uint256 i = 0; i < symbols.length; i++) {
            if (!componentRegistry.isComponentRegistered(symbols[i])) {
                revert CirculatingSupply_SymbolNotRegistered(symbols[i]);
            }
            uint256 oldSupply = supply[symbols[i]];
            totalCirculatingSupply = totalCirculatingSupply - oldSupply + supplies[i];
            supply[symbols[i]] = supplies[i];
            lastUpdated[symbols[i]] = time;
            emit SupplyUpdated(symbols[i], supplies[i], time);
        }
    }

    /// @notice Returns the raw circulating supply for a token symbol without staleness checks
    /// @param symbol Token symbol (e.g. bytes32("ETH"))
    function getRawSupply(bytes32 symbol) external view returns (uint256) {
        return supply[symbol];
    }

    /// @notice Returns the block timestamp of the last supply update for a token symbol
    /// @param symbol Token symbol (e.g. bytes32("ETH"))
    function getLastUpdated(bytes32 symbol) external view returns (uint256) {
        return lastUpdated[symbol];
    }

    /// @notice Returns the sum of all tracked token circulating supplies
    function getTotalSupply() external view returns (uint256) {
        return totalCirculatingSupply;
    }

    function updateUpdater(address _updater) public onlyOwner {
        if (_updater == address(0)) revert CirculatingSupply_InvalidUpdater();
        emit UpdaterChanged(updater, _updater);
        updater = _updater;
    }
}
