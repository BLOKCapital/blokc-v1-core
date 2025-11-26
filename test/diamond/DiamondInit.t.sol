// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { DiamondTestBase } from "./DiamondTestBase.sol";
import { Diamond } from "src/diamond/Diamond.sol";
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";
import { IDiamondLoupe } from "src/diamond/facets/baseFacets/loupe/IDiamondLoupe.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";
import { IERC165 } from "src/interfaces/IERC165.sol";
import { IUpgrade } from "src/diamond/facets/baseFacets/upgrade/IUpgrade.sol";

/// @title DiamondInitTest
/// @notice Tests for Diamond contract initialization
contract DiamondInitTest is DiamondTestBase {
    function test_InitializeSuccessfully() public view {
        // Diamond should be deployed and owner should be set
        assertEq(getDiamondOwnership().owner(), owner);
    }

    function test_InitialOwnerSetOnInitialization() public view {
        assertEq(getDiamondOwnership().owner(), owner);
        assertTrue(getDiamondOwnership().owner() != address(0));
    }

    function test_BaseFacetsRegisteredOnInitialization() public view {
        IDiamondLoupe.Facet[] memory facets = getDiamondLoupe().facets();

        // Should have exactly 4 base facets
        assertEq(facets.length, 4);

        // Verify each base facet is present
        bool hasCutFacet = false;
        bool hasLoupeFacet = false;
        bool hasOwnershipFacet = false;
        bool hasUpgradeFacet = false;

        for (uint256 i = 0; i < facets.length; i++) {
            if (facets[i].facetAddress == address(cutFacet)) hasCutFacet = true;
            if (facets[i].facetAddress == address(loupeFacet)) hasLoupeFacet = true;
            if (facets[i].facetAddress == address(ownershipFacet)) hasOwnershipFacet = true;
            if (facets[i].facetAddress == address(upgradeFacet)) hasUpgradeFacet = true;
        }

        assertTrue(hasCutFacet, "DiamondCutFacet not registered");
        assertTrue(hasLoupeFacet, "DiamondLoupeFacet not registered");
        assertTrue(hasOwnershipFacet, "OwnershipFacet not registered");
        assertTrue(hasUpgradeFacet, "UpgradeFacet not registered");
    }

    function test_BaseFacetSelectorsRegistered() public view {
        // Check DiamondCutFacet selectors
        bytes4[] memory cutSels = getDiamondLoupe().facetFunctionSelectors(address(cutFacet));
        assertEq(cutSels.length, cutSelectors.length);
        assertEq(cutSels[0], cutSelectors[0]);

        // Check DiamondLoupeFacet selectors
        bytes4[] memory loupeSels = getDiamondLoupe().facetFunctionSelectors(address(loupeFacet));
        assertEq(loupeSels.length, loupeSelectors.length);

        // Check OwnershipFacet selectors
        bytes4[] memory ownerSels = getDiamondLoupe().facetFunctionSelectors(address(ownershipFacet));
        assertEq(ownerSels.length, ownershipSelectors.length);

        // Check UpgradeFacet selectors
        bytes4[] memory upgradeSels = getDiamondLoupe().facetFunctionSelectors(address(upgradeFacet));
        assertEq(upgradeSels.length, upgradeSelectors.length);
    }

    function test_FacetAddressesAfterInit() public view {
        address[] memory addresses = getDiamondLoupe().facetAddresses();

        // Should have 4 facet addresses
        assertEq(addresses.length, 4);

        // Verify all addresses are non-zero
        for (uint256 i = 0; i < addresses.length; i++) {
            assertTrue(addresses[i] != address(0), "Facet address is zero");
        }
    }

    function test_InterfacesSupported() public view {
        // ERC165
        assertTrue(getDiamondERC165().supportsInterface(type(IERC165).interfaceId));

        // ERC173 (Ownership)
        assertTrue(getDiamondERC165().supportsInterface(type(IERC173).interfaceId));

        // IDiamondCut
        assertTrue(getDiamondERC165().supportsInterface(type(IDiamondCut).interfaceId));

        // IDiamondLoupe
        assertTrue(getDiamondERC165().supportsInterface(type(IDiamondLoupe).interfaceId));

        // IUpgrade
        assertTrue(getDiamondERC165().supportsInterface(type(IUpgrade).interfaceId));
    }

    function test_InitialVersionIsZero() public view {
        assertEq(getDiamondUpgrade().getCurrentVersion(), 0);
    }

    function test_RevertIf_InitializeWithZeroOwner() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(cutFacet), cutSelectors);

        vm.expectRevert(abi.encodeWithSignature("Diamond_ContractOwnerIsZero()"));
        new Diamond(cuts, address(0), address(facetRegistry), address(protocolStatus));
    }

    function test_InitializeWithDifferentOwner() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](4);
        cuts[0] = createAddCut(address(cutFacet), cutSelectors);
        cuts[1] = createAddCut(address(loupeFacet), loupeSelectors);
        cuts[2] = createAddCut(address(ownershipFacet), ownershipSelectors);
        cuts[3] = createAddCut(address(upgradeFacet), upgradeSelectors);

        Diamond newDiamond = new Diamond(cuts, user1, address(facetRegistry), address(protocolStatus));

        assertEq(IERC173(address(newDiamond)).owner(), user1);
    }

    function test_InitializeWithEmptyDiamondCut() public {
        IDiamondCut.FacetCut[] memory emptyCuts = new IDiamondCut.FacetCut[](0);

        // Should succeed - diamond can be deployed with no facets initially
        // However, we cannot call any functions on it since there are no facets
        Diamond emptyDiamond = new Diamond(emptyCuts, owner, address(facetRegistry), address(protocolStatus));

        // Verify diamond was created
        assertTrue(address(emptyDiamond) != address(0));
        assertTrue(address(emptyDiamond).code.length > 0);
    }

    function test_FacetAddressLookupForSelectors() public view {
        // Test that selectors map to correct facets
        assertEq(getDiamondLoupe().facetAddress(cutSelectors[0]), address(cutFacet));
        assertEq(getDiamondLoupe().facetAddress(loupeSelectors[0]), address(loupeFacet));
        assertEq(getDiamondLoupe().facetAddress(ownershipSelectors[0]), address(ownershipFacet));
        assertEq(getDiamondLoupe().facetAddress(upgradeSelectors[0]), address(upgradeFacet));
    }

    function test_NonExistentSelectorReturnsZeroAddress() public view {
        bytes4 nonExistentSelector = bytes4(keccak256("nonExistent()"));
        assertEq(getDiamondLoupe().facetAddress(nonExistentSelector), address(0));
    }

    function test_MultipleDeployments() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](4);
        cuts[0] = createAddCut(address(cutFacet), cutSelectors);
        cuts[1] = createAddCut(address(loupeFacet), loupeSelectors);
        cuts[2] = createAddCut(address(ownershipFacet), ownershipSelectors);
        cuts[3] = createAddCut(address(upgradeFacet), upgradeSelectors);

        // Deploy multiple diamonds
        Diamond diamond1 = new Diamond(cuts, user1, address(facetRegistry), address(protocolStatus));
        Diamond diamond2 = new Diamond(cuts, user2, address(facetRegistry), address(protocolStatus));

        // Each should have its own owner
        assertEq(IERC173(address(diamond1)).owner(), user1);
        assertEq(IERC173(address(diamond2)).owner(), user2);

        // Each should be independent
        assertTrue(address(diamond1) != address(diamond2));
    }
}
