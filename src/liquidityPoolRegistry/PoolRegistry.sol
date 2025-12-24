// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

/*###############################################################################

    @title PoolRegistry
    @author BLOK Capital DAO
    @notice Registry contract that manages the registration and tracking of liquidity pools

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

// Local Interfaces
import { IPoolRegistry } from "src/interfaces/IPoolRegistry.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when pool address is zero
error PoolRegistry_PoolAddressIsZero();

/// @notice Thrown when attempting to add a pool that already exists
/// @param poolAddress The pool address that already exists
error PoolRegistry_PoolAlreadyExists(address poolAddress);

/// @notice Thrown when attempting to remove a pool that does not exist
/// @param poolAddress The pool address that does not exist
error PoolRegistry_PoolDoesNotExist(address poolAddress);

/// @notice Thrown when pair name is empty
error PoolRegistry_PairNameEmpty();

/// @notice Thrown when DEX ID is empty
error PoolRegistry_DexIdEmpty();

/// @notice Thrown when quote token is zero
error PoolRegistry_QuoteTokenIsZero();

/// @notice Thrown when base token is zero
error PoolRegistry_BaseTokenIsZero();

contract PoolRegistry is IPoolRegistry, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    // ========================================================================
    // State Variables
    // ========================================================================

    /// @notice Array of all registered pool addresses
    EnumerableSet.AddressSet private _poolAddresses;

    /// @notice Mapping from pool address to pool metadata
    mapping(address => PoolInfo) private _poolInfo;

    /// @notice Mapping from pool ID to pool address
    mapping(bytes32 => address) private _poolIdToAddress;

    // ========================================================================
    // Constructor
    // ========================================================================

    /// @notice Constructor
    /// @dev Initializes the registry with the given owner
    /// @param initialOwner The address that will be the owner of this registry
    constructor(address initialOwner) Ownable(initialOwner) { }

    /// @notice Modifier to validate a pool
    /// @param _poolAddress The address of the pool to validate
    /// @param _quoteToken The address of the quote token
    /// @param _baseToken The address of the base token
    /// @param _protocolId The identifier of the protocol where the pool exists
    /// @param _pairName The name of the trading pair (e.g., "ETH/USD")
    modifier validPool(
        address _poolAddress,
        address _quoteToken,
        address _baseToken,
        bytes32 _protocolId,
        string calldata _pairName
    ) {
        _validatePool(_poolAddress, _quoteToken, _baseToken, _protocolId, _pairName);
        _;
    }

    // ========================================================================
    // External Functions (State-Changing)
    // ========================================================================

    /// @notice Registers a new liquidity pool
    /// @dev The pool address must not be zero, must not already exist, and both pairName and dexId must be non-empty
    /// @param _poolAddress The address of the pool to add
    /// @param _protocolId The identifier of the protocol where the pool exists
    /// @param _pairName The name of the trading pair (e.g., "ETH/USD")
    function addPool(
        address _poolAddress,
        address _quoteToken,
        address _baseToken,
        bytes32 _protocolId,
        string calldata _pairName
    )
        external
        onlyOwner
        validPool(_poolAddress, _quoteToken, _baseToken, _protocolId, _pairName)
    {
        // Generate pool ID
        bytes32 poolId = keccak256(abi.encode(_quoteToken, _baseToken));
        bytes32 reversedPoolId = keccak256(abi.encode(_baseToken, _quoteToken));

        _poolAddresses.add(_poolAddress);
        _poolIdToAddress[poolId] = _poolAddress;
        _poolIdToAddress[reversedPoolId] = _poolAddress;
        _poolInfo[_poolAddress] = PoolInfo({
            poolAddress: _poolAddress,
            quoteToken: _quoteToken,
            baseToken: _baseToken,
            dexId: _protocolId,
            poolId: poolId,
            reversedPoolId: reversedPoolId,
            active: true,
            pairName: _pairName
        });
    }

    /// @notice Removes a pool from the registry
    /// @dev The pool must exist in the registry. Uses gas-optimized array removal pattern.
    /// @param _poolAddress The address of the pool to remove
    function removePool(address _poolAddress) external onlyOwner {
        if (!_poolAddresses.contains(_poolAddress)) revert PoolRegistry_PoolDoesNotExist(_poolAddress);
        PoolInfo memory info = _poolInfo[_poolAddress];
        bytes32 poolId = info.poolId;
        bytes32 reversedPoolId = info.reversedPoolId;
        _poolAddresses.remove(_poolAddress);
        delete _poolInfo[_poolAddress];
        delete _poolIdToAddress[poolId];
        delete _poolIdToAddress[reversedPoolId];
    }

    // ========================================================================
    // External Functions (View)
    // ========================================================================

    /// @notice Returns the information of a registered pool
    /// @param _poolAddress The address of the pool
    /// @return PoolInfo The details of the pool
    function poolDetails(address _poolAddress) external view override returns (PoolInfo memory) {
        return _poolInfo[_poolAddress];
    }

    /// @notice Returns the addresses of all registered pools
    /// @return pools_ Array of all registered pool addresses
    function poolAddresses() external view returns (address[] memory pools_) {
        pools_ = _poolAddresses.values();
    }

    /// @notice Checks if a pool is registered
    /// @param _poolAddress The address of the pool to check
    /// @return True if the pool is registered, false otherwise
    function isPoolRegistered(address _poolAddress) external view returns (bool) {
        return _poolAddresses.contains(_poolAddress);
    }

    /// @notice Checks if a pool is active
    /// @param _poolAddress The address of the pool to check
    /// @return True if the pool is active, false otherwise
    function isPoolActive(address _poolAddress) external view returns (bool) {
        return _poolInfo[_poolAddress].active;
    }

    /// @notice Returns the address of a pool by its ID
    /// @param _poolId The ID of the pool
    /// @return The address of the pool
    function poolAddressById(bytes32 _poolId) external view returns (address) {
        return _poolIdToAddress[_poolId];
    }

    // ========================================================================
    // Internal Functions
    // ========================================================================

    function _validatePool(
        address _poolAddress,
        address _quoteToken,
        address _baseToken,
        bytes32 _protocolId,
        string calldata _pairName
    )
        internal
        view
    {
        if (_poolAddresses.contains(_poolAddress)) revert PoolRegistry_PoolAlreadyExists(_poolAddress);
        if (_poolAddress == address(0)) revert PoolRegistry_PoolAddressIsZero();
        if (_quoteToken == address(0)) revert PoolRegistry_QuoteTokenIsZero();
        if (_baseToken == address(0)) revert PoolRegistry_BaseTokenIsZero();
        if (_protocolId == bytes32(0)) revert PoolRegistry_DexIdEmpty();
        if (bytes(_pairName).length == 0) revert PoolRegistry_PairNameEmpty();
    }
}
