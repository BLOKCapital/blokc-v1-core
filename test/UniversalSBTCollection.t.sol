// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import { UniversalSBTCollection } from "src/MembershipPass/collection/UniversalSBTCollection.sol";
import { IERC5484 } from "src/interfaces/IERC5484.sol";

contract UniversalSBTCollectionTest is Test {
    UniversalSBTCollection coll;

    address factory = address(0xF1);
    address alice = address(0xA1);

    // Mirror contract errors for selectors
    error NotFactory();
    error MintingClosed();

    function setUp() public {
        coll = new UniversalSBTCollection(
            "U",
            "U",
            "desc",
            "bafybase",
            0, // maxSupply = 0 => unlimited
            IERC5484.BurnAuth.Both,
            factory
        );
    }

    // -------------------------------------------------------------------------
    // Test: Burn auth is assigned correctly
    // -------------------------------------------------------------------------
    function test_mint_sets_correct_burn_auth() public {
        vm.prank(factory);
        uint256 id = coll.mint(alice);
        assertEq(id, 1);

        (address holder, IERC5484.BurnAuth auth) = coll.getTokenData(1);
        assertEq(holder, alice);
        assertEq(uint256(auth), uint256(IERC5484.BurnAuth.Both));
    }

    // -------------------------------------------------------------------------
    // Test: Only factory can mint
    // -------------------------------------------------------------------------
    function test_onlyFactoryCanMint() public {
        vm.prank(factory);
        uint256 id = coll.mint(alice);
        assertEq(id, 1);
    }

    // -------------------------------------------------------------------------
    // Test: Mint reverts for non-factory
    // -------------------------------------------------------------------------
    function test_mint_rejects_when_not_factory() public {
        vm.expectRevert(NotFactory.selector);
        coll.mint(alice);
    }

    // -------------------------------------------------------------------------
    // Test: Minting closed prevents minting
    // -------------------------------------------------------------------------
    function test_closeMinting_prevents_mint() public {
        vm.prank(factory);
        coll.mint(alice);

        vm.prank(factory);
        coll.closeMinting();

        vm.expectRevert(MintingClosed.selector);
        vm.prank(factory);
        coll.mint(address(0xB1));
    }
}
