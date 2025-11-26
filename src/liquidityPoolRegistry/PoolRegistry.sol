// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/*###############################################################################

    @title PoolRegistry
    @author BLOK Capital DAO
    @notice Registry contract that manages the registration and tracking of liquidity pools

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

// OpenZeppelin Upgradeable Contracts
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// Local Interfaces
import { IPoolRegistry } from "src/interfaces/IPoolRegistry.sol";

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

contract PoolRegistry is Initializable, OwnableUpgradeable, IPoolRegistry {
    // ========================================================================
    // State Variables
    // ========================================================================

    /// @notice Array of all registered pool addresses
    address[] private _pools;

    /// @notice Mapping from pool address to pool metadata
    mapping(address => PoolInfo) private _poolInfo;

    // ========================================================================
    // Constructor
    // ========================================================================

    /// @notice Disables initialization of the implementation contract
    /// @dev This prevents the implementation from being initialized directly
    constructor() {
        _disableInitializers();
    }

    // ========================================================================
    // Initialization
    // ========================================================================

    /// @notice Initializes the registry contract
    /// @dev This function should be called during proxy deployment via the proxy's initialization mechanism
    /// @param _initialOwner The address that will be the owner of this registry
    function initialize(address _initialOwner) public initializer {
        __Ownable_init(_initialOwner);
    }

    // ========================================================================
    // External Functions (State-Changing)
    // ========================================================================

    /// @notice Registers a new liquidity pool
    /// @dev The pool address must not be zero, must not already exist, and both pairName and dexId must be non-empty
    /// @param _poolAddress The address of the pool to add
    /// @param _protocolId The identifier of the protocol where the pool exists
    /// @param _pairName The name of the trading pair (e.g., "ETH/USD")
    function addPool(address _poolAddress, bytes32 _protocolId, string calldata _pairName) external onlyOwner {
        // Validate pool address
        if (_poolAddress == address(0)) {
            revert PoolRegistry_PoolAddressIsZero();
        }

        // Check if pool already exists
        if (bytes(_poolInfo[_poolAddress].pairName).length != 0) {
            revert PoolRegistry_PoolAlreadyExists(_poolAddress);
        }

        // Validate pair name is not empty
        if (bytes(_pairName).length == 0) {
            revert PoolRegistry_PairNameEmpty();
        }

        // Validate DEX ID is not empty
        if (_protocolId == bytes32(0)) {
            revert PoolRegistry_DexIdEmpty();
        }

        // Add pool to array and mapping
        _pools.push(_poolAddress);
        _poolInfo[_poolAddress] =
            PoolInfo({ poolAddress: _poolAddress, protocolId: _protocolId, active: true, pairName: _pairName });
    }

    /// @notice Removes a pool from the registry
    /// @dev The pool must exist in the registry. Uses gas-optimized array removal pattern.
    /// @param _poolAddress The address of the pool to remove
    function removePool(address _poolAddress) external onlyOwner {
        // Validate pool exists
        if (bytes(_poolInfo[_poolAddress].pairName).length == 0) {
            revert PoolRegistry_PoolDoesNotExist(_poolAddress);
        }

        // Remove pool from array using swap-and-pop pattern
        uint256 length = _pools.length;
        for (uint256 i = 0; i < length; i++) {
            if (_pools[i] == _poolAddress) {
                // Swap with last element and pop
                _pools[i] = _pools[length - 1];
                _pools.pop();
                break;
            }
        }

        // Delete pool metadata
        delete _poolInfo[_poolAddress];
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
        pools_ = _pools;
    }

    /// @notice Checks if a pool is registered
    /// @param _poolAddress The address of the pool to check
    /// @return True if the pool is registered, false otherwise
    function isPoolRegistered(address _poolAddress) external view returns (bool) {
        return bytes(_poolInfo[_poolAddress].pairName).length != 0;
    }

    /// @notice Checks if a pool is active
    /// @param _poolAddress The address of the pool to check
    /// @return True if the pool is active, false otherwise
    function isPoolActive(address _poolAddress) external view returns (bool) {
        return _poolInfo[_poolAddress].active;
    }
}
