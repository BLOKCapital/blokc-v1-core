// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { BaddieCollection } from "src/GardenSBT/Collection/BaddieCollection.sol";
import { BuilderCollection } from "src/GardenSBT/Collection/BuilderCollection.sol";
import { GardenCollection } from "src/GardenSBT/Collection/GardenCollection.sol";
import { MockERC721 } from "./Mocks.t.sol";

contract CollectionsTest is Test {
    MockERC721 parentPass;
    BaddieCollection baddie;
    BuilderCollection builder;
    GardenCollection garden;

    // Mirror contract errors for selector checking
    error NoMembershipPass(address to);
    error AlreadyHasSBT(address to);
    error NonTransferable();

    address registry = address(0xABCD);
    address user = address(0x1111);
    address user2 = address(0x2222);

    function setUp() public {
        parentPass = new MockERC721("Parent", "P");

        // Deploy collections as the registry so registry is the owner of the collections
        vm.startPrank(registry);
        baddie = new BaddieCollection("bafyBaddie", address(parentPass));
        builder = new BuilderCollection("bafyBuilder", address(parentPass));
        // Garden is open (no parent pass) for open-mint tests → pass address(0)
        garden = new GardenCollection("bafyGarden", address(0));
        vm.stopPrank();
    }

    // ----------------------------------------------------------
    // BADDIE TESTS
    // ----------------------------------------------------------

    function test_baddie_parentCheck_fails_if_no_pass() public {
        vm.startPrank(registry);

        vm.expectRevert(abi.encodeWithSelector(NoMembershipPass.selector, user));
        baddie.mint(user, 1);

        vm.stopPrank();
    }

    function test_baddie_mint_success_after_pass() public {
        // give user the parent pass
        parentPass.mint(user);

        vm.prank(registry);
        uint256 tid = baddie.mint(user, 1);
        assertEq(tid, 1);
        assertEq(baddie.ownerOf(1), user);
    }

    // ----------------------------------------------------------
    // BUILDER TESTS (WITH PASS CHECK)
    // ----------------------------------------------------------

    function test_builder_parentCheck_fails_if_no_pass() public {
        vm.startPrank(registry);

        vm.expectRevert(abi.encodeWithSelector(NoMembershipPass.selector, user));
        builder.mint(user, 1);

        vm.stopPrank();
    }

    function test_builder_mint_and_limits() public {
        // give user the parent pass
        parentPass.mint(user);

        vm.prank(registry);
        uint256 tid = builder.mint(user, 1);
        assertEq(tid, 1);

        // second mint for same user should revert AlreadyHasSBT
        vm.prank(registry);
        vm.expectRevert(abi.encodeWithSelector(AlreadyHasSBT.selector, user));
        builder.mint(user, 2);
    }

    // ----------------------------------------------------------
    // GARDEN TESTS (open mint)
    // ----------------------------------------------------------

    function test_garden_open_mint() public {
        vm.prank(registry);
        uint256 t1 = garden.mint(user, 1);
        assertEq(t1, 1);

        vm.prank(registry);
        uint256 t2 = garden.mint(user2, 2);
        assertEq(t2, 2);
    }

    // ----------------------------------------------------------
    // SOULBOUND TEST
    // ----------------------------------------------------------

    function test_soulbound_prevents_transfer() public {
        parentPass.mint(user);

        vm.prank(registry);
        baddie.mint(user, 1);

        vm.prank(user);
        vm.expectRevert(NonTransferable.selector);
        baddie.transferFrom(user, address(0xC1), 1);
    }
}
