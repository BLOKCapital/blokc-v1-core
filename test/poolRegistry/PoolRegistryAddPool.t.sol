// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.20;

import { PoolRegistryTestBase } from "./PoolRegistryTestBase.sol";
import { PoolRegistry } from "src/liquidityPoolRegistry/PoolRegistry.sol";
import { IPoolRegistry } from "src/interfaces/IPoolRegistry.sol";

/// @title Tests for PoolRegistry addPool functionality
contract PoolRegistryAddPoolTest is PoolRegistryTestBase {
    function setUp() public override {
        super.setUp();
    }

    // =============================================================
    // ADD POOL TESTS
    // =============================================================

    /// @notice Test adding a single pool
    function test_AddSinglePool() public {
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);

        assertPoolAdded(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
    }

    /// @notice Test adding multiple pools
    function test_AddMultiplePools() public {
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        addPool(pool2, PAIR_NAME_WBTC_ETH, DEX_SUSHISWAP);
        addPool(pool3, PAIR_NAME_DAI_USDC, DEX_CURVE);

        assertPoolAdded(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        assertPoolAdded(pool2, PAIR_NAME_WBTC_ETH, DEX_SUSHISWAP);
        assertPoolAdded(pool3, PAIR_NAME_DAI_USDC, DEX_CURVE);

        address[] memory pools = registry.poolAddresses();
        assertEq(pools.length, 3);
    }

    /// @notice Test adding pool with same DEX but different pair
    function test_AddPoolSameDexDifferentPair() public {
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        addPool(pool2, PAIR_NAME_WBTC_ETH, DEX_UNISWAP);

        assertPoolAdded(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        assertPoolAdded(pool2, PAIR_NAME_WBTC_ETH, DEX_UNISWAP);
    }

    /// @notice Test adding pool with same pair but different DEX
    function test_AddPoolSamePairDifferentDex() public {
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        addPool(pool2, PAIR_NAME_ETH_USDC, DEX_SUSHISWAP);

        assertPoolAdded(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        assertPoolAdded(pool2, PAIR_NAME_ETH_USDC, DEX_SUSHISWAP);
    }

    /// @notice Test adding pool updates poolAddresses array
    function test_AddPoolUpdatesPoolAddressesArray() public {
        address[] memory poolsBefore = registry.poolAddresses();
        assertEq(poolsBefore.length, 0);

        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);

        address[] memory poolsAfter = registry.poolAddresses();
        assertEq(poolsAfter.length, 1);
        assertEq(poolsAfter[0], pool1);
    }

    /// @notice Test adding pool updates isPoolRegistered
    function test_AddPoolUpdatesIsPoolRegistered() public {
        assertFalse(registry.isPoolRegistered(pool1));

        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);

        assertTrue(registry.isPoolRegistered(pool1));
    }

    /// @notice Test adding pool updates poolDetails
    function test_AddPoolUpdatesPoolDetails() public {
        IPoolRegistry.PoolInfo memory poolInfoBefore = registry.poolDetails(pool1);
        assertEq(poolInfoBefore.pairName, "");
        assertEq(poolInfoBefore.protocolId, bytes32(0));

        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);

        IPoolRegistry.PoolInfo memory poolInfoAfter = registry.poolDetails(pool1);
        assertEq(poolInfoAfter.pairName, PAIR_NAME_ETH_USDC);
        assertEq(poolInfoAfter.protocolId, bytes32(bytes(DEX_UNISWAP)));
    }

    /// @notice Test adding pools in sequence
    function test_AddPoolsInSequence() public {
        for (uint256 i = 0; i < 5; i++) {
            address[5] memory pools = [pool1, pool2, pool3, pool4, pool5];
            string[5] memory pairNames =
                [PAIR_NAME_ETH_USDC, PAIR_NAME_WBTC_ETH, PAIR_NAME_DAI_USDC, PAIR_NAME_USDT_USDC, PAIR_NAME_ARB_ETH];

            addPool(pools[i], pairNames[i], DEX_UNISWAP);

            address[] memory registeredPools = registry.poolAddresses();
            assertEq(registeredPools.length, i + 1);
        }
    }

    /// @notice Test adding pool with long pair name
    function test_AddPoolWithLongPairName() public {
        string memory longPairName = "VeryLongTokenName/AnotherVeryLongTokenName";
        addPool(pool1, longPairName, DEX_UNISWAP);

        assertPoolAdded(pool1, longPairName, DEX_UNISWAP);
    }

    /// @notice Test adding pool with long DEX ID
    function test_AddPoolWithLongDexId() public {
        string memory longDexId = "VeryLongDecentralizedExchangeName";
        addPool(pool1, PAIR_NAME_ETH_USDC, longDexId);

        assertPoolAdded(pool1, PAIR_NAME_ETH_USDC, longDexId);
    }

    /// @notice Test adding pool with special characters in pair name
    function test_AddPoolWithSpecialCharacters() public {
        string memory specialPairName = "ETH-USD/USDC_v2";
        addPool(pool1, specialPairName, DEX_UNISWAP);

        assertPoolAdded(pool1, specialPairName, DEX_UNISWAP);
    }

    /// @notice Test adding pool doesn't affect other pools
    function test_AddPoolDoesntAffectOtherPools() public {
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        addPool(pool2, PAIR_NAME_WBTC_ETH, DEX_SUSHISWAP);

        // Verify pool1 details unchanged
        IPoolRegistry.PoolInfo memory poolInfo1 = registry.poolDetails(pool1);
        assertEq(poolInfo1.pairName, PAIR_NAME_ETH_USDC);
        assertEq(poolInfo1.protocolId, bytes32(bytes(DEX_UNISWAP)));

        // Add pool3 and verify pool1 and pool2 are still correct
        addPool(pool3, PAIR_NAME_DAI_USDC, DEX_CURVE);

        IPoolRegistry.PoolInfo memory poolInfo1After = registry.poolDetails(pool1);
        assertEq(poolInfo1After.pairName, PAIR_NAME_ETH_USDC);
        assertEq(poolInfo1After.protocolId, bytes32(bytes(DEX_UNISWAP)));

        IPoolRegistry.PoolInfo memory poolInfo2After = registry.poolDetails(pool2);
        assertEq(poolInfo2After.pairName, PAIR_NAME_WBTC_ETH);
        assertEq(poolInfo2After.protocolId, bytes32(bytes(DEX_SUSHISWAP)));
    }

    /// @notice Test pool array grows correctly with multiple additions
    function test_PoolArrayGrowsCorrectly() public {
        for (uint256 i = 1; i <= 5; i++) {
            address[5] memory pools = [pool1, pool2, pool3, pool4, pool5];
            string[5] memory pairNames =
                [PAIR_NAME_ETH_USDC, PAIR_NAME_WBTC_ETH, PAIR_NAME_DAI_USDC, PAIR_NAME_USDT_USDC, PAIR_NAME_ARB_ETH];

            addPool(pools[i - 1], pairNames[i - 1], DEX_UNISWAP);

            address[] memory registeredPools = registry.poolAddresses();
            assertEq(registeredPools.length, i, "Pool array should grow");

            // Verify all pools are in array
            for (uint256 j = 0; j < i; j++) {
                bool found = false;
                for (uint256 k = 0; k < registeredPools.length; k++) {
                    if (registeredPools[k] == pools[j]) {
                        found = true;
                        break;
                    }
                }
                assertTrue(found, "Pool should be in array");
            }
        }
    }

    // =============================================================
    // REVERT TESTS - ADD POOL
    // =============================================================

    /// @notice Test adding pool reverts when not owner
    function test_RevertIf_AddPoolWhenNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        registry.addPool(pool1, bytes32(bytes(DEX_UNISWAP)), PAIR_NAME_ETH_USDC);
    }

    /// @notice Test adding pool with zero address reverts
    function test_RevertIf_AddPoolWithZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_PoolAddressIsZero()));
        registry.addPool(address(0), bytes32(bytes(DEX_UNISWAP)), PAIR_NAME_ETH_USDC);
    }

    /// @notice Test adding already registered pool reverts
    function test_RevertIf_AddPoolThatAlreadyExists() public {
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);

        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_PoolAlreadyExists(), pool1));
        registry.addPool(pool1, bytes32(bytes(DEX_SUSHISWAP)), PAIR_NAME_WBTC_ETH);
    }

    /// @notice Test adding pool with empty pair name reverts
    function test_RevertIf_AddPoolWithEmptyPairName() public {
        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_PairNameEmpty()));
        registry.addPool(pool1, "", DEX_UNISWAP);
    }

    /// @notice Test adding pool with empty DEX ID reverts
    function test_RevertIf_AddPoolWithEmptyDexId() public {
        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_DexIdEmpty()));
        registry.addPool(pool1, bytes32(0), PAIR_NAME_ETH_USDC);
    }

    /// @notice Test adding pool with empty pair name and empty DEX ID reverts
    function test_RevertIf_AddPoolWithEmptyPairNameAndDexId() public {
        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_PairNameEmpty()));
        registry.addPool(pool1, "", "");
    }

    /// @notice Test non-owner cannot add pool
    function test_RevertIf_NonOwnerAddsPool() public {
        vm.prank(user1);
        vm.expectRevert();
        registry.addPool(pool1, bytes32(bytes(DEX_UNISWAP)), PAIR_NAME_ETH_USDC);

        vm.prank(user2);
        vm.expectRevert();
        registry.addPool(pool2, bytes32(bytes(DEX_SUSHISWAP)), PAIR_NAME_WBTC_ETH);
    }

    /// @notice Test adding pool twice with different details reverts
    function test_RevertIf_AddSamePoolTwice() public {
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);

        // Try to add with different pair name
        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_PoolAlreadyExists(), pool1));
        registry.addPool(pool1, bytes32(bytes(DEX_UNISWAP)), PAIR_NAME_WBTC_ETH);

        // Try to add with different DEX
        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_PoolAlreadyExists(), pool1));
        registry.addPool(pool1, bytes32(bytes(DEX_SUSHISWAP)), PAIR_NAME_ETH_USDC);
    }

    /// @notice Test that pool is not added when transaction reverts
    function test_PoolNotAddedWhenReverts() public {
        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_PoolAddressIsZero()));
        registry.addPool(address(0), bytes32(bytes(DEX_UNISWAP)), PAIR_NAME_ETH_USDC);

        // Verify no pool was added
        address[] memory pools = registry.poolAddresses();
        assertEq(pools.length, 0);
    }

    /// @notice Test ownership protection
    function test_OnlyOwnerCanAddPools() public {
        address randomUser = makeAddr("randomUser");

        vm.prank(randomUser);
        vm.expectRevert();
        registry.addPool(pool1, bytes32(bytes(DEX_UNISWAP)), PAIR_NAME_ETH_USDC);

        // Owner should be able to add
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        assertTrue(registry.isPoolRegistered(pool1));
    }

    /// @notice Test that existing pool data cannot be overwritten
    function test_ExistingPoolDataCannotBeOverwritten() public {
        addPool(pool1, PAIR_NAME_ETH_USDC, DEX_UNISWAP);

        IPoolRegistry.PoolInfo memory poolInfoOriginal = registry.poolDetails(pool1);
        string memory originalPairName = poolInfoOriginal.pairName;
        bytes32 originalDexId = poolInfoOriginal.protocolId;

        // Try to add again with different data
        vm.expectRevert(abi.encodeWithSelector(getErrorSelector_PoolAlreadyExists(), pool1));
        registry.addPool(pool1, bytes32(bytes(DEX_SUSHISWAP)), PAIR_NAME_WBTC_ETH);

        // Verify original data is unchanged
        IPoolRegistry.PoolInfo memory poolInfoCurrent = registry.poolDetails(pool1);
        assertEq(poolInfoCurrent.pairName, originalPairName);
        assertEq(poolInfoCurrent.protocolId, originalDexId);
    }

    // =============================================================
    // FUZZ TESTS
    // =============================================================

    /// @notice Fuzz test adding pools with random pair names
    function testFuzz_AddPoolWithRandomPairName(string memory pairName) public {
        // Skip empty string as it should revert
        vm.assume(bytes(pairName).length > 0);

        addPool(pool1, pairName, DEX_UNISWAP);
        assertPoolAdded(pool1, pairName, DEX_UNISWAP);
    }

    /// @notice Fuzz test adding pools with random DEX IDs
    function testFuzz_AddPoolWithRandomDexId(string memory dexId) public {
        // Skip empty string as it should revert
        vm.assume(bytes(dexId).length > 0);

        addPool(pool1, PAIR_NAME_ETH_USDC, dexId);
        assertPoolAdded(pool1, PAIR_NAME_ETH_USDC, dexId);
    }

    /// @notice Fuzz test adding pools with random addresses
    function testFuzz_AddPoolWithRandomAddress(address poolAddress) public {
        // Skip zero address as it should revert
        vm.assume(poolAddress != address(0));

        addPool(poolAddress, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
        assertPoolAdded(poolAddress, PAIR_NAME_ETH_USDC, DEX_UNISWAP);
    }
}
