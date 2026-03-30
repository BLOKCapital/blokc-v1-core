// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Test } from "forge-std/Test.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IndicesTestSetUp } from "test/indices/IndicesTestSetUp.sol";
import {
    IndexCalculationRegistry,
    IndexCalculationRegistry_InvalidInitialOwner,
    IndexCalculationRegistry_InvalidIndexCalculationAddress,
    IndexCalculationRegistry_IndexCalculationAlreadyRegistered,
    IndexCalculationRegistry_IndexCalculationNotRegistered
} from "../../../src/indices/IndexCalculationRegistry.sol";

contract IndexCalculationRegistryTest is IndicesTestSetUp {
    address nonOwner = makeAddr("nonOwner");
    address calcStrategy = makeAddr("calcStrategy");

    // ═══════════════════════════════════════════════════════════════════════
    //                     Modifier
    // ═══════════════════════════════════════════════════════════════════════

    modifier registerIndexCalculation() {
        vm.startPrank(owner);
        indexCalRegistry.registerIndexCalculation(calcStrategy);
        vm.stopPrank();
        _;
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                     Constructor
    // ═══════════════════════════════════════════════════════════════════════

    function test_constructor_revert_onlyOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        indexCalRegistry.registerIndexCalculation(calcStrategy);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                     Register Index Calculation
    // ═══════════════════════════════════════════════════════════════════════
    function test_registerIndexCalculation() public {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit IndexCalculationRegistry.IndexCalculationRegistered(calcStrategy, 1);
        indexCalRegistry.registerIndexCalculation(calcStrategy);
        vm.stopPrank();

        // storage variable check
        bool isRegistered = indexCalRegistry.isIndexCalculationRegistered(calcStrategy);
        address[] memory allIndexAddress = indexCalRegistry.getIndexCalculationAddresses();
        IndexCalculationRegistry.IndexCalculationInfo memory info =
            indexCalRegistry.getIndexCalculationInfo(calcStrategy);

        assertEq(isRegistered, true);
        assertEq(allIndexAddress.length, 1);
        assertEq(allIndexAddress[0], calcStrategy);
        assertEq(info.id, 1);
        assertEq(info.indexCalculationAddress, calcStrategy);
        assertEq(info.registeredAt, block.timestamp);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                     Register Index Calculation -- Revert
    // ═══════════════════════════════════════════════════════════════════════

    function test_registerIndexCalculation_non_owner() public {
        vm.startPrank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        indexCalRegistry.registerIndexCalculation(calcStrategy);
        vm.stopPrank();
    }

    function test_registerIndexCalculation_addressZero() public {
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IndexCalculationRegistry_InvalidIndexCalculationAddress.selector, address(0))
        );
        indexCalRegistry.registerIndexCalculation(address(0));
        vm.stopPrank();
    }

    function test_registerIndexCalculation_alreadyRegistered() public {
        vm.startPrank(owner);
        indexCalRegistry.registerIndexCalculation(calcStrategy);
        vm.expectRevert(
            abi.encodeWithSelector(
                IndexCalculationRegistry_IndexCalculationAlreadyRegistered.selector, address(calcStrategy)
            )
        );
        indexCalRegistry.registerIndexCalculation(calcStrategy);
        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                   Unregister Index Calculation
    // ═══════════════════════════════════════════════════════════════════════

    function test_unregisterIndexCalculation() public registerIndexCalculation {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, false);
        emit IndexCalculationRegistry.IndexCalculationUnregistered(calcStrategy);
        indexCalRegistry.unregisterIndexCalculation(address(calcStrategy));
        vm.stopPrank();

        // storage variable check
        bool isRegistered = indexCalRegistry.isIndexCalculationRegistered(calcStrategy);
        address[] memory allIndexAddress = indexCalRegistry.getIndexCalculationAddresses();
        IndexCalculationRegistry.IndexCalculationInfo memory info =
            indexCalRegistry.getIndexCalculationInfo(calcStrategy);

        assertEq(isRegistered, false);
        assertEq(allIndexAddress.length, 0);
        assertEq(info.id, 0);
        assertEq(info.indexCalculationAddress, address(0));
        assertEq(info.registeredAt, 0);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                   Unregister Index Calculation -- Revert
    // ═══════════════════════════════════════════════════════════════════════

    function test_unregisterIndexCalculation_nonOwner() public registerIndexCalculation {
        vm.startPrank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        indexCalRegistry.unregisterIndexCalculation(address(calcStrategy));
        vm.stopPrank();
    }

    function test_unregisterIndexCalculation_unregisteredIndex() public {
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IndexCalculationRegistry_IndexCalculationNotRegistered.selector, calcStrategy)
        );
        indexCalRegistry.unregisterIndexCalculation(address(calcStrategy));
        vm.stopPrank();
    }
}

