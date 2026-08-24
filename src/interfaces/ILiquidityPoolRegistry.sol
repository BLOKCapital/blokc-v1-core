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
/// @notice Interface for the Liquidity Pool Registry that tracks DEXes and their pools.
/// @dev DEXes are registered explicitly (mirroring the FacetRegistry module pattern) and pools
///      are scoped to registered DEXes. Each DEX carries swap and quote selector metadata so the
///      cumulative rebalancer can discover available protocols without hardcoding selectors.
///      DEX-specific pool parameters (fee tiers, bin steps, coin indices) are NOT stored here —
///      they live in the pool contracts and are derived on-chain by DEX facets at swap time.
interface ILiquidityPoolRegistry {
    // ========================================================================
    // Structs
    // ========================================================================

    /// @notice Metadata stored per registered DEX
    /// @param dexId DEX identifier (keccak256("UNISWAP_V3"), keccak256("CURVE"), etc.)
    /// @param swapSelector 4-byte selector of the DEX facet's standardised swap wrapper
    /// @param quoteSelector 4-byte selector of the DEX facet's standardised quote function
    /// @param active Whether the DEX is active for use
    struct DexInfo {
        bytes32 dexId;
        bytes4 swapSelector;
        bytes4 quoteSelector;
        bool active;
    }

    /// @notice Metadata stored per pool address
    /// @param poolAddress Address of the liquidity pool
    /// @param dexId DEX identifier (keccak256("UNISWAP_V3"), keccak256("CAMELOT_V2"), etc.)
    /// @param pairName Human-readable pair name (e.g., "WETH/USDC")
    /// @param token0 First token in the pair (sorted by address)
    /// @param token1 Second token in the pair (sorted by address)
    struct PoolInfo {
        address poolAddress;
        bytes32 dexId;
        string pairName;
        address token0;
        address token1;
    }

    /// @notice Parameters for adding a new pool
    struct AddPoolParams {
        address poolAddress;
        address tokenA;
        address tokenB;
        bytes32 dexId;
        string pairName;
    }

    // ========================================================================
    // Events
    // ========================================================================

    // ── DEX events
    // ──────────────────────────────────────────────────────
    event DexRegistered(bytes32 indexed dexId, bytes4 swapSelector, bytes4 quoteSelector);
    event DexSelectorsUpdated(bytes32 indexed dexId, bytes4 swapSelector, bytes4 quoteSelector);
    event DexStatusChanged(bytes32 indexed dexId, bool active);

    // ── Pool events
    // ─────────────────────────────────────────────────────
    event PoolAdded(
        address indexed poolAddress, bytes32 indexed pairId, bytes32 indexed dexId, address token0, address token1
    );
    event PoolRemoved(address indexed poolAddress, bytes32 indexed pairId);

    // ========================================================================
    // DEX Management
    // ========================================================================

    /// @notice Registers a new DEX with its swap and quote selectors
    /// @param dexId DEX identifier (e.g. keccak256("UNISWAP_V3"))
    /// @param swapSelector Selector of the DEX facet's standardised swap wrapper
    /// @param quoteSelector Selector of the DEX facet's standardised quote function
    function registerDex(bytes32 dexId, bytes4 swapSelector, bytes4 quoteSelector) external;

    /// @notice Updates the swap and quote selectors for a registered DEX
    /// @param dexId DEX identifier
    /// @param swapSelector New swap selector
    /// @param quoteSelector New quote selector
    function updateDexSelectors(bytes32 dexId, bytes4 swapSelector, bytes4 quoteSelector) external;

    /// @notice Sets the active status of a registered DEX
    /// @param dexId DEX identifier
    /// @param active New active status
    function setDexActive(bytes32 dexId, bool active) external;

    // ========================================================================
    // DEX Queries
    // ========================================================================

    /// @notice Returns full metadata for a registered DEX
    /// @param dexId DEX identifier
    /// @return info The DexInfo struct
    function getDex(bytes32 dexId) external view returns (DexInfo memory info);

    /// @notice Checks if a DEX has been registered
    /// @param dexId DEX identifier
    /// @return True if registered
    function isDexRegistered(bytes32 dexId) external view returns (bool);

    /// @notice Checks if a DEX is active
    /// @param dexId DEX identifier
    /// @return True if registered and active
    function isDexActive(bytes32 dexId) external view returns (bool);

    /// @notice Returns the swap selector for a DEX (used by rebalance execution)
    /// @param dexId DEX identifier
    /// @return swapSelector The 4-byte swap wrapper selector
    function getSwapSelectorForDex(bytes32 dexId) external view returns (bytes4 swapSelector);

    /// @notice Returns the quote selector for a DEX (used by optimal path engine)
    /// @param dexId DEX identifier
    /// @return quoteSelector The 4-byte quote function selector
    function getQuoteSelectorForDex(bytes32 dexId) external view returns (bytes4 quoteSelector);

    /// @notice Returns all registered DEX IDs
    /// @return dexIds Array of DEX identifiers
    function getRegisteredDexIds() external view returns (bytes32[] memory dexIds);

    /// @notice Returns only active DEX IDs
    /// @return dexIds Array of active DEX identifiers
    function getActiveDexIds() external view returns (bytes32[] memory dexIds);

    /// @notice Returns the number of pools registered under a DEX
    /// @param dexId DEX identifier
    /// @return count Number of pools
    function getDexPoolCount(bytes32 dexId) external view returns (uint256 count);

    // ========================================================================
    // Pool Management
    // ========================================================================

    /// @notice Registers a new liquidity pool under an existing DEX
    /// @param params Pool parameters (dexId must reference a registered DEX)
    function addPool(AddPoolParams calldata params) external;

    /// @notice Removes a pool from the registry
    /// @param poolAddress Address of the pool to remove
    function removePool(address poolAddress) external;

    // ========================================================================
    // Pool Queries - Single Pool
    // ========================================================================

    /// @notice Returns the full information of a registered pool
    /// @param poolAddress The address of the pool
    /// @return PoolInfo The details of the pool
    function getPool(address poolAddress) external view returns (PoolInfo memory);

    /// @notice Checks if a pool is registered
    /// @param poolAddress The address of the pool to check
    /// @return True if the pool is registered
    function isPoolRegistered(address poolAddress) external view returns (bool);

    // ========================================================================
    // Pool Queries - By Token Pair
    // ========================================================================

    /// @notice Get all pools for a token pair (regardless of DEX)
    /// @param tokenA First token address
    /// @param tokenB Second token address
    /// @return pools Array of pool addresses
    function getPoolsForPair(address tokenA, address tokenB) external view returns (address[] memory pools);

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
