// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.31;

/*###############################################################################

    @title IPoolRegistry
    @author BLOK Capital DAO
    @notice Interface for the PoolRegistry contract

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

interface IPoolRegistry {
    /// @notice Simple metadata stored per pool address.
    struct PoolInfo {
        address poolAddress;
        bytes32 protocolId; // 32 bytes: compact identifier (keccak256("UNISWAP_V3"))
        bool active;
        string pairName;
    }
    /// @notice Registers a new liquidity pool.
    /// @param poolAddress Address of the pool to add.
    /// @param protocolId Protocol ID of the pool.
    /// @param pairName Human-readable pair name of the pool.

    function addPool(address poolAddress, bytes32 protocolId, string calldata pairName) external;

    /// @notice Removes a pool from the registry.
    /// @param poolAddress Address of the pool to remove.
    function removePool(address poolAddress) external;

    /// @notice Returns the information of a registered pool.
    /// @param poolAddress The address of the pool.
    /// @return PoolInfo The details of the pool.
    function poolDetails(address poolAddress) external view returns (PoolInfo memory);

    /// @notice Returns the addresses of all registered pools.
    /// @return pools The addresses of all registered pools.
    function poolAddresses() external view returns (address[] memory pools);

    /// @notice Checks if a pool is registered.
    /// @param poolAddress The address of the pool to check.
    /// @return True if the pool is registered, false otherwise.
    function isPoolRegistered(address poolAddress) external view returns (bool);

    /// @notice Checks if a pool is active.
    /// @param poolAddress The address of the pool to check.
    /// @return True if the pool is active, false otherwise.
    function isPoolActive(address poolAddress) external view returns (bool);
}
