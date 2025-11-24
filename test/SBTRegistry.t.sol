// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import { SBTRegistry } from "src/GardenSBT/CollectionRegistry/SBTRegistry.sol";
import { BaddieCollection } from "src/GardenSBT/Collection/BaddieCollection.sol";
import { BuilderCollection } from "src/GardenSBT/Collection/BuilderCollection.sol";
import { GardenCollection } from "src/GardenSBT/Collection/GardenCollection.sol";

contract SBTRegistryTest is Test {
    SBTRegistry registry;
    BaddieCollection baddie;
    BuilderCollection builder;
    GardenCollection garden;

    error NotCollectionOwner();
    error NotAuthorized();

    address deployer = address(this);
    address alice = address(0x1111111111111111111111111111111111111111);

    function setUp() public {
        // registry owner (gardenFactory) is deployer (this)
        registry = new SBTRegistry(deployer);

        baddie = new BaddieCollection("bafyB", address(0));
        builder = new BuilderCollection("bafyBU", address(0));
        garden = new GardenCollection("bafyG", address(0));

        // Make registry the owner of each collection (required by registerCollection)
        baddie.transferOwnership(address(registry));
        builder.transferOwnership(address(registry));
        garden.transferOwnership(address(registry));

        // register them
        registry.registerCollection("Baddie", address(baddie));
        registry.registerCollection("Builder", address(builder));
        registry.registerCollection("Garden", address(garden));
    }

    // ------------------------------------------------------------
    // mintByAddress
    // ------------------------------------------------------------
    function test_registry_mint_by_address() public {
        uint256 tid = registry.mintByAddress(address(garden), alice, 1);
        assertEq(tid, 1);
        assertEq(garden.ownerOf(1), alice);
    }

    // ------------------------------------------------------------
    // registering a collection when registry is NOT the owner
    // ------------------------------------------------------------
    function test_register_requires_registry_to_be_owner_of_collection() public {
        // Deploy collection NOT owned by registry (deployer = 0xBEEF)
        vm.prank(address(0xBEEF));
        GardenCollection ext = new GardenCollection("bafyX", address(0));

        // must revert with NotCollectionOwner
        vm.expectRevert(NotCollectionOwner.selector);
        registry.registerCollection("X", address(ext));
    }

    // ------------------------------------------------------------
    // only owner should mint — unauthorized user should fail
    // ------------------------------------------------------------
    function test_unauthorized_mint_reverts() public {
        vm.prank(address(0x999)); // not owner

        vm.expectRevert(NotAuthorized.selector);
        registry.mintByAddress(address(garden), alice, 1);
    }
}
