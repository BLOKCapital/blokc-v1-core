// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { PoolRegistry } from "src/liquidityPoolRegistry/PoolRegistry.sol";
import { IPoolRegistry } from "src/interfaces/IPoolRegistry.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Base test contract for PoolRegistry tests
/// @notice Provides common setup and helper functions for all PoolRegistry test suites
abstract contract PoolRegistryTestBase is Test {
    // Registry contracts
    PoolRegistry internal registry;
    PoolRegistry internal registryImpl;
    ProxyAdmin internal registryProxyAdmin;
    TransparentUpgradeableProxy internal registryProxy;

    // Test addresses
    address internal owner;
    address internal user1;
    address internal user2;
    address internal user3;

    // Mock pool addresses
    address internal pool1;
    address internal pool2;
    address internal pool3;
    address internal pool4;
    address internal pool5;

    // Constants for testing
    string constant PAIR_NAME_ETH_USDC = "ETH/USDC";
    string constant PAIR_NAME_WBTC_ETH = "WBTC/ETH";
    string constant PAIR_NAME_DAI_USDC = "DAI/USDC";
    string constant PAIR_NAME_USDT_USDC = "USDT/USDC";
    string constant PAIR_NAME_ARB_ETH = "ARB/ETH";

    string constant DEX_UNISWAP = "UniswapV3";
    string constant DEX_SUSHISWAP = "SushiSwap";
    string constant DEX_CURVE = "Curve";
    string constant DEX_BALANCER = "Balancer";

    function setUp() public virtual {
        // Setup test addresses
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // Setup mock pool addresses (use makeAddr to ensure they're EOAs or use actual mock contracts)
        pool1 = makeAddr("pool1");
        pool2 = makeAddr("pool2");
        pool3 = makeAddr("pool3");
        pool4 = makeAddr("pool4");
        pool5 = makeAddr("pool5");

        // Deploy implementation
        registryImpl = new PoolRegistry();

        // Initialize the proxy with the implementation and initialization data
        bytes memory initData = abi.encodeWithSelector(PoolRegistry.initialize.selector, owner);

        // In OZ v5, TransparentUpgradeableProxy creates its own ProxyAdmin
        // Pass owner directly as initialOwner (not a ProxyAdmin address)
        registryProxy = new TransparentUpgradeableProxy(
            address(registryImpl),
            owner, // initialOwner - the proxy will create a ProxyAdmin with this owner
            initData
        );

        registry = PoolRegistry(payable(address(registryProxy)));

        // Get reference to the ProxyAdmin that was created by the proxy
        // The admin address is stored in EIP-1967 admin slot
        bytes32 ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
        address admin = address(uint160(uint256(vm.load(address(registryProxy), ADMIN_SLOT))));
        registryProxyAdmin = ProxyAdmin(admin);
    }

    /// @notice Helper function to add a pool
    /// @param poolAddress The address of the pool
    /// @param pairName The pair name
    /// @param dexId The DEX identifier
    function addPool(address poolAddress, string memory pairName, string memory dexId) internal {
        vm.prank(owner);
        registry.addPool(poolAddress, bytes32(bytes(dexId)), pairName);
    }

    /// @notice Helper function to remove a pool
    /// @param poolAddress The address of the pool to remove
    function removePool(address poolAddress) internal {
        vm.prank(owner);
        registry.removePool(poolAddress);
    }

    /// @notice Helper function to add multiple pools
    /// @param count Number of pools to add
    function addMultiplePools(uint256 count) internal {
        require(count > 0 && count <= 5, "Invalid count");
        address[5] memory pools = [pool1, pool2, pool3, pool4, pool5];
        string[5] memory pairNames =
            [PAIR_NAME_ETH_USDC, PAIR_NAME_WBTC_ETH, PAIR_NAME_DAI_USDC, PAIR_NAME_USDT_USDC, PAIR_NAME_ARB_ETH];

        for (uint256 i = 0; i < count; i++) {
            addPool(pools[i], pairNames[i], DEX_UNISWAP);
        }
    }

    /// @notice Helper function to get error selector for PoolAddressIsZero
    function getErrorSelector_PoolAddressIsZero() internal pure returns (bytes4) {
        return bytes4(keccak256("PoolRegistry_PoolAddressIsZero()"));
    }

    /// @notice Helper function to get error selector for PoolAlreadyExists
    function getErrorSelector_PoolAlreadyExists() internal pure returns (bytes4) {
        return bytes4(keccak256("PoolRegistry_PoolAlreadyExists(address)"));
    }

    /// @notice Helper function to get error selector for PoolDoesNotExist
    function getErrorSelector_PoolDoesNotExist() internal pure returns (bytes4) {
        return bytes4(keccak256("PoolRegistry_PoolDoesNotExist(address)"));
    }

    /// @notice Helper function to get error selector for PairNameEmpty
    function getErrorSelector_PairNameEmpty() internal pure returns (bytes4) {
        return bytes4(keccak256("PoolRegistry_PairNameEmpty()"));
    }

    /// @notice Helper function to get error selector for DexIdEmpty
    function getErrorSelector_DexIdEmpty() internal pure returns (bytes4) {
        return bytes4(keccak256("PoolRegistry_DexIdEmpty()"));
    }

    /// @notice Helper to assert that a pool was added correctly
    /// @param poolAddress The address of the pool
    /// @param expectedPairName The expected pair name
    /// @param expectedDexId The expected DEX ID
    function assertPoolAdded(
        address poolAddress,
        string memory expectedPairName,
        string memory expectedDexId
    )
        internal
        view
    {
        assertTrue(registry.isPoolRegistered(poolAddress), "Pool should be registered");

        IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(poolAddress);
        assertEq(poolInfo.pairName, expectedPairName, "Pair name should match");
        assertEq(poolInfo.protocolId, bytes32(bytes(expectedDexId)), "DEX ID should match");

        address[] memory pools = registry.poolAddresses();
        bool found = false;
        for (uint256 i = 0; i < pools.length; i++) {
            if (pools[i] == poolAddress) {
                found = true;
                break;
            }
        }
        assertTrue(found, "Pool should be in pool addresses array");
    }

    /// @notice Helper to assert that a pool was removed correctly
    /// @param poolAddress The address of the pool
    function assertPoolRemoved(address poolAddress) internal view {
        assertFalse(registry.isPoolRegistered(poolAddress), "Pool should not be registered");

        IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(poolAddress);
        assertEq(poolInfo.pairName, "", "Pair name should be empty");
        assertEq(poolInfo.protocolId, bytes32(0), "DEX ID should be empty");

        address[] memory pools = registry.poolAddresses();
        for (uint256 i = 0; i < pools.length; i++) {
            assertTrue(pools[i] != poolAddress, "Pool should not be in pool addresses array");
        }
    }
}
