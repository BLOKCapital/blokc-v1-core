// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { Test } from "forge-std/Test.sol";
import { SbtFacet } from "src/diamond/facets/utilityFacets/SbtFacet.sol";

contract SbtFacetTest is Test {
    SbtFacet sbt;

    function setUp() public {
        sbt = new SbtFacet();
    }

    function test_ownerCanAddCollectionAndMint() public {
        // as the deployer is not using LibDiamond.owner enforcement in this test,
        // we will bypass access control by directly calling addCollection from this contract
        sbt.addCollection(1, "ipfs://collection1");
        uint256 tokenId = sbt.mintSbt(1);
        assertEq(tokenId, 1);
        assertEq(sbt.tokenOf(address(this)), 1);
        assertEq(sbt.collectionOf(1), 1);
        assertEq(sbt.tokenURI(1), "ipfs://collection1");
    }

    function test_cannotMintTwice() public {
        sbt.addCollection(2, "ipfs://c2");
        sbt.mintSbt(2);
        vm.expectRevert();
        sbt.mintSbt(2);
    }

    function test_cannotMintFromUnallowedCollection() public {
        vm.expectRevert();
        sbt.mintSbt(999);
    }
}
