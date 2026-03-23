// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/// @title DexQuoteRegistry
/// @notice Lightweight registry that maps DEX identifiers to the quote function selector
///         and parameter count used by the optimal-path engine. Implements the same two
///         read functions that the CRE engine calls on the full FacetRegistry, so it can
///         be used as a drop-in `facetRegistryAddress` for testing without deploying the
///         full Diamond / FacetRegistry infrastructure.
contract DexQuoteRegistry {
    address public owner;

    mapping(bytes32 dexId => bytes4 selector) private _selectors;
    mapping(bytes32 dexId => uint8 paramCount) private _paramCounts;

    error DexQuoteRegistry_NotOwner();
    error DexQuoteRegistry_InvalidParamCount(uint8 paramCount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert DexQuoteRegistry_NotOwner();
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // =========================================================================
    // Admin
    // =========================================================================

    /// @notice Register or update the quote function for a DEX
    /// @param dexId keccak256 of the DEX name string (e.g. keccak256("UNISWAP_V3"))
    /// @param selector 4-byte function selector of the quote function on the dexFacetAddress
    /// @param paramCount Number of parameters the quote function takes (4 or 5)
    function setDexQuoteSelector(bytes32 dexId, bytes4 selector, uint8 paramCount) external onlyOwner {
        if (paramCount != 4 && paramCount != 5) revert DexQuoteRegistry_InvalidParamCount(paramCount);
        _selectors[dexId] = selector;
        _paramCounts[dexId] = paramCount;
    }

    // =========================================================================
    // Views — identical ABI to FacetRegistry
    // =========================================================================

    /// @notice Returns true when a quote selector has been registered for dexId
    function isDexRegistered(bytes32 dexId) external view returns (bool) {
        return _selectors[dexId] != bytes4(0);
    }

    /// @notice Returns the quote selector and parameter count for a DEX
    function getQuoteSelectorForDex(bytes32 dexId) external view returns (bytes4 quoteSelector, uint8 paramCount) {
        return (_selectors[dexId], _paramCounts[dexId]);
    }
}
