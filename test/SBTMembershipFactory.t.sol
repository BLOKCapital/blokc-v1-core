// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import { SBTMembershipFactory } from "src/MembershipPass/factory/SBTMembershipFactory.sol";
import { MockERC721 } from "./Mocks.t.sol";
import { IERC5484 } from "src/interfaces/IERC5484.sol";
import { UniversalSBTCollection } from "src/MembershipPass/collection/UniversalSBTCollection.sol";

contract SBTMembershipFactoryTest is Test {
    SBTMembershipFactory factory;
    MockERC721 parentPass;

    error NotAuthorized();
    error CollectionNotFound();

    address ownerAddr = address(this);
    address worker = address(0x1111111111111111111111111111111111111111);
    address alice = address(0x2222222222222222222222222222222222222222);

    function setUp() public {
        // factory owner (DAO) = this test contract
        factory = new SBTMembershipFactory(ownerAddr);
        parentPass = new MockERC721("Pass", "P");
    }

    function test_deploy_and_set_policy_and_worker_mint() public {
        // Deploy collection as DAO (ownerAddr)
        address col = factory.deployCollection(
            "BaddiePass",
            "BP",
            "desc",
            "bafyBP",
            0,
            IERC5484.BurnAuth.OwnerOnly,
            SBTMembershipFactory.MintPolicy.DAO_OR_WORKER
        );

        assertEq(factory.getCollection("BaddiePass"), col);

        factory.addWorkerForCollection(worker, col);

        vm.prank(worker);
        uint256 tid = factory.mintFromCollection(col, alice);
        assertEq(tid, 1);

        // burnAuth check
        (address holder, IERC5484.BurnAuth auth) = UniversalSBTCollection(col).getTokenData(1);
        assertEq(holder, alice);
        assertEq(uint256(auth), uint256(IERC5484.BurnAuth.OwnerOnly));

        // non-worker fails
        vm.prank(address(0xF));
        vm.expectRevert(NotAuthorized.selector);
        factory.mintFromCollection(col, address(0xB));
    }

    function test_dao_only_policy_blocks_worker() public {
        address col = factory.deployCollection(
            "DAOOnly", "DO", "desc", "bafyDO", 0, IERC5484.BurnAuth.Neither, SBTMembershipFactory.MintPolicy.DAO_ONLY
        );

        // DAO (owner) mints successfully
        uint256 tid = factory.mintFromCollection(col, alice);
        assertEq(tid, 1);

        // Add worker, but worker should not be allowed under DAO_ONLY
        factory.addWorkerForCollection(worker, col);

        vm.prank(worker);
        vm.expectRevert(NotAuthorized.selector);
        factory.mintFromCollection(col, address(0x9));
    }
}
