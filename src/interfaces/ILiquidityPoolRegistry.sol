// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.31;

/*###############################################################################

    @title ILiquidityPoolRegistry
    @author BLOK Capital DAO
    @notice Interface for the LiquidityPoolRegistry contract

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

interface ILiquidityPoolRegistry {
    // ========================================================================
    // Structs
    // ========================================================================

    /// @notice Metadata stored per pool address
    /// @param poolAddress Address of the liquidity pool
    /// @param dexId DEX identifier (keccak256("UNISWAP_V3"), etc.)
    /// @param pairId Canonical pair identifier (ordered token addresses)
    /// @param pairName Human-readable pair name (e.g., "WETH/USDC")
    /// @param token0 First token in the pair (sorted by address)
    /// @param token1 Second token in the pair (sorted by address)
    /// @param fee Fee tier for V3-style pools (e.g., 500, 3000, 10000) - 0 for V2
    /// @param active Whether the pool is active for use
    struct PoolInfo {
        address poolAddress;
        bytes32 dexId;
        bytes32 pairId;
        string pairName;
        address token0;
        address token1;
        uint24 fee;
        bool active;
    }

    /// @notice Parameters for adding a new pool
    struct AddPoolParams {
        address poolAddress;
        address tokenA;
        address tokenB;
        bytes32 dexId;
        string pairName;
        uint24 fee;
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
        uint24 fee
    );

    event PoolRemoved(address indexed poolAddress, bytes32 indexed pairId);
    event PoolStatusChanged(address indexed poolAddress, bool active);

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

    // ========================================================================
    // Pool Queries - Single Pool
    // ========================================================================

    /// @notice Returns the information of a registered pool
    /// @param poolAddress The address of the pool
    /// @return PoolInfo The details of the pool
    function getPool(address poolAddress) external view returns (PoolInfo memory);

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
    // Pool Queries - By Fee Tier
    // ========================================================================

    /// @notice Get pool for a token pair with specific fee tier
    /// @param tokenA First token address
    /// @param tokenB Second token address
    /// @param dexId DEX identifier
    /// @param fee Fee tier
    /// @return pool Pool address (address(0) if not found)
    function getPoolByFee(
        address tokenA,
        address tokenB,
        bytes32 dexId,
        uint24 fee
    )
        external
        view
        returns (address pool);

    /// @notice Get all pools for a token pair on a DEX, grouped by fee tier
    /// @param tokenA First token address
    /// @param tokenB Second token address
    /// @param dexId DEX identifier
    /// @return pools Array of pool addresses
    /// @return fees Array of fee tiers corresponding to each pool
    function getPoolsWithFees(
        address tokenA,
        address tokenB,
        bytes32 dexId
    )
        external
        view
        returns (address[] memory pools, uint24[] memory fees);

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

    // ========================================================================
    // Utility Functions
    // ========================================================================

    /// @notice Compute canonical pair ID from two token addresses
    /// @param tokenA First token address
    /// @param tokenB Second token address
    /// @return pairId Canonical pair ID
    function computePairId(address tokenA, address tokenB) external pure returns (bytes32 pairId);

    /// @notice Get sorted token addresses (token0 < token1)
    /// @param tokenA First token address
    /// @param tokenB Second token address
    /// @return token0 Lower address
    /// @return token1 Higher address
    function sortTokens(address tokenA, address tokenB) external pure returns (address token0, address token1);
}
