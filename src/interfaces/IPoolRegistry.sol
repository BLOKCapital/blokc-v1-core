// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.20;

/*###############################################################################

    @title IPoolRegistry
    @author BLOK Capital DAO
    @notice Interface of the PoolRegistry contract.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

/**
 * @title IPoolRegistry
 * @notice Interface of the PoolRegistry contract.
 */
interface IPoolRegistry {
    /// @notice Simple metadata stored per pool address.
    struct PoolInfo {
        // human-readable pair name (e.g. "ETH/USD")
        string pairName;
        // DEX identifier
        string dexId;
    }
    /**
     * @notice Registers a new liquidity pool.
     * @param poolAddress Address of the pool to add.
     * @param pairName Name of the trading pair.
     * @param dexId ID of the DEX where the pool exists.
     */

    function addPool(address poolAddress, string calldata pairName, string calldata dexId) external;

    /**
     * @notice Removes a pool from the registry.
     * @param poolAddress Address of the pool to remove.
     */
    function removePool(address poolAddress) external;

    /**
     * @notice Returns the details of a registered pool.
     * @param poolAddress The address of the pool.
     * @return pairName The name of the trading pair.
     * @return dexId The ID of the DEX.
     */
    function poolDetails(address poolAddress) external view returns (string memory pairName, string memory dexId);

    /**
     * @notice Returns the addresses of all registered pools.
     * @return pools The addresses of all registered pools.
     */
    function poolAddresses() external view returns (address[] memory pools);

    /**
     * @notice Checks if a pool is registered.
     * @param poolAddress The address of the pool to check.
     * @return True if the pool is registered, false otherwise.
     */
    function isPoolRegistered(address poolAddress) external view returns (bool);
}
