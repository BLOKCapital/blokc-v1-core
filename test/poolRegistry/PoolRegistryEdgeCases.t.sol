// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.20;

import { PoolRegistryTestBase } from "./PoolRegistryTestBase.sol";
import { PoolRegistry } from "src/liquidityPoolRegistry/PoolRegistry.sol";
import { IPoolRegistry } from "src/interfaces/IPoolRegistry.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title Tests for PoolRegistry edge cases and security
contract PoolRegistryEdgeCasesTest is PoolRegistryTestBase {
    function setUp() public override {
        super.setUp();
    }

    // =============================================================
    // OWNERSHIP TESTS
    // =============================================================

    /// @notice Test ownership transfer
    function test_OwnershipTransfer() public {
        address newOwner = makeAddr("newOwner");

        assertEq(registry.owner(), owner);

        vm.prank(owner);
        registry.transferOwnership(newOwner);

        assertEq(registry.owner(), newOwner);

        // New owner can add pool
        vm.prank(newOwner);
        registry.addPool(pool1, bytes32(bytes(DEX_UNISWAP)), PAIR_NAME_ETH_USDC);

        assertTrue(registry.isPoolRegistered(pool1));
    }

    /// @notice Test old owner cannot perform actions after transfer
    function test_OldOwnerCannotActAfterTransfer() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(owner);
        registry.transferOwnership(newOwner);

        // Old owner should not be able to add pool
        vm.prank(owner);
        vm.expectRevert();
        registry.addPool(pool1, bytes32(bytes(DEX_UNISWAP)), PAIR_NAME_ETH_USDC);
    }

    /// @notice Test ownership transfer to zero address reverts
    function test_RevertIf_TransferOwnershipToZeroAddress() public {
        vm.expectRevert();
        registry.transferOwnership(address(0));
    }

    /// @notice Test non-owner cannot transfer ownership
    function test_RevertIf_NonOwnerTransfersOwnership() public {
        vm.prank(user1);
        vm.expectRevert();
        registry.transferOwnership(user2);
    }

    // =============================================================
    // STRING EDGE CASES
    // =============================================================

    /// @notice Test pool with very long pair name
    function test_PoolWithVeryLongPairName() public {
        string memory longName = "ABCDEFGHIJKLMNOPQRSTUVWXYZ/ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        addPool(pool1, longName, DEX_UNISWAP);

        IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(pool1);
        assertEq(poolInfo.pairName, longName);
        assertEq(poolInfo.protocolId, bytes32(bytes(DEX_UNISWAP)));
    }

    /// @notice Test pool with very long DEX ID
    function test_PoolWithVeryLongDexId() public {
        string memory longDexId = "VeryLongDecentralizedExchangeNameThatIsUnusuallyLong";
        addPool(pool1, PAIR_NAME_ETH_USDC, longDexId);

        IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(pool1);
        assertEq(poolInfo.pairName, PAIR_NAME_ETH_USDC);
        assertEq(poolInfo.protocolId, bytes32(bytes(longDexId)));
    }

    /// @notice Test pool with Unicode characters
    function test_PoolWithUnicodeCharacters() public {
        string memory unicodePairName = unicode"ETH/USDC 🚀";
        string memory unicodeDexId = unicode"Uniswap 🦄";

        addPool(pool1, unicodePairName, unicodeDexId);

        IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(pool1);
        assertEq(poolInfo.pairName, unicodePairName);
        assertEq(poolInfo.protocolId, bytes32(bytes(unicodeDexId)));
    }

    /// @notice Test pool with special characters
    function test_PoolWithSpecialCharacters() public {
        string memory specialPairName = "ETH-USDC_v2.0";
        string memory specialDexId = "Uniswap-V3";

        addPool(pool1, specialPairName, specialDexId);

        IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(pool1);
        assertEq(poolInfo.pairName, specialPairName);
        assertEq(poolInfo.protocolId, bytes32(bytes(specialDexId)));
    }

    /// @notice Test pool with single character strings
    function test_PoolWithSingleCharacterStrings() public {
        string memory singleCharPairName = "A";
        string memory singleCharDexId = "B";

        addPool(pool1, singleCharPairName, singleCharDexId);

        IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(pool1);
        assertEq(poolInfo.pairName, singleCharPairName);
        assertEq(poolInfo.protocolId, bytes32(bytes(singleCharDexId)));
    }

    /// @notice Test pool with numbers in strings
    function test_PoolWithNumbersInStrings() public {
        string memory pairNameWithNumbers = "TOKEN1/TOKEN2";
        string memory dexIdWithNumbers = "Uniswap3";

        addPool(pool1, pairNameWithNumbers, dexIdWithNumbers);

        IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(pool1);
        assertEq(poolInfo.pairName, pairNameWithNumbers);
        assertEq(poolInfo.protocolId, bytes32(bytes(dexIdWithNumbers)));
    }

    // =============================================================
    // ARRAY MANAGEMENT EDGE CASES
    // =============================================================

    /// @notice Test removing last element from array
    function test_RemoveLastElementFromArray() public {
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        addPool(pool2, PAIR_NAME_WBTC_ETH, DEX_SUSHISWAP);

        address[] memory poolsBefore = registry.poolAddresses();
        address lastPool = poolsBefore[poolsBefore.length - 1];

        removePool(lastPool);

        address[] memory poolsAfter = registry.poolAddresses();
        assertEq(poolsAfter.length, poolsBefore.length - 1);

        for (uint256 i = 0; i < poolsAfter.length; i++) {
            assertTrue(poolsAfter[i] != lastPool);
        }
    }

    /// @notice Test removing first element from array
    function test_RemoveFirstElementFromArray() public {
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        addPool(pool2, PAIR_NAME_WBTC_ETH, DEX_SUSHISWAP);

        address[] memory poolsBefore = registry.poolAddresses();
        address firstPool = poolsBefore[0];

        removePool(firstPool);

        address[] memory poolsAfter = registry.poolAddresses();
        assertEq(poolsAfter.length, poolsBefore.length - 1);

        for (uint256 i = 0; i < poolsAfter.length; i++) {
            assertTrue(poolsAfter[i] != firstPool);
        }
    }

    /// @notice Test removing all elements one by one
    function test_RemoveAllElementsOneByOne() public {
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        addPool(pool2, PAIR_NAME_WBTC_ETH, DEX_SUSHISWAP);
        addPool(pool3, PAIR_NAME_DAI_USDC, DEX_CURVE);

        removePool(pool1);
        address[] memory pools1 = registry.poolAddresses();
        assertEq(pools1.length, 2);

        removePool(pool2);
        address[] memory pools2 = registry.poolAddresses();
        assertEq(pools2.length, 1);

        removePool(pool3);
        address[] memory pools3 = registry.poolAddresses();
        assertEq(pools3.length, 0);
    }

    /// @notice Test adding pools after removing all
    function test_AddPoolsAfterRemovingAll() public {
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        addPool(pool2, PAIR_NAME_WBTC_ETH, DEX_SUSHISWAP);

        removePool(pool1);
        removePool(pool2);

        address[] memory poolsAfterRemoval = registry.poolAddresses();
        assertEq(poolsAfterRemoval.length, 0);

        addPool(pool3, PAIR_NAME_DAI_USDC, DEX_CURVE);

        address[] memory poolsAfterAdd = registry.poolAddresses();
        assertEq(poolsAfterAdd.length, 1);
        assertEq(poolsAfterAdd[0], pool3);
    }

    /// @notice Test array integrity after many operations
    function test_ArrayIntegrityAfterManyOperations() public {
        // Add multiple pools
        for (uint256 i = 0; i < 10; i++) {
            address newPool = address(uint160(1000 + i));
            vm.prank(owner);
            registry.addPool(newPool, bytes32(bytes(DEX_UNISWAP)), PAIR_NAME_ETH_USDC);
        }

        // Remove some pools
        for (uint256 i = 0; i < 5; i++) {
            address poolToRemove = address(uint160(1000 + i));
            vm.prank(owner);
            registry.removePool(poolToRemove);
        }

        // Add more pools
        for (uint256 i = 10; i < 15; i++) {
            address newPool = address(uint160(1000 + i));
            vm.prank(owner);
            registry.addPool(newPool, bytes32(bytes(DEX_SUSHISWAP)), PAIR_NAME_WBTC_ETH);
        }

        address[] memory finalPools = registry.poolAddresses();
        assertEq(finalPools.length, 10); // 10 - 5 + 5 = 10

        // Verify all pools in array are registered
        for (uint256 i = 0; i < finalPools.length; i++) {
            assertTrue(registry.isPoolRegistered(finalPools[i]));
        }
    }

    // =============================================================
    // POOL ADDRESS EDGE CASES
    // =============================================================

    /// @notice Test pool with maximum address value
    function test_PoolWithMaxAddress() public {
        address maxAddress = address(type(uint160).max);
        addPool(maxAddress, PAIR_NAME_ETH_USDC, DEX_UNISWAP);

        assertTrue(registry.isPoolRegistered(maxAddress));
    }

    /// @notice Test pool with minimum non-zero address value
    function test_PoolWithMinAddress() public {
        address minAddress = address(1);
        addPool(minAddress, PAIR_NAME_ETH_USDC, DEX_UNISWAP);

        assertTrue(registry.isPoolRegistered(minAddress));
    }

    /// @notice Test many pools with sequential addresses
    function test_ManyPoolsWithSequentialAddresses() public {
        for (uint256 i = 1; i <= 20; i++) {
            address sequentialAddress = address(uint160(i));
            vm.prank(owner);
            registry.addPool(sequentialAddress, bytes32(bytes(DEX_UNISWAP)), PAIR_NAME_ETH_USDC);
        }

        address[] memory pools = registry.poolAddresses();
        assertEq(pools.length, 20);
    }

    // =============================================================
    // STATE CONSISTENCY TESTS
    // =============================================================

    /// @notice Test state consistency after complex operations
    function test_StateConsistencyAfterComplexOperations() public {
        // Add pools
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        addPool(pool2, PAIR_NAME_WBTC_ETH, DEX_SUSHISWAP);
        addPool(pool3, PAIR_NAME_DAI_USDC, DEX_CURVE);

        // Remove middle pool
        removePool(pool2);

        // Add new pool
        addPool(pool4, PAIR_NAME_USDT_USDC, DEX_BALANCER);

        // Remove first pool
        removePool(pool1);

        // Verify final state
        address[] memory pools = registry.poolAddresses();
        assertEq(pools.length, 2);

        assertTrue(registry.isPoolRegistered(pool3));
        assertTrue(registry.isPoolRegistered(pool4));
        assertFalse(registry.isPoolRegistered(pool1));
        assertFalse(registry.isPoolRegistered(pool2));
    }

    /// @notice Test that array and mapping stay in sync
    function test_ArrayAndMappingStayInSync() public {
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        addPool(pool2, PAIR_NAME_WBTC_ETH, DEX_SUSHISWAP);

        address[] memory pools = registry.poolAddresses();

        // Every pool in array should be registered
        for (uint256 i = 0; i < pools.length; i++) {
            assertTrue(registry.isPoolRegistered(pools[i]));
            IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(pools[i]);
            assertTrue(bytes(poolInfo.pairName).length > 0);
            assertTrue(poolInfo.protocolId != bytes32(0));
        }
    }

    // =============================================================
    // GAS AND PERFORMANCE TESTS
    // =============================================================

    /// @notice Test gas cost of adding a pool
    function test_GasCost_AddPool() public {
        uint256 gasBefore = gasleft();
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        uint256 gasUsed = gasBefore - gasleft();

        // Gas should be reasonable
        assertTrue(gasUsed < 500_000, "Gas should be reasonable");
    }

    /// @notice Test gas cost of removing a pool
    function test_GasCost_RemovePool() public {
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);

        uint256 gasBefore = gasleft();
        removePool(pool1);
        uint256 gasUsed = gasBefore - gasleft();

        // Gas should be reasonable
        assertTrue(gasUsed < 500_000, "Gas should be reasonable");
    }

    /// @notice Test gas cost with large array
    function test_GasCost_WithLargeArray() public {
        // Add many pools
        for (uint256 i = 0; i < 50; i++) {
            address newPool = address(uint160(1000 + i));
            vm.prank(owner);
            registry.addPool(newPool, bytes32(bytes(DEX_UNISWAP)), PAIR_NAME_ETH_USDC);
        }

        // Remove pool from middle
        address poolToRemove = address(uint160(1025));
        uint256 gasBefore = gasleft();
        vm.prank(owner);
        registry.removePool(poolToRemove);
        uint256 gasUsed = gasBefore - gasleft();

        // Gas should still be reasonable (swap-and-pop pattern)
        assertTrue(gasUsed < 1_000_000, "Gas should be reasonable even with large array");
    }

    // =============================================================
    // FUZZ TESTS
    // =============================================================

    /// @notice Fuzz test add and remove operations
    function testFuzz_AddAndRemoveOperations(address poolAddress, string memory pairName, string memory dexId) public {
        // Skip invalid inputs
        vm.assume(poolAddress != address(0));
        vm.assume(bytes(pairName).length > 0);
        vm.assume(bytes(dexId).length > 0);

        addPool(poolAddress, pairName, dexId);

        assertTrue(registry.isPoolRegistered(poolAddress));

        IPoolRegistry.PoolInfo memory poolInfo = registry.poolDetails(poolAddress);
        assertEq(poolInfo.pairName, pairName);
        assertEq(poolInfo.protocolId, bytes32(bytes(dexId)));

        removePool(poolAddress);

        assertFalse(registry.isPoolRegistered(poolAddress));
    }

    /// @notice Fuzz test multiple add operations
    function testFuzz_MultipleAddOperations(address addr1, address addr2, address addr3) public {
        // Ensure unique and valid addresses
        vm.assume(addr1 != address(0) && addr2 != address(0) && addr3 != address(0));
        vm.assume(addr1 != addr2 && addr2 != addr3 && addr1 != addr3);

        addPool(addr1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        addPool(addr2, PAIR_NAME_WBTC_ETH, DEX_SUSHISWAP);
        addPool(addr3, PAIR_NAME_DAI_USDC, DEX_CURVE);

        assertTrue(registry.isPoolRegistered(addr1));
        assertTrue(registry.isPoolRegistered(addr2));
        assertTrue(registry.isPoolRegistered(addr3));

        address[] memory pools = registry.poolAddresses();
        assertEq(pools.length, 3);
    }

    /// @notice Fuzz test ownership operations
    function testFuzz_OwnershipOperations(address newOwner) public {
        // Skip zero address
        vm.assume(newOwner != address(0));

        vm.prank(owner);
        registry.transferOwnership(newOwner);

        assertEq(registry.owner(), newOwner);

        // New owner can add pool
        vm.prank(newOwner);
        registry.addPool(pool1, bytes32(bytes(DEX_UNISWAP)), PAIR_NAME_ETH_USDC);

        assertTrue(registry.isPoolRegistered(pool1));
    }

    // =============================================================
    // UPGRADE TESTS - Moved to PoolRegistryUpgrade.t.sol
    // =============================================================
    // Note: Comprehensive upgrade tests are now in a dedicated test file

    /// @notice Test empty registry behavior
    function test_EmptyRegistryBehavior() public {
        PoolRegistry newImpl = new PoolRegistry();
        ProxyAdmin newAdmin = new ProxyAdmin(address(this));

        bytes memory initData = abi.encodeWithSelector(PoolRegistry.initialize.selector, owner);
        TransparentUpgradeableProxy newProxy =
            new TransparentUpgradeableProxy(address(newImpl), address(newAdmin), initData);
        PoolRegistry newRegistry = PoolRegistry(payable(address(newProxy)));

        // All queries on empty registry should work
        address[] memory pools = newRegistry.poolAddresses();
        assertEq(pools.length, 0);

        assertFalse(newRegistry.isPoolRegistered(address(1)));

        IPoolRegistry.PoolInfo memory poolInfo = newRegistry.poolDetails(address(1));
        assertEq(poolInfo.pairName, "");
        assertEq(poolInfo.protocolId, bytes32(0));
    }
}
