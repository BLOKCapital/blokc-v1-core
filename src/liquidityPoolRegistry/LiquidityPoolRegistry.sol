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

/// @notice Thrown when DEX ID is empty
error LiquidityPoolRegistry_EmptyDexId();

/// @notice Thrown when tokens are the same
error LiquidityPoolRegistry_IdenticalTokens();

/// @notice Thrown when (pairId, dexId, swapFee) already maps to another pool
error LiquidityPoolRegistry_DuplicatePoolKey();

/// @notice Thrown when pool address has no contract code
error LiquidityPoolRegistry_NotContract();

/// @notice Thrown when pair name exceeds maximum length
error LiquidityPoolRegistry_PairNameTooLong();

/**
 * @title LiquidityPoolRegistry
 * @notice Registry contract for managing liquidity pools across multiple DEXes. This contract allows the owner to add,
 * remove, and update liquidity pool information, including token pairs, DEX identifiers, AMM types, swap fees, and
 * active status. It provides various query functions to retrieve pools by address, token pair, DEX, AMM type, and
 * swap fee. The registry ensures that each pool is uniquely identified by its token pair, DEX, and swap fee combination
 * and includes comprehensive error handling for edge cases related to pool management. The contract uses OpenZeppelin's
 * Ownable for access control and EnumerableSet for efficient management of registered pool addresses and pair IDs.
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
    // State Variables
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

    /// @notice Mapping from DEX ID to set of pool addresses
    mapping(bytes32 dexId => EnumerableSet.AddressSet pools) private _dexPools;

    /// @notice Mapping from (pairId, dexId, swapFee) to pool address for quick lookup
    /// @dev Key = keccak256(abi.encode(pairId, dexId, swapFee))
    mapping(bytes32 key => address pool) private _poolByKey;

    // ========================================================================
    // Constructor
    // ========================================================================

    /// @notice Constructor
    /// @param initialOwner The address that will be the owner of this registry
    constructor(address initialOwner) Ownable(initialOwner) { }

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

    /// @inheritdoc ILiquidityPoolRegistry
    function setPoolActive(address poolAddress, bool active) external onlyOwner {
        if (!_allPools.contains(poolAddress)) {
            revert LiquidityPoolRegistry_PoolDoesNotExist(poolAddress);
        }
        _poolInfo[poolAddress].active = active;
        emit PoolStatusChanged(poolAddress, active);
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
    function getPoolSwapInfo(address poolAddress)
        external
        view
        returns (bool valid, address token0, address token1, uint24 swapFee)
    {
        if (!_allPools.contains(poolAddress)) {
            return (false, address(0), address(0), 0);
        }
        PoolInfo storage info = _poolInfo[poolAddress];
        return (info.active, info.token0, info.token1, info.swapFee);
    }

    /// @inheritdoc ILiquidityPoolRegistry
    function isPoolRegistered(address poolAddress) external view returns (bool) {
        return _allPools.contains(poolAddress);
    }

    /// @inheritdoc ILiquidityPoolRegistry
    /// @dev Returns false for unregistered pool addresses (default storage).
    function isPoolActive(address poolAddress) external view returns (bool) {
        return _poolInfo[poolAddress].active;
    }

    // ========================================================================
    // Pool Queries - By Token Pair
    // ========================================================================

    /// @inheritdoc ILiquidityPoolRegistry
    function getPoolsForPair(address tokenA, address tokenB) external view returns (address[] memory pools) {
        bytes32 pairId = _computePairId(tokenA, tokenB);
        return _pairPools[pairId].values();
    }

    /// @inheritdoc ILiquidityPoolRegistry
    function getActivePoolsForPair(address tokenA, address tokenB) external view returns (address[] memory pools) {
        return _getActivePoolsForPair(tokenA, tokenB);
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
        return _getPoolsForPairOnDex(tokenA, tokenB, dexId);
    }

    /// @inheritdoc ILiquidityPoolRegistry
    function getPoolsByDex(bytes32 dexId) external view returns (address[] memory pools) {
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

    /// @dev Registers a pool, reverts on invalid parameters, duplicate pool, duplicate key, or non-contract.
    function _addPool(AddPoolParams calldata params) internal {
        // Validation
        if (params.poolAddress == address(0)) revert LiquidityPoolRegistry_ZeroAddress();
        if (params.tokenA == address(0) || params.tokenB == address(0)) revert LiquidityPoolRegistry_ZeroAddress();
        if (params.tokenA == params.tokenB) revert LiquidityPoolRegistry_IdenticalTokens();
        if (params.dexId == bytes32(0)) revert LiquidityPoolRegistry_EmptyDexId();
        if (bytes(params.pairName).length == 0) revert LiquidityPoolRegistry_EmptyPairName();
        if (bytes(params.pairName).length > MAX_PAIR_NAME_LENGTH) revert LiquidityPoolRegistry_PairNameTooLong();
        if (params.poolAddress.code.length == 0) revert LiquidityPoolRegistry_NotContract();
        if (_allPools.contains(params.poolAddress)) revert LiquidityPoolRegistry_PoolAlreadyExists(params.poolAddress);

        // Sort tokens for canonical pair ID
        (address token0, address token1) = _sortTokens(params.tokenA, params.tokenB);
        bytes32 pairId = keccak256(abi.encode(token0, token1));

        // Enforce one pool per (pairId, dexId, swapFee)
        bytes32 key = _computePoolKey(pairId, params.dexId, params.swapFee);
        address existing = _poolByKey[key];
        if (existing != address(0)) revert LiquidityPoolRegistry_DuplicatePoolKey();

        // Store pool info
        _poolInfo[params.poolAddress] = PoolInfo({
            poolAddress: params.poolAddress,
            dexId: params.dexId,
            pairId: pairId,
            pairName: params.pairName,
            token0: token0,
            token1: token1,
            swapFee: params.swapFee,
            active: true
        });

        // Add to all sets
        _allPools.add(params.poolAddress);
        _pairPools[pairId].add(params.poolAddress);
        _dexPools[params.dexId].add(params.poolAddress);
        _allPairIds.add(pairId);

        // Add to quick lookup
        _poolByKey[key] = params.poolAddress;

        emit PoolAdded(params.poolAddress, pairId, params.dexId, token0, token1, params.swapFee);
    }

    /// @dev Removes a pool from all sets and deletes its info and key lookup.
    function _removePool(address poolAddress) internal {
        if (!_allPools.contains(poolAddress)) {
            revert LiquidityPoolRegistry_PoolDoesNotExist(poolAddress);
        }

        PoolInfo memory info = _poolInfo[poolAddress];

        // Remove from all sets
        _allPools.remove(poolAddress);
        _pairPools[info.pairId].remove(poolAddress);
        _dexPools[info.dexId].remove(poolAddress);

        // Remove from quick lookup
        bytes32 key = _computePoolKey(info.pairId, info.dexId, info.swapFee);
        delete _poolByKey[key];

        // Clean up pair ID if no more pools for this pair
        if (_pairPools[info.pairId].length() == 0) {
            _allPairIds.remove(info.pairId);
        }

        // Delete pool info
        delete _poolInfo[poolAddress];

        emit PoolRemoved(poolAddress, info.pairId);
    }

    /// @dev Helper function to get all active pools for a token pair.
    function _getActivePoolsForPair(address tokenA, address tokenB) internal view returns (address[] memory pools) {
        bytes32 pairId = _computePairId(tokenA, tokenB);
        address[] memory allPools = _pairPools[pairId].values();

        uint256 activeCount = 0;
        for (uint256 i = 0; i < allPools.length; i++) {
            if (_poolInfo[allPools[i]].active) {
                activeCount++;
            }
        }

        pools = new address[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allPools.length; i++) {
            if (_poolInfo[allPools[i]].active) {
                pools[index++] = allPools[i];
            }
        }
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

    /// @dev Returns keccak256(abi.encode(pairId, dexId, swapFee)) for _poolByKey lookup.
    function _computePoolKey(bytes32 pairId, bytes32 dexId, uint24 swapFee) internal pure returns (bytes32) {
        return keccak256(abi.encode(pairId, dexId, swapFee));
    }
}
