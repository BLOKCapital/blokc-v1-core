// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Test } from "forge-std/Test.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import {
    TreasuryRegistry,
    TreasuryInfo,
    TreasuryRegistry_InvalidTreasuryAddress,
    TreasuryRegistry_CannotRenounceOwnership
} from "../../../src/fees/TreasuryRegistry.sol";
import {
    OnboarderRegistry,
    OnboarderRegistry_InvalidOnboarderAddress,
    OnboarderRegistry_AlreadyRegistered,
    OnboarderRegistry_NotRegistered,
    OnboarderRegistry_CannotRenounceOwnership
} from "../../../src/fees/OnboarderRegistry.sol";

contract TreasuryRegistryTest is Test {
    TreasuryRegistry internal treasuryRegistry;
    address internal owner = makeAddr("owner");
    address internal nonOwner = makeAddr("nonOwner");
    address internal treasury = makeAddr("treasury");

    function setUp() public {
        treasuryRegistry = new TreasuryRegistry(owner);
    }

    function test_startsUnset() public view {
        assertEq(treasuryRegistry.getTreasuryAddress(), address(0));
    }

    function test_setTreasuryAddress_happy_recordsAuditFields() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, true, address(treasuryRegistry));
        emit TreasuryRegistry.TreasuryAddressUpdated(address(0), treasury, block.number, bytes32("proposal-1"));
        treasuryRegistry.setTreasuryAddress(treasury, bytes32("proposal-1"));

        assertEq(treasuryRegistry.getTreasuryAddress(), treasury);
        TreasuryInfo memory info = treasuryRegistry.getTreasuryInfo();
        assertEq(info.treasuryAddress, treasury);
        assertEq(info.updatedAtBlock, block.number);
        assertEq(info.updatedAtTimestamp, block.timestamp);
        assertEq(info.updatedBy, owner);
        assertEq(info.proposalRef, bytes32("proposal-1"));
    }

    function test_rotate_updatesFields() public {
        address newTreasury = makeAddr("newTreasury");
        vm.startPrank(owner);
        treasuryRegistry.setTreasuryAddress(treasury, bytes32("p1"));
        treasuryRegistry.setTreasuryAddress(newTreasury, bytes32("p2"));
        vm.stopPrank();

        assertEq(treasuryRegistry.getTreasuryAddress(), newTreasury);
        TreasuryInfo memory info = treasuryRegistry.getTreasuryInfo();
        assertEq(info.updatedAtBlock, block.number);
        assertEq(info.updatedBy, owner);
        assertEq(info.proposalRef, bytes32("p2"));
    }

    function test_setTreasuryAddress_revert_zero() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(TreasuryRegistry_InvalidTreasuryAddress.selector, address(0)));
        treasuryRegistry.setTreasuryAddress(address(0), bytes32(""));
    }

    function test_setTreasuryAddress_revert_nonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        treasuryRegistry.setTreasuryAddress(treasury, bytes32(""));
    }

    function test_constructor_revert_zeroOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new TreasuryRegistry(address(0));
    }

    function test_renounceOwnership_reverts() public {
        vm.prank(owner);
        vm.expectRevert(TreasuryRegistry_CannotRenounceOwnership.selector);
        treasuryRegistry.renounceOwnership();
    }
}

contract OnboarderRegistryTest is Test {
    OnboarderRegistry internal onboarderRegistry;
    address internal owner = makeAddr("owner");
    address internal nonOwner = makeAddr("nonOwner");
    address internal onboarder = makeAddr("onboarder");

    function setUp() public {
        onboarderRegistry = new OnboarderRegistry(owner);
    }

    function test_addOnboarder_happy_eligible() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, false, address(onboarderRegistry));
        emit OnboarderRegistry.OnboarderAdded(onboarder);
        onboarderRegistry.addOnboarder(onboarder);

        assertTrue(onboarderRegistry.isOnboarderEligible(onboarder));
        assertEq(onboarderRegistry.getOnboarderCount(), 1);
        address[] memory list = onboarderRegistry.getOnboarders();
        assertEq(list.length, 1);
        assertEq(list[0], onboarder);
    }

    function test_addOnboarder_revert_zero() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(OnboarderRegistry_InvalidOnboarderAddress.selector, address(0)));
        onboarderRegistry.addOnboarder(address(0));
    }

    function test_addOnboarder_revert_duplicate() public {
        vm.startPrank(owner);
        onboarderRegistry.addOnboarder(onboarder);
        vm.expectRevert(abi.encodeWithSelector(OnboarderRegistry_AlreadyRegistered.selector, onboarder));
        onboarderRegistry.addOnboarder(onboarder);
        vm.stopPrank();
    }

    function test_removeOnboarder_happy() public {
        vm.startPrank(owner);
        onboarderRegistry.addOnboarder(onboarder);
        vm.expectEmit(true, false, false, false, address(onboarderRegistry));
        emit OnboarderRegistry.OnboarderRemoved(onboarder);
        onboarderRegistry.removeOnboarder(onboarder);
        vm.stopPrank();

        assertFalse(onboarderRegistry.isOnboarderEligible(onboarder));
    }

    function test_removeOnboarder_revert_notRegistered() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(OnboarderRegistry_NotRegistered.selector, onboarder));
        onboarderRegistry.removeOnboarder(onboarder);
    }

    function test_addOnboarder_revert_nonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        onboarderRegistry.addOnboarder(onboarder);
    }

    function test_constructor_revert_zeroOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new OnboarderRegistry(address(0));
    }

    function test_renounceOwnership_reverts() public {
        vm.prank(owner);
        vm.expectRevert(OnboarderRegistry_CannotRenounceOwnership.selector);
        onboarderRegistry.renounceOwnership();
    }
}
