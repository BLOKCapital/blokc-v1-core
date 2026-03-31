// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

/// @title ILiquidityPoolRegistry
/// @author BLOK Capital DAO
/// @notice Interface for the Liquidity Pool Registry that tracks pools across DEXes.
/// @dev Pools are indexed by token pair, DEX identifier, AMM type, and swap fee for efficient lookup.
interface ILiquidityPoolRegistry {
    // ========================================================================
    // Structs
    // ========================================================================

    /// @notice Metadata stored per pool address
    /// @param poolAddress Address of the liquidity pool
    /// @param dexId DEX identifier (keccak256("UNISWAP_V3"), keccak256("CAMELOT_V2"), etc.)
    /// @param pairId Canonical pair identifier (ordered token addresses)
    /// @param pairName Human-readable pair name (e.g., "WETH/USDC")
    /// @param token0 First token in the pair (sorted by address)
    /// @param token1 Second token in the pair (sorted by address)
    /// @param swapFee Swap fee in millionths (3000 = 0.3%). Used for V3 pool lookup AND V2 amount computation.
    /// @param active Whether the pool is active for use
    struct PoolInfo {
        address poolAddress;
        bytes32 dexId;
        bytes32 pairId;
        string pairName;
        address token0;
        address token1;
        uint24 swapFee;
        bool active;
    }

    /// @notice Parameters for adding a new pool
    struct AddPoolParams {
        address poolAddress;
        address tokenA;
        address tokenB;
        bytes32 dexId;
        string pairName;
        uint24 swapFee;
    }

    // ========================================================================
    // Events
    // ========================================================================

    event PoolAdded(
        address indexed poolAddress,
        bytes32 indexed pairId,
        bytes32 indexed dexId,
        address token0,
        address token1,
        uint24 swapFee
    );

    event PoolRemoved(address indexed poolAddress, bytes32 indexed pairId);
    event PoolStatusChanged(address indexed poolAddress, bool active);
    event PoolSwapFeeUpdated(address indexed poolAddress, uint24 oldSwapFee, uint24 newSwapFee);

    // ========================================================================
    // Pool Management
    // ========================================================================

    /// @notice Registers a new liquidity pool
    /// @param params Pool parameters
    function addPool(AddPoolParams calldata params) external;

    /// @notice Removes a pool from the registry
    /// @param poolAddress Address of the pool to remove
    function removePool(address poolAddress) external;

    /// @notice Sets the active status of a pool
    /// @param poolAddress Address of the pool
    /// @param active New active status
    function setPoolActive(address poolAddress, bool active) external;

    /// @notice Updates the swap fee for a pool (e.g., for dynamic-fee pools)
    /// @param poolAddress Address of the pool
    /// @param swapFee New swap fee in millionths
    function setPoolSwapFee(address poolAddress, uint24 swapFee) external;

    // ========================================================================
    // Pool Queries - Single Pool
    // ========================================================================

    /// @notice Returns the full information of a registered pool
    /// @param poolAddress The address of the pool
    /// @return PoolInfo The details of the pool
    function getPool(address poolAddress) external view returns (PoolInfo memory);

    /// @notice Returns only the fields needed for a direct swap — avoids loading pairName/pairId
    /// @param poolAddress The address of the pool
    /// @return valid True if the pool is registered and active
    /// @return token0 First token (sorted by address)
    /// @return token1 Second token (sorted by address)
    /// @return swapFee Swap fee in millionths
    function getPoolSwapInfo(address poolAddress)
        external
        view
        returns (bool valid, address token0, address token1, uint24 swapFee);

    /// @notice Checks if a pool is registered
    /// @param poolAddress The address of the pool to check
    /// @return True if the pool is registered
    function isPoolRegistered(address poolAddress) external view returns (bool);

    /// @notice Checks if a pool is active
    /// @param poolAddress The address of the pool to check
    /// @return True if the pool is active (false if unregistered)
    function isPoolActive(address poolAddress) external view returns (bool);

    // ========================================================================
    // Pool Queries - By Token Pair
    // ========================================================================

    /// @notice Get all pools for a token pair (regardless of DEX)
    /// @param tokenA First token address
    /// @param tokenB Second token address
    /// @return pools Array of pool addresses
    function getPoolsForPair(address tokenA, address tokenB) external view returns (address[] memory pools);

    /// @notice Get all active pools for a token pair
    /// @param tokenA First token address
    /// @param tokenB Second token address
    /// @return pools Array of active pool addresses
    function getActivePoolsForPair(address tokenA, address tokenB) external view returns (address[] memory pools);

    // ========================================================================
    // Pool Queries - By DEX
    // ========================================================================

    /// @notice Get all pools for a token pair on a specific DEX
    /// @param tokenA First token address
    /// @param tokenB Second token address
    /// @param dexId DEX identifier
    /// @return pools Array of pool addresses on that DEX
    function getPoolsForPairOnDex(
        address tokenA,
        address tokenB,
        bytes32 dexId
    )
        external
        view
        returns (address[] memory pools);

    /// @notice Get all pools for a specific DEX
    /// @param dexId DEX identifier
    /// @return pools Array of all pool addresses on that DEX
    function getPoolsByDex(bytes32 dexId) external view returns (address[] memory pools);

    // ========================================================================
    // Global Queries
    // ========================================================================

    /// @notice Returns all registered pool addresses
    /// @return pools Array of all pool addresses
    function getAllPools() external view returns (address[] memory pools);

    /// @notice Returns the total number of registered pools
    /// @return count Number of pools
    function getPoolCount() external view returns (uint256 count);

    /// @notice Get all unique pair IDs
    /// @return pairIds Array of pair IDs
    function getAllPairIds() external view returns (bytes32[] memory pairIds);
}
