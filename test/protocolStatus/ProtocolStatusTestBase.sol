// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { ProtocolStatus } from "src/protocolStatus/ProtocolStatus.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";

/// @title Base test contract for ProtocolStatus tests
abstract contract ProtocolStatusTestBase is Test {
    ProtocolStatus internal protocolStatus;

    address internal owner;
    address internal user1;
    address internal user2;
    address internal nonOwner;
    address internal securityCouncil1;
    address internal securityCouncil2;
    address internal securityCouncil3;

    IProtocolStatus.SecurityCouncilMember[] internal initialMembers;

    event ProtocolStatusChanged(
        IProtocolStatus.State indexed oldStatus,
        IProtocolStatus.State indexed newStatus,
        address indexed changedBy,
        string name
    );
    event SecurityCouncilMemberAdded(address indexed member, string name);
    event SecurityCouncilMemberRemoved(address indexed member, string name);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setUp() public virtual {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        nonOwner = makeAddr("nonOwner");
        securityCouncil1 = makeAddr("securityCouncil1");
        securityCouncil2 = makeAddr("securityCouncil2");
        securityCouncil3 = makeAddr("securityCouncil3");

        vm.deal(owner, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(securityCouncil1, 100 ether);
        vm.deal(securityCouncil2, 100 ether);
        vm.deal(securityCouncil3, 100 ether);

        // Setup initial Security Council members
        initialMembers = new IProtocolStatus.SecurityCouncilMember[](2);
        initialMembers[0] = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil1,
            name: "Security Council Member 1"
        });
        initialMembers[1] = IProtocolStatus.SecurityCouncilMember({
            memberAddress: securityCouncil2,
            name: "Security Council Member 2"
        });

        // Deploy ProtocolStatus
        protocolStatus = new ProtocolStatus(initialMembers, owner);
    }
}

