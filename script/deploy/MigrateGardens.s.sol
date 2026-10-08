// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▛▀▜▌▐▛▚▖     ▐▌   ▐▌ ▐▌▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { BaseScript } from "script/Base.s.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IndexComponentRegistry } from "src/indices/IndexComponentRegistry.sol";
import { console2 } from "forge-std/console2.sol";

/**
 * @title MigrateGardens
 * @notice Phase-3 migration script: flips gardens from the old index stack to the new one.
 *         Per garden, in ONE broadcast (so no garden is left disconnected):
 *           1. disconnectFromIndex()
 *           2. configureIndexModule(newIndexFactory, newComponentRegistry, POOL_REGISTRY)
 *           3. connectToIndex(newIndex)
 *           4. approveTokens(component tokens + USDC, newRebalancer)
 *
 *         ALL of these are onlyGardenOwner calls. The script flips every garden OWNED BY THE
 *         BROADCASTER; for other gardens it logs the owner so that key can run the same
 *         sequence (or re-run this script with that key as PRIVATE_KEY_ARB).
 *
 *         Env:
 *           MIGRATE_GARDENS         comma-separated "garden=newIndex" pairs, e.g.
 *                                   "0xAAA..=0xIDX5,0xBBB..=0xIDX5,0xCCC..=0xIDX2"
 *           NEW_INDEX_FACTORY       from MigrateRegistryAndIndices output
 *           NEW_COMPONENT_REGISTRY  from MigrateRegistryAndIndices output
 *           NEW_REBALANCER          from MigrateRegistryAndIndices output
 *           POOL_REGISTRY_ADDRESS   live LiquidityPoolRegistry (unchanged)
 *
 *         Note: the old rebalancer's allowances are NOT revoked — ApproveFacet only grants
 *         max. This is bounded: after RetireOldRebalancer removes the index types, the old
 *         rebalancer's cumulativeRebalance reverts NoIndicesRegistered permanently.
 */
contract MigrateGardens is BaseScript {
    address internal constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    function run() public broadcaster {
        setUp();
        address newIndexFactory = vm.envAddress("NEW_INDEX_FACTORY");
        address newRegistryAddr = vm.envAddress("NEW_COMPONENT_REGISTRY");
        address newRebalancer = vm.envAddress("NEW_REBALANCER");
        address poolRegistry = vm.envAddress("POOL_REGISTRY_ADDRESS");
        IndexComponentRegistry registry = IndexComponentRegistry(newRegistryAddr);

        (address[] memory gardens, address[] memory newIndices) = _parsePairs(vm.envString("MIGRATE_GARDENS"));

        for (uint256 i = 0; i < gardens.length; i++) {
            address garden = gardens[i];
            address newIndex = newIndices[i];
            (bool okOwner, bytes memory ownerRet) = garden.call(abi.encodeWithSignature("owner()"));
            address gardenOwner = okOwner ? abi.decode(ownerRet, (address)) : address(0);

            if (gardenOwner != deployer) {
                console2.log(unicode"SKIP (not broadcaster-owned) - owner must run the 4-tx sequence:", garden);
                console2.log("  owner:", gardenOwner);
                console2.log("  target index:", newIndex);
                continue;
            }

            console2.log("Migrating garden:", garden);

            // Balance snapshot — the flip must move nothing
            uint256 usdcBefore = IERC20(USDC).balanceOf(garden);

            // 1. disconnect (clears any pending intent + removes from the old index)
            (bool ok1,) = garden.call(abi.encodeWithSignature("disconnectFromIndex()"));
            require(ok1, "disconnect failed");
            console2.log("  1. disconnected from old index");

            // 2. repoint the index module to the new stack (requires disconnected + no intent)
            (bool ok2,) = garden.call(
                abi.encodeWithSignature(
                    "configureIndexModule(address,address,address)", newIndexFactory, newRegistryAddr, poolRegistry
                )
            );
            require(ok2, "configureIndexModule failed");
            console2.log("  2. index module repointed to new stack");

            // 3. connect to the new index
            (bool ok3,) = garden.call(abi.encodeWithSignature("connectToIndex(address)", newIndex));
            require(ok3, "connectToIndex failed");
            console2.log("  3. connected to new index");

            // 4. approve the new rebalancer for every component of the new index + USDC
            (bool okW, bytes memory wRet) = newIndex.call(abi.encodeWithSignature("getWeights()"));
            require(okW, "getWeights failed");
            (bytes32[] memory symbols,) = abi.decode(wRet, (bytes32[], uint256[]));

            address[] memory tokens = new address[](symbols.length + 1);
            for (uint256 j = 0; j < symbols.length; j++) {
                tokens[j] = registry.getComponentAddress(symbols[j]);
            }
            tokens[symbols.length] = USDC;

            (bool ok4,) =
                garden.call(abi.encodeWithSignature("approveTokens(address[],address)", tokens, newRebalancer));
            require(ok4, "approveTokens failed");
            console2.log("  4. approved new rebalancer for all components + USDC");

            // Post-verify: connected to the new index, balances untouched
            (bool okC, bytes memory cRet) = garden.call(abi.encodeWithSignature("getConnectedIndex()"));
            require(okC && abi.decode(cRet, (address)) == newIndex, "post-verify: wrong connected index");
            uint256 usdcAfter = IERC20(USDC).balanceOf(garden);
            require(usdcAfter == usdcBefore, "post-verify: USDC balance changed during flip");
            console2.log("  verified: connected to new index, balances untouched");
        }
        console2.log("Garden migration pass complete");
    }

    /// @dev Parses "garden=newIndex,garden=newIndex,..." into parallel arrays
    function _parsePairs(string memory raw) internal pure returns (address[] memory gardens, address[] memory indices) {
        bytes memory b = bytes(raw);
        uint256 count = 1;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == ",") count++;
        }
        gardens = new address[](count);
        indices = new address[](count);
        uint256 idx;
        uint256 start;
        for (uint256 i = 0; i <= b.length; i++) {
            if (i == b.length || b[i] == ",") {
                (gardens[idx], indices[idx]) = _parsePair(_slice(raw, start, i));
                idx++;
                start = i + 1;
            }
        }
    }

    function _parsePair(string memory pair) internal pure returns (address garden, address index) {
        bytes memory b = bytes(pair);
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == "=") {
                garden = vm.parseAddress(_slice(pair, 0, i));
                index = vm.parseAddress(_slice(pair, i + 1, b.length));
                return (garden, index);
            }
        }
        revert("invalid pair, expected garden=newIndex");
    }

    function _slice(string memory raw, uint256 start, uint256 end) internal pure returns (string memory) {
        bytes memory b = bytes(raw);
        bytes memory out = new bytes(end - start);
        for (uint256 i = start; i < end; i++) {
            out[i - start] = b[i];
        }
        return string(out);
    }
}
