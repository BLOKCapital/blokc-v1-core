// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { DiamondTestBase } from "./DiamondTestBase.sol";
import { Diamond } from "src/diamond/Diamond.sol";
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";
import { IDiamondLoupe } from "src/diamond/facets/baseFacets/loupe/IDiamondLoupe.sol";
import { IERC165 } from "src/interfaces/IERC165.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";
import { IUpgrade } from "src/diamond/facets/baseFacets/upgrade/IUpgrade.sol";

/// @title DiamondIntegrationTest
/// @notice Integration tests for Diamond with all facets working together
contract DiamondIntegrationTest is DiamondTestBase {
    function test_Integration_CompleteWorkflow() public {
        // 1. Verify initial state
        assertEq(getDiamondOwnership().owner(), owner);
        assertEq(getDiamondUpgrade().getCurrentVersion(), 0);

        // 2. Add a custom facet to registry (but not to diamond yet)
        IntegrationFacet customFacet = new IntegrationFacet();
        bytes4[] memory customSelectors = new bytes4[](1);
        customSelectors[0] = customFacet.customFunction.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(customFacet), customSelectors);

        // 3. Verify facet is NOT in diamond yet
        assertEq(getDiamondLoupe().facetAddress(customSelectors[0]), address(0));

        // 4. Upgrade to sync diamond with registry (this will add the facet)
        uint256 registryVersion = facetRegistry.getCurrentVersion();
        vm.prank(owner);
        getDiamondUpgrade().upgrade(bytes32(0));

        // 5. Verify version updated
        assertEq(getDiamondUpgrade().getCurrentVersion(), registryVersion);

        // 6. Verify facet was added via loupe
        assertEq(getDiamondLoupe().facetAddress(customSelectors[0]), address(customFacet));

        // 7. Call the custom function
        IntegrationFacet diamondAsCustom = IntegrationFacet(address(diamond));
        assertEq(diamondAsCustom.customFunction(), 1234);
    }

    function test_Integration_OwnershipAndAccess() public {
        // Only owner can perform owner actions
        IntegrationFacet customFacet = new IntegrationFacet();
        bytes4[] memory customSelectors = new bytes4[](1);
        customSelectors[0] = customFacet.customFunction.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(customFacet), customSelectors);

        // Non-owner cannot add facets
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(customFacet), customSelectors);

        vm.prank(nonOwner);
        vm.expectRevert();
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Transfer ownership
        vm.prank(owner);
        getDiamondOwnership().transferOwnership(user1);

        // New owner can add facets
        vm.prank(user1);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Verify facet was added
        assertEq(getDiamondLoupe().facetAddress(customSelectors[0]), address(customFacet));
    }

    function test_Integration_MultipleUsers() public {
        // Deploy multiple diamonds for different users
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](4);
        cuts[0] = createAddCut(address(cutFacet), cutSelectors);
        cuts[1] = createAddCut(address(loupeFacet), loupeSelectors);
        cuts[2] = createAddCut(address(ownershipFacet), ownershipSelectors);
        cuts[3] = createAddCut(address(upgradeFacet), upgradeSelectors);

        Diamond diamond1 = new Diamond(cuts, user1, address(facetRegistry), address(protocolStatus));
        Diamond diamond2 = new Diamond(cuts, user2, address(facetRegistry), address(protocolStatus));

        // Each diamond has its own owner
        assertEq(IERC173(address(diamond1)).owner(), user1);
        assertEq(IERC173(address(diamond2)).owner(), user2);

        // Each diamond is independent
        assertTrue(address(diamond1) != address(diamond2));
    }

    function test_Integration_FacetReplacementWorkflow() public {
        // 1. Add initial facet
        IntegrationFacet facet1 = new IntegrationFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = facet1.customFunction.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(facet1), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // 2. Replace with new facet
        IntegrationFacet facet2 = new IntegrationFacet();

        vm.prank(owner);
        facetRegistry.replaceFunctions(address(facet2), selectors);

        IDiamondCut.FacetCut[] memory replaceCuts = new IDiamondCut.FacetCut[](1);
        replaceCuts[0] = createReplaceCut(address(facet2), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(replaceCuts, address(0), "");

        // 3. Verify replacement via loupe
        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(facet2));
    }

    function test_Integration_AllInterfacesSupported() public view {
        // Verify all required interfaces are supported
        assertTrue(IERC165(address(diamond)).supportsInterface(type(IERC165).interfaceId));
        assertTrue(IERC165(address(diamond)).supportsInterface(type(IERC173).interfaceId));
        assertTrue(IERC165(address(diamond)).supportsInterface(type(IDiamondCut).interfaceId));
        assertTrue(IERC165(address(diamond)).supportsInterface(type(IDiamondLoupe).interfaceId));
        assertTrue(IERC165(address(diamond)).supportsInterface(type(IUpgrade).interfaceId));
    }

    function test_Integration_ProtocolStatusIntegration() public {
        // Deploy facet
        IntegrationFacet customFacet = new IntegrationFacet();
        bytes4[] memory customSelectors = new bytes4[](1);
        customSelectors[0] = customFacet.customFunction.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(customFacet), customSelectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(customFacet), customSelectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Functions work when protocol is active
        IntegrationFacet diamondAsCustom = IntegrationFacet(address(diamond));
        assertEq(diamondAsCustom.customFunction(), 1234);

        // Deactivate protocol
        vm.prank(owner);
        protocolStatus.deactivateProtocol();

        // Functions should revert
        vm.expectRevert();
        diamondAsCustom.customFunction();

        // Reactivate
        vm.prank(owner);
        protocolStatus.activateProtocol();

        // Functions work again
        assertEq(diamondAsCustom.customFunction(), 1234);
    }

    function test_Integration_UpgradeDisabledState() public {
        // Disable upgrades
        vm.prank(owner);
        protocolStatus.disableUpgrades();

        // Regular functions should work
        IntegrationFacet customFacet = new IntegrationFacet();
        bytes4[] memory customSelectors = new bytes4[](1);
        customSelectors[0] = customFacet.customFunction.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(customFacet), customSelectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(customFacet), customSelectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        IntegrationFacet diamondAsCustom = IntegrationFacet(address(diamond));
        assertEq(diamondAsCustom.customFunction(), 1234);

        // But upgrade should fail
        vm.prank(owner);
        vm.expectRevert();
        getDiamondUpgrade().upgrade(bytes32(0));
    }

    function test_Integration_LargeNumberOfFacets() public {
        // Add 10 custom facets
        for (uint256 i = 0; i < 10; i++) {
            IntegrationFacet customFacet = new IntegrationFacet();
            bytes4[] memory customSelectors = new bytes4[](1);
            customSelectors[0] = bytes4(keccak256(abi.encodePacked("custom", i)));

            vm.prank(owner);
            facetRegistry.addFunctions(address(customFacet), customSelectors);

            IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
            cuts[0] = createAddCut(address(customFacet), customSelectors);

            vm.prank(owner);
            getDiamondCut().diamondCut(cuts, address(0), "");
        }

        // Should have 4 base + 10 custom = 14 facets
        address[] memory addresses = getDiamondLoupe().facetAddresses();
        assertEq(addresses.length, 14);
    }

    function test_Integration_StatePersistsAcrossOperations() public {
        // Add stateful facet
        StatefulFacet statefulFacet = new StatefulFacet();
        bytes4[] memory statefulSelectors = new bytes4[](2);
        statefulSelectors[0] = statefulFacet.store.selector;
        statefulSelectors[1] = statefulFacet.retrieve.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(statefulFacet), statefulSelectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(statefulFacet), statefulSelectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Store a value
        StatefulFacet diamondAsStateful = StatefulFacet(address(diamond));
        diamondAsStateful.store(42);

        // Retrieve value
        assertEq(diamondAsStateful.retrieve(), 42);

        // Transfer ownership
        vm.prank(owner);
        getDiamondOwnership().transferOwnership(user1);

        // Value should still be there
        assertEq(diamondAsStateful.retrieve(), 42);
    }
}

contract IntegrationFacet {
    function customFunction() external pure returns (uint256) {
        return 1234;
    }
}

contract StatefulFacet {
    uint256 private value;

    function store(uint256 _value) external {
        value = _value;
    }

    function retrieve() external view returns (uint256) {
        return value;
    }
}
