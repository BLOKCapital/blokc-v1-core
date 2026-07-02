// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import "forge-std/Test.sol";
import { ProtocolStatus } from "src/protocolStatus/ProtocolStatus.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract ProtocolStatusTest is Test {
    using stdStorage for StdStorage;

    ProtocolStatus ps;
    address owner = makeAddr("owner");
    address stranger = makeAddr("stranger");

    function setUp() public {
        vm.prank(owner);
        ps = new ProtocolStatus(owner);
    }

    // =====================================================================
    // Constructor
    // =====================================================================

    function test_constructor_startsActive() public {
        assertEq(uint256(ps.getProtocolStatus()), uint256(IProtocolStatus.State.ACTIVE));
    }

    function test_constructor_emitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit ProtocolStatus.ProtocolStatusChanged(IProtocolStatus.State.INACTIVE, IProtocolStatus.State.ACTIVE, owner);
        vm.prank(owner);
        new ProtocolStatus(owner);
    }

    function test_constructor_revertsOnZeroOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new ProtocolStatus(address(0));
    }

    function test_constructor_setsOwner() public {
        assertEq(ps.owner(), owner);
    }

    // =====================================================================
    // Activate
    // =====================================================================

    function test_activate_revertsIfAlreadyActive() public {
        vm.prank(owner);
        vm.expectRevert(ProtocolStatus.ProtocolStatus_ProtocolIsAlreadyActive.selector);
        ps.activateProtocol();
    }

    function test_activate_onlyOwner() public {
        // First deactivate to make activation possible
        vm.prank(owner);
        ps.deactivateProtocol();

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        ps.activateProtocol();
    }

    function test_activate_succeeds() public {
        vm.startPrank(owner);
        ps.deactivateProtocol();

        vm.expectEmit(true, true, true, true);
        emit ProtocolStatus.ProtocolStatusChanged(IProtocolStatus.State.INACTIVE, IProtocolStatus.State.ACTIVE, owner);
        ps.activateProtocol();
        assertEq(uint256(ps.getProtocolStatus()), uint256(IProtocolStatus.State.ACTIVE));
        vm.stopPrank();
    }

    // =====================================================================
    // Deactivate
    // =====================================================================

    function test_deactivate_revertsIfAlreadyInactive() public {
        vm.startPrank(owner);
        ps.deactivateProtocol();
        vm.expectRevert(ProtocolStatus.ProtocolStatus_ProtocolIsAlreadyInactive.selector);
        ps.deactivateProtocol();
        vm.stopPrank();
    }

    function test_deactivate_onlyOwner() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        ps.deactivateProtocol();
    }

    function test_deactivate_succeeds() public {
        vm.prank(owner);
        ps.deactivateProtocol();
        assertEq(uint256(ps.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));
    }

    // =====================================================================
    // Disable Upgrades
    // =====================================================================

    function test_disableUpgrades_revertsIfNotActive() public {
        vm.startPrank(owner);
        ps.deactivateProtocol();
        vm.expectRevert(ProtocolStatus.ProtocolStatus_MustBeActiveToDisableUpgrades.selector);
        ps.disableUpgrades();
        vm.stopPrank();
    }

    function test_disableUpgrades_onlyOwner() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        ps.disableUpgrades();
    }

    function test_disableUpgrades_succeeds() public {
        vm.prank(owner);
        ps.disableUpgrades();
        assertEq(uint256(ps.getProtocolStatus()), uint256(IProtocolStatus.State.UPGRADES_DISABLED));
    }

    // =====================================================================
    // State transitions
    // =====================================================================

    function test_fullStateTransitionCycle() public {
        vm.startPrank(owner);
        // ACTIVE -> UPGRADES_DISABLED
        ps.disableUpgrades();
        assertEq(uint256(ps.getProtocolStatus()), uint256(IProtocolStatus.State.UPGRADES_DISABLED));

        // Can still go to INACTIVE from UPGRADES_DISABLED (pausing works)
        ps.deactivateProtocol();
        assertEq(uint256(ps.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));

        // Can activate back from INACTIVE
        ps.activateProtocol();
        assertEq(uint256(ps.getProtocolStatus()), uint256(IProtocolStatus.State.ACTIVE));
        vm.stopPrank();
    }
}
