// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

// Local Interfaces
import { ILiquidityPoolRegistry } from "src/interfaces/ILiquidityPoolRegistry.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// ============================================================================
// Errors
// ============================================================================

// ── DEX errors ──────────────────────────────────────────────────────────

/// @notice Thrown when DEX ID is zero
error LiquidityPoolRegistry_EmptyDexId();

/// @notice Thrown when attempting to register a DEX that already exists
/// @param dexId The DEX identifier that already exists
error LiquidityPoolRegistry_DexAlreadyExists(bytes32 dexId);

/// @notice Thrown when referencing a DEX that has not been registered
/// @param dexId The DEX identifier that does not exist
error LiquidityPoolRegistry_DexDoesNotExist(bytes32 dexId);

/// @notice Thrown when a required selector is zero
error LiquidityPoolRegistry_EmptySelector();

// ── Pool errors ─────────────────────────────────────────────────────────

/// @notice Thrown when pool address is zero
error LiquidityPoolRegistry_ZeroAddress();

/// @notice Thrown when attempting to add a pool that already exists
/// @param poolAddress The pool address that already exists
error LiquidityPoolRegistry_PoolAlreadyExists(address poolAddress);

/// @notice Thrown when attempting to remove a pool that does not exist
/// @param poolAddress The pool address that does not exist
error LiquidityPoolRegistry_PoolDoesNotExist(address poolAddress);

/// @notice Thrown when pair name is empty
error LiquidityPoolRegistry_EmptyPairName();

/// @notice Thrown when tokens are the same
error LiquidityPoolRegistry_IdenticalTokens();

/// @notice Thrown when pool address has no contract code
error LiquidityPoolRegistry_NotContract();

/// @notice Thrown when pair name exceeds maximum length
error LiquidityPoolRegistry_PairNameTooLong();

/// @notice Thrown when renounceOwnership is called (disabled to prevent permanent lockout)
error LiquidityPoolRegistry_CannotRenounceOwnership();

/**
 * @title LiquidityPoolRegistry
 * @notice Registry contract for managing DEXes and their liquidity pools. DEXes are registered
 *         explicitly (mirroring the FacetRegistry module pattern) and carry swap/quote selector
 *         metadata. Pools are scoped to registered DEXes — a pool cannot be added unless its DEX
 *         has been registered first. DEX-specific pool parameters (fee tiers, bin steps, coin
 *         indices) are NOT stored here — they live in the pool contracts and are derived on-chain
 *         by DEX facets at swap time.
 */
contract LiquidityPoolRegistry is ILiquidityPoolRegistry, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    // ========================================================================
    // Constants
    // ========================================================================

    /// @notice Maximum allowed length for pairName (bytes)
    uint256 internal constant MAX_PAIR_NAME_LENGTH = 128;

    // ========================================================================
    // DEX Storage (mirrors FacetRegistry module pattern)
    // ========================================================================

    /// @notice Set of all registered DEX IDs
    EnumerableSet.Bytes32Set private _dexIds;

    /// @notice Whether a DEX has been registered
    mapping(bytes32 dexId => bool) private _dexExists;

    /// @notice DEX swap wrapper selector (for rebalance execution)
    mapping(bytes32 dexId => bytes4) private _dexSwapSelector;

    /// @notice DEX quote function selector (for optimal path)
    mapping(bytes32 dexId => bytes4) private _dexQuoteSelector;

    /// @notice Whether a DEX is active
    mapping(bytes32 dexId => bool) private _dexActive;

    // ========================================================================
    // Pool Storage
    // ========================================================================

    /// @notice Set of all registered pool addresses
    EnumerableSet.AddressSet private _allPools;

    /// @notice Set of all unique pair IDs
    EnumerableSet.Bytes32Set private _allPairIds;

    /// @notice Mapping from pool address to pool info
    mapping(address pool => PoolInfo info) private _poolInfo;

    /// @notice Mapping from pair ID to set of pool addresses
    /// @dev pairId = keccak256(abi.encode(token0, token1)) where token0 < token1
    mapping(bytes32 pairId => EnumerableSet.AddressSet pools) private _pairPools;

    /// @notice Mapping from DEX ID to set of pool addresses (pools scoped to their DEX)
    mapping(bytes32 dexId => EnumerableSet.AddressSet pools) private _dexPools;

    // ========================================================================
    // Constructor
    // ========================================================================

    /// @notice Constructor
    /// @param initialOwner The address that will be the owner of this registry
    constructor(address initialOwner) Ownable(initialOwner) { }

    // ========================================================================
    // Renounce Ownership
    // ========================================================================

    /// @inheritdoc Ownable
    function renounceOwnership() public pure override {
        revert LiquidityPoolRegistry_CannotRenounceOwnership();
    }

    // ========================================================================
    // DEX Management
    // ========================================================================

    /// @inheritdoc ILiquidityPoolRegistry
    function registerDex(bytes32 dexId, bytes4 swapSelector, bytes4 quoteSelector) external onlyOwner {
        if (dexId == bytes32(0)) revert LiquidityPoolRegistry_EmptyDexId();
        if (_dexExists[dexId]) revert LiquidityPoolRegistry_DexAlreadyExists(dexId);
        if (swapSelector == bytes4(0) || quoteSelector == bytes4(0)) revert LiquidityPoolRegistry_EmptySelector();

        _dexExists[dexId] = true;
        _dexActive[dexId] = true;
        _dexIds.add(dexId);
        _dexSwapSelector[dexId] = swapSelector;
        _dexQuoteSelector[dexId] = quoteSelector;

        emit DexRegistered(dexId, swapSelector, quoteSelector);
    }

    /// @inheritdoc ILiquidityPoolRegistry
    function updateDexSelectors(bytes32 dexId, bytes4 swapSelector, bytes4 quoteSelector) external onlyOwner {
        if (!_dexExists[dexId]) revert LiquidityPoolRegistry_DexDoesNotExist(dexId);
        if (swapSelector == bytes4(0) || quoteSelector == bytes4(0)) revert LiquidityPoolRegistry_EmptySelector();

        _dexSwapSelector[dexId] = swapSelector;
        _dexQuoteSelector[dexId] = quoteSelector;

        emit DexSelectorsUpdated(dexId, swapSelector, quoteSelector);
    }

    /// @inheritdoc ILiquidityPoolRegistry
    function setDexActive(bytes32 dexId, bool active) external onlyOwner {
        if (!_dexExists[dexId]) revert LiquidityPoolRegistry_DexDoesNotExist(dexId);
        _dexActive[dexId] = active;
        emit DexStatusChanged(dexId, active);
    }

    // ========================================================================
    // DEX Queries
    // ========================================================================

    /// @inheritdoc ILiquidityPoolRegistry
    function getDex(bytes32 dexId) external view returns (DexInfo memory info) {
        if (!_dexExists[dexId]) revert LiquidityPoolRegistry_DexDoesNotExist(dexId);
        info = DexInfo({
            dexId: dexId,
            swapSelector: _dexSwapSelector[dexId],
            quoteSelector: _dexQuoteSelector[dexId],
            active: _dexActive[dexId]
        });
    }

    /// @inheritdoc ILiquidityPoolRegistry
    function isDexRegistered(bytes32 dexId) external view returns (bool) {
        return _dexExists[dexId];
    }

    /// @inheritdoc ILiquidityPoolRegistry
    function isDexActive(bytes32 dexId) external view returns (bool) {
        return _dexActive[dexId];
    }

    /// @inheritdoc ILiquidityPoolRegistry
    function getSwapSelectorForDex(bytes32 dexId) external view returns (bytes4) {
        if (!_dexExists[dexId]) revert LiquidityPoolRegistry_DexDoesNotExist(dexId);
        return _dexSwapSelector[dexId];
    }

    /// @inheritdoc ILiquidityPoolRegistry
    function getQuoteSelectorForDex(bytes32 dexId) external view returns (bytes4) {
        if (!_dexExists[dexId]) revert LiquidityPoolRegistry_DexDoesNotExist(dexId);
        return _dexQuoteSelector[dexId];
    }

    /// @inheritdoc ILiquidityPoolRegistry
    function getRegisteredDexIds() external view returns (bytes32[] memory) {
        return _dexIds.values();
    }

    /// @inheritdoc ILiquidityPoolRegistry
    function getActiveDexIds() external view returns (bytes32[] memory) {
        bytes32[] memory all = _dexIds.values();
        uint256 count;
        for (uint256 i; i < all.length; i++) {
            if (_dexActive[all[i]]) count++;
        }
        bytes32[] memory active = new bytes32[](count);
        uint256 idx;
        for (uint256 i; i < all.length; i++) {
            if (_dexActive[all[i]]) active[idx++] = all[i];
        }
        return active;
    }

    /// @inheritdoc ILiquidityPoolRegistry
    function getDexPoolCount(bytes32 dexId) external view returns (uint256) {
        if (!_dexExists[dexId]) revert LiquidityPoolRegistry_DexDoesNotExist(dexId);
        return _dexPools[dexId].length();
    }

    // ========================================================================
    // Pool Management
    // ========================================================================

    /// @inheritdoc ILiquidityPoolRegistry
    function addPool(AddPoolParams calldata params) external onlyOwner {
        _addPool(params);
    }

    /// @inheritdoc ILiquidityPoolRegistry
    function removePool(address poolAddress) external onlyOwner {
        _removePool(poolAddress);
    }

    // ========================================================================
    // Pool Queries - Single Pool
    // ========================================================================

    /// @inheritdoc ILiquidityPoolRegistry
    function getPool(address poolAddress) external view returns (PoolInfo memory) {
        if (!_allPools.contains(poolAddress)) revert LiquidityPoolRegistry_PoolDoesNotExist(poolAddress);
        return _poolInfo[poolAddress];
    }

    /// @inheritdoc ILiquidityPoolRegistry
    function isPoolRegistered(address poolAddress) external view returns (bool) {
        return _allPools.contains(poolAddress);
    }

    // ========================================================================
    // Pool Queries - By Token Pair
    // ========================================================================

    /// @inheritdoc ILiquidityPoolRegistry
    function getPoolsForPair(address tokenA, address tokenB) external view returns (address[] memory pools) {
        bytes32 pairId = _computePairId(tokenA, tokenB);
        return _pairPools[pairId].values();
    }

    // ========================================================================
    // Pool Queries - By DEX
    // ========================================================================

    /// @inheritdoc ILiquidityPoolRegistry
    function getPoolsForPairOnDex(
        address tokenA,
        address tokenB,
        bytes32 dexId
    )
        external
        view
        returns (address[] memory pools)
    {
        
        if (!_dexExists[dexId]) revert LiquidityPoolRegistry_DexDoesNotExist(dexId);

        return _getPoolsForPairOnDex(tokenA, tokenB, dexId);
    }

    /// @inheritdoc ILiquidityPoolRegistry
    function getPoolsByDex(bytes32 dexId) external view returns (address[] memory pools) {
        if (!_dexExists[dexId]) revert LiquidityPoolRegistry_DexDoesNotExist(dexId);
        return _dexPools[dexId].values();
    }

    // ========================================================================
    // Global Queries
    // ========================================================================

    /// @inheritdoc ILiquidityPoolRegistry
    function getAllPools() external view returns (address[] memory pools) {
        return _allPools.values();
    }

    /// @inheritdoc ILiquidityPoolRegistry
    function getPoolCount() external view returns (uint256 count) {
        return _allPools.length();
    }

    /// @inheritdoc ILiquidityPoolRegistry
    function getAllPairIds() external view returns (bytes32[] memory pairIds) {
        return _allPairIds.values();
    }

    // ========================================================================
    // Internal Functions
    // ========================================================================

    /// @dev Registers a pool. Reverts on invalid parameters, unregistered DEX, duplicate, or non-contract.
    function _addPool(AddPoolParams calldata params) internal {
        if (params.poolAddress == address(0)) revert LiquidityPoolRegistry_ZeroAddress();
        if (params.tokenA == address(0) || params.tokenB == address(0)) revert LiquidityPoolRegistry_ZeroAddress();
        if (params.tokenA == params.tokenB) revert LiquidityPoolRegistry_IdenticalTokens();
        if (!_dexExists[params.dexId]) revert LiquidityPoolRegistry_DexDoesNotExist(params.dexId);
        if (bytes(params.pairName).length == 0) revert LiquidityPoolRegistry_EmptyPairName();
        if (bytes(params.pairName).length > MAX_PAIR_NAME_LENGTH) revert LiquidityPoolRegistry_PairNameTooLong();
        if (params.poolAddress.code.length == 0) revert LiquidityPoolRegistry_NotContract();
        if (_allPools.contains(params.poolAddress)) revert LiquidityPoolRegistry_PoolAlreadyExists(params.poolAddress);

        // Sort tokens for canonical pair ID
        (address token0, address token1) = _sortTokens(params.tokenA, params.tokenB);
        bytes32 pairId = keccak256(abi.encode(token0, token1));

        // Store pool info
        _poolInfo[params.poolAddress] = PoolInfo({
            poolAddress: params.poolAddress,
            dexId: params.dexId,
            pairName: params.pairName,
            token0: token0,
            token1: token1
        });

        // Add to all sets
        _allPools.add(params.poolAddress);
        _pairPools[pairId].add(params.poolAddress);
        _dexPools[params.dexId].add(params.poolAddress);
        _allPairIds.add(pairId);

        emit PoolAdded(params.poolAddress, pairId, params.dexId, token0, token1);
    }

    /// @dev Removes a pool from all sets and deletes its info.
    function _removePool(address poolAddress) internal {
        if (!_allPools.contains(poolAddress)) {
            revert LiquidityPoolRegistry_PoolDoesNotExist(poolAddress);
        }

        // Read only the fields we need via storage pointer (avoids copying pairName to memory)
        PoolInfo storage info = _poolInfo[poolAddress];
        bytes32 dexId = info.dexId;
        bytes32 pairId = keccak256(abi.encode(info.token0, info.token1));

        // Remove from all sets
        _allPools.remove(poolAddress);
        _pairPools[pairId].remove(poolAddress);
        _dexPools[dexId].remove(poolAddress);

        // Clean up pair ID if no more pools for this pair
        if (_pairPools[pairId].length() == 0) {
            _allPairIds.remove(pairId);
        }

        // Delete pool info
        delete _poolInfo[poolAddress];

        emit PoolRemoved(poolAddress, pairId);
    }

    /// @dev Helper function to get all pools for a token pair on a specific DEX.
    function _getPoolsForPairOnDex(
        address tokenA,
        address tokenB,
        bytes32 dexId
    )
        internal
        view
        returns (address[] memory pools)
    {
        bytes32 pairId = _computePairId(tokenA, tokenB);
        address[] memory pairPoolsList = _pairPools[pairId].values();

        uint256 count = 0;
        for (uint256 i = 0; i < pairPoolsList.length; i++) {
            if (_poolInfo[pairPoolsList[i]].dexId == dexId) {
                count++;
            }
        }

        pools = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < pairPoolsList.length; i++) {
            if (_poolInfo[pairPoolsList[i]].dexId == dexId) {
                pools[index++] = pairPoolsList[i];
            }
        }
    }

    /// @dev Returns (token0, token1) with token0 < token1 for canonical ordering.
    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    /// @dev Returns keccak256(abi.encode(token0, token1)) with token0 < token1.
    function _computePairId(address tokenA, address tokenB) internal pure returns (bytes32) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        return keccak256(abi.encode(token0, token1));
    }
}
