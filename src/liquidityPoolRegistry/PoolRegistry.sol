// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/*###############################################################################

    @title PoolRegistry
    @author BLOK Capital DAO
    @notice Registry contract that manages the registration and tracking of liquidity pools.
    @dev This contract uses the Transparent Proxy pattern and is upgradeable.
         It uses OpenZeppelin's upgradeable contracts library for security and reliability.
         Pools can be added and removed by the owner only.

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

// ============================================================================
// PoolRegistry
// ============================================================================

/**
 * @title PoolRegistry
 * @notice Registry contract that manages the registration and tracking of liquidity pools
 * @dev This contract manages the registration and tracking of liquidity pools for the protocol.
 *      Only the owner can add or remove pools. Pools are stored with metadata including pair name and DEX ID.
 */
contract PoolRegistry is Initializable, OwnableUpgradeable, IPoolRegistry {
    // ========================================================================
    // State Variables
    // ========================================================================

    /// @notice Array of all registered pool addresses
    address[] private pools;

    /// @notice Mapping from pool address to pool metadata
    mapping(address pool => PoolInfo) private poolInfo;

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

    /**
     * @notice Initializes the registry contract
     * @dev This function should be called during proxy deployment via the proxy's initialization mechanism
     * @param _initialOwner The address that will be the owner of this registry
     */
    function initialize(address _initialOwner) public initializer {
        __Ownable_init(_initialOwner);
    }

    // ========================================================================
    // External Functions (State-Changing)
    // ========================================================================

    /**
     * @notice Registers a new liquidity pool
     * @dev The pool address must not be zero, must not already exist, and both pairName and dexId must be non-empty
     * @param _poolAddress The address of the pool to add
     * @param _pairName The name of the trading pair (e.g., "ETH/USD")
     * @param _dexId The identifier of the DEX where the pool exists
     */
    function addPool(address _poolAddress, string calldata _pairName, string calldata _dexId) external onlyOwner {
        // Validate pool address
        if (_poolAddress == address(0)) {
            revert PoolRegistry_PoolAddressIsZero();
        }

        // Check if pool already exists
        if (bytes(poolInfo[_poolAddress].pairName).length != 0) {
            revert PoolRegistry_PoolAlreadyExists(_poolAddress);
        }

        // Validate pair name is not empty
        if (bytes(_pairName).length == 0) {
            revert PoolRegistry_PairNameEmpty();
        }

        // Validate DEX ID is not empty
        if (bytes(_dexId).length == 0) {
            revert PoolRegistry_DexIdEmpty();
        }

        // Add pool to array and mapping
        pools.push(_poolAddress);
        poolInfo[_poolAddress] = PoolInfo({ pairName: _pairName, dexId: _dexId });
    }

    /**
     * @notice Removes a pool from the registry
     * @dev The pool must exist in the registry. Uses gas-optimized array removal pattern.
     * @param _poolAddress The address of the pool to remove
     */
    function removePool(address _poolAddress) external onlyOwner {
        // Validate pool exists
        if (bytes(poolInfo[_poolAddress].pairName).length == 0) {
            revert PoolRegistry_PoolDoesNotExist(_poolAddress);
        }

        // Remove pool from array using swap-and-pop pattern
        uint256 length = pools.length;
        for (uint256 i = 0; i < length; i++) {
            if (pools[i] == _poolAddress) {
                // Swap with last element and pop
                pools[i] = pools[length - 1];
                pools.pop();
                break;
            }
        }

        // Delete pool metadata
        delete poolInfo[_poolAddress];
    }

    // ========================================================================
    // External Functions (View)
    // ========================================================================

    /**
     * @notice Returns the details of a registered pool
     * @param _poolAddress The address of the pool
     * @return pairName The name of the trading pair
     * @return dexId The identifier of the DEX
     */
    function poolDetails(address _poolAddress) external view returns (string memory pairName, string memory dexId) {
        PoolInfo memory info = poolInfo[_poolAddress];
        return (info.pairName, info.dexId);
    }

    /**
     * @notice Returns the addresses of all registered pools
     * @return pools_ Array of all registered pool addresses
     */
    function poolAddresses() external view returns (address[] memory pools_) {
        pools_ = pools;
    }

    /**
     * @notice Checks if a pool is registered
     * @param _poolAddress The address of the pool to check
     * @return True if the pool is registered, false otherwise
     */
    function isPoolRegistered(address _poolAddress) external view returns (bool) {
        return bytes(poolInfo[_poolAddress].pairName).length != 0;
    }
}
