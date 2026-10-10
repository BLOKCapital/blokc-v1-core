// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { Test } from "forge-std/Test.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import {
    FeeRegistry,
    FeeRegistry_ExceedsMaxPerformanceFeeBps,
    FeeRegistry_ExceedsMaxProtocolFeeBps,
    FeeRegistry_ExceedsMaxOnboarderShareBps,
    FeeRegistry_FeeSumExceedsProfit,
    FeeRegistry_InvalidAssessmentBase,
    FeeRegistry_InvalidApplyRateAt,
    FeeRegistry_CapBelowCurrentValue,
    FeeRegistry_InvalidCap,
    FeeRegistry_CannotRenounceOwnership
} from "../../../src/fees/FeeRegistry.sol";

contract FeeRegistryTest is Test {
    FeeRegistry internal feeRegistry;
    address internal owner = makeAddr("owner");
    address internal nonOwner = makeAddr("nonOwner");

    function setUp() public {
        feeRegistry = new FeeRegistry(owner);
    }

    function test_constructor_setsDefaults() public view {
        (uint256 perf, uint256 proto, uint256 onboarderShare, uint8 assessmentBase, uint8 applyRateAt) =
            feeRegistry.getFeeSchedule();
        assertEq(perf, 1000);
        assertEq(proto, 200);
        assertEq(onboarderShare, 5000);
        assertEq(assessmentBase, 0); // ProfitAtDisconnect
        assertEq(applyRateAt, 0); // ConnectLock

        (uint256 maxPerf, uint256 maxProto, uint256 maxOnboarder) = feeRegistry.getSafetyCaps();
        assertEq(maxPerf, 3000);
        assertEq(maxProto, 1000);
        assertEq(maxOnboarder, 10_000);
    }

    function test_constructor_revert_zeroOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new FeeRegistry(address(0));
    }

    function test_setPerformanceFeeBps_happy_emitsUpdated() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true, address(feeRegistry));
        emit FeeRegistry.PerformanceFeeBpsUpdated(1000, 1500);
        feeRegistry.setPerformanceFeeBps(1500);
        assertEq(feeRegistry.getPerformanceFeeBps(), 1500);
    }

    function test_setPerformanceFeeBps_revert_aboveCap() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(FeeRegistry_ExceedsMaxPerformanceFeeBps.selector, 3001, 3000));
        feeRegistry.setPerformanceFeeBps(3001);
    }

    function test_setSafetyCaps_revert_capSumExceedsProfit() public {
        // The caps themselves are constrained to sum <= 10_000, which (rates <= caps) keeps the
        // investor invariant performanceFee + protocolFee <= profit satisfiable for every
        // reachable schedule.
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(FeeRegistry_FeeSumExceedsProfit.selector, 6000, 5000));
        feeRegistry.setSafetyCaps(6000, 5000, 10_000);
    }

    function test_setOnboarderShareBps_revert_aboveCap() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(FeeRegistry_ExceedsMaxOnboarderShareBps.selector, 10_001, 10_000));
        feeRegistry.setOnboarderShareBps(10_001);
    }

    function test_raise_afterCapIncrease_succeeds() public {
        // Spec: a raise above a cap reverts until the cap itself is changed in a separate vote
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(FeeRegistry_ExceedsMaxPerformanceFeeBps.selector, 3500, 3000));
        feeRegistry.setPerformanceFeeBps(3500);

        feeRegistry.setSafetyCaps(3500, 1000, 10_000);
        feeRegistry.setPerformanceFeeBps(3500);
        vm.stopPrank();
        assertEq(feeRegistry.getPerformanceFeeBps(), 3500);
    }

    function test_setSafetyCaps_revert_capBelowCurrentValue() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(FeeRegistry_CapBelowCurrentValue.selector, "performance", 500, 1000));
        feeRegistry.setSafetyCaps(500, 1000, 10_000);
    }

    function test_setSafetyCaps_revert_onboarderCapAboveHardBound() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(FeeRegistry_InvalidCap.selector, 10_001));
        feeRegistry.setSafetyCaps(3000, 1000, 10_001);
    }

    function test_setSafetyCaps_happy_emits() public {
        vm.prank(owner);
        vm.expectEmit(false, false, false, true, address(feeRegistry));
        emit FeeRegistry.SafetyCapsUpdated(2000, 800, 8000);
        feeRegistry.setSafetyCaps(2000, 800, 8000);
        (uint256 maxPerf, uint256 maxProto, uint256 maxOnboarder) = feeRegistry.getSafetyCaps();
        assertEq(maxPerf, 2000);
        assertEq(maxProto, 800);
        assertEq(maxOnboarder, 8000);
    }

    function test_setAssessmentBase_revert_invalidValue() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(FeeRegistry_InvalidAssessmentBase.selector, 1));
        feeRegistry.setAssessmentBase(1); // only ProfitAtDisconnect (0) exists in V1
    }

    function test_setApplyRateAt_happy_and_revert_invalidValue() public {
        vm.prank(owner);
        feeRegistry.setApplyRateAt(1); // DisconnectLive
        assertEq(feeRegistry.getApplyRateAt(), 1);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(FeeRegistry_InvalidApplyRateAt.selector, 2));
        feeRegistry.setApplyRateAt(2);
    }

    function test_setters_revert_nonOwner() public {
        vm.startPrank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        feeRegistry.setPerformanceFeeBps(1500);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        feeRegistry.setSafetyCaps(3000, 1000, 10_000);
        vm.stopPrank();
    }

    function test_renounceOwnership_reverts() public {
        vm.prank(owner);
        vm.expectRevert(FeeRegistry_CannotRenounceOwnership.selector);
        feeRegistry.renounceOwnership();
    }
}
