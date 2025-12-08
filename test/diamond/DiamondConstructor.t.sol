// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { Diamond } from "src/diamond/Diamond.sol";
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";
import { DiamondCutFacet } from "src/diamond/facets/baseFacets/cut/DiamondCutFacet.sol";
import { DiamondLoupeFacet } from "src/diamond/facets/baseFacets/loupe/DiamondLoupeFacet.sol";
import { OwnershipFacet } from "src/diamond/facets/baseFacets/ownership/OwnershipFacet.sol";
import { UpgradeFacet } from "src/diamond/facets/baseFacets/upgrade/UpgradeFacet.sol";
import { IERC165 } from "src/interfaces/IERC165.sol";

// Define error for testing
error Diamond_ContractOwnerIsZero();

/// @title DiamondConstructorTest
/// @notice Tests for Diamond constructor
contract DiamondConstructorTest is Test {
    function test_RevertIf_Constructor_OwnerIsZero() public {
        DiamondCutFacet cutFacet = new DiamondCutFacet();
        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();
        UpgradeFacet upgradeFacet = new UpgradeFacet();

        bytes4[] memory cutSelectors = new bytes4[](1);
        cutSelectors[0] = cutFacet.diamondCut.selector;

        bytes4[] memory loupeSelectors = new bytes4[](5);
        loupeSelectors[0] = loupeFacet.facets.selector;
        loupeSelectors[1] = loupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = loupeFacet.facetAddresses.selector;
        loupeSelectors[3] = loupeFacet.facetAddress.selector;
        loupeSelectors[4] = IERC165.supportsInterface.selector;

        bytes4[] memory ownershipSelectors = new bytes4[](2);
        ownershipSelectors[0] = ownershipFacet.owner.selector;
        ownershipSelectors[1] = ownershipFacet.transferOwnership.selector;

        bytes4[] memory upgradeSelectors = new bytes4[](3);
        upgradeSelectors[0] = upgradeFacet.upgrade.selector;
        upgradeSelectors[1] = upgradeFacet.getCurrentVersion.selector;
        upgradeSelectors[2] = upgradeFacet.upgradeDetails.selector;

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](4);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(cutFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: cutSelectors
        });
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(loupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });
        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ownershipSelectors
        });
        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(upgradeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: upgradeSelectors
        });

        // Create valid addresses for facetRegistry and protocolStatus
        address facetRegistry = makeAddr("facetRegistry");
        address protocolStatus = makeAddr("protocolStatus");

        vm.expectRevert(Diamond_ContractOwnerIsZero.selector);
        new Diamond(cuts, address(0), facetRegistry, protocolStatus);
    }
}
