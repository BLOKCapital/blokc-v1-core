// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
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

/// @notice Thrown when supply has not been set for a symbol
error HardcodedCirculatingSupply_SupplyNotSet(bytes32 symbol);

/// @notice Thrown when array lengths do not match
error HardcodedCirculatingSupply_LengthMismatch();

/**
 * @title HardcodedCirculatingSupply
 * @author BLOK Capital DAO
 * @notice Owner-managed circulating supply provider with no staleness checks.
 * @dev Intended for testing and early-stage indices where a real-time oracle is not yet needed.
 *      The owner can set and update supplies at any time via `setSupplies()`. Unlike `CirculatingSupply`,
 *      this contract has no updater role, no staleness threshold, and no component registry validation —
 *      keeping it minimal and self-contained.
 *
 *      Implements `ICirculatingSupply` so it can be used interchangeably with `CirculatingSupply`
 *      by `MarketCapWeighted` and other calculation strategies.
 */
contract HardcodedCirculatingSupply is ICirculatingSupply, Ownable {
    /// @notice Circulating supply for each token symbol (whole token units)
    mapping(bytes32 => uint256) private _supply;

    /// @notice Whether a supply value has been set for a symbol
    mapping(bytes32 => bool) private _isSet;

    /// @notice Emitted when a token's circulating supply is set or updated
    event SupplySet(bytes32 indexed symbol, uint256 supply);

    /// @param initialOwner Address of the contract owner who can set supplies
    constructor(address initialOwner) Ownable(initialOwner) { }

    /// @notice Returns the circulating supply for a token symbol.
    /// @dev No staleness check — returns whatever value the owner last set.
    ///      Reverts if the symbol was never set.
    /// @param symbol Token symbol as bytes32
    /// @return Circulating supply in whole token units
    function getSupply(bytes32 symbol) external view override returns (uint256) {
        if (!_isSet[symbol]) revert HardcodedCirculatingSupply_SupplyNotSet(symbol);
        return _supply[symbol];
    }

    /// @notice Sets circulating supplies for multiple tokens in a single call.
    /// @dev Only callable by owner. Can be used to initialize or update values.
    /// @param symbols Array of token symbols
    /// @param supplies Array of circulating supply values (whole token units, parallel to symbols)
    function setSupplies(bytes32[] calldata symbols, uint256[] calldata supplies) external onlyOwner {
        if (symbols.length != supplies.length) revert HardcodedCirculatingSupply_LengthMismatch();
        for (uint256 i = 0; i < symbols.length; i++) {
            _supply[symbols[i]] = supplies[i];
            _isSet[symbols[i]] = true;
            emit SupplySet(symbols[i], supplies[i]);
        }
    }

    /// @notice Returns the raw supply without any checks (returns 0 if never set).
    /// @param symbol Token symbol as bytes32
    function getRawSupply(bytes32 symbol) external view returns (uint256) {
        return _supply[symbol];
    }
}
