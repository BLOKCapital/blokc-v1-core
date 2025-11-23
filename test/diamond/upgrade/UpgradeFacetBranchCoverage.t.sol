// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { DiamondTestBase } from "../DiamondTestBase.sol";
import { IUpgrade } from "src/diamond/facets/baseFacets/upgrade/IUpgrade.sol";
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";
import { IDiamondLoupe } from "src/diamond/facets/baseFacets/loupe/IDiamondLoupe.sol";

/// @title UpgradeFacetBranchCoverageTest
/// @notice Tests to cover missing branches in UpgradeFacet
contract UpgradeFacetBranchCoverageTest is DiamondTestBase {
    function _prepareUpgrade()
        internal
        view
        returns (IDiamondCut.FacetCut[] memory cuts, uint256 diamondVersion, uint256 registryVersion, bytes32 hashData)
    {
        return getDiamondUpgrade().upgradeDetails();
    }

    function _upgradeWithCurrentPlan() internal {
        (IDiamondCut.FacetCut[] memory cuts, uint256 diamondVersion, uint256 registryVersion, bytes32 hashData) =
            _prepareUpgrade();

        bytes32 expectedHash = keccak256(abi.encode(cuts, diamondVersion, registryVersion));
        assertEq(hashData, expectedHash);

        vm.prank(owner);
        getDiamondUpgrade().upgrade(hashData);
    }

    function test_Upgrade_NoChanges_EmptyFacetCuts() public {
        // When registry and diamond are in sync, upgrade should revert
        uint256 currentVersion = getDiamondUpgrade().getCurrentVersion();
        uint256 registryVersion = facetRegistry.getCurrentVersion();

        assertEq(currentVersion, registryVersion);

        // Upgrade should revert with no changes
        vm.prank(owner);
        vm.expectRevert();
        getDiamondUpgrade().upgrade(bytes32(0));
    }

    function test_Upgrade_WithAddOnly() public {
        // Add facet to registry only
        MockUpgradeBranchFacet mockFacet = new MockUpgradeBranchFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        // Upgrade should add the facet
        _upgradeWithCurrentPlan();

        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(mockFacet));
    }

    function test_Upgrade_WithReplaceOnly() public {
        // Add facet to diamond first
        MockUpgradeBranchFacet facet1 = new MockUpgradeBranchFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = facet1.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(facet1), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Replace in registry
        MockUpgradeBranchFacet facet2 = new MockUpgradeBranchFacet();
        vm.prank(owner);
        facetRegistry.replaceFunctions(address(facet2), selectors);

        // Upgrade should replace the facet
        _upgradeWithCurrentPlan();

        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(facet2));
    }

    function test_Upgrade_WithRemoveOnly() public {
        // Add facet to diamond first
        MockUpgradeBranchFacet mockFacet = new MockUpgradeBranchFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Remove from registry
        vm.prank(owner);
        facetRegistry.removeFunctions(address(0), selectors);

        // Upgrade should remove the facet
        _upgradeWithCurrentPlan();

        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(0));
    }

    function test_Upgrade_WithAddAndReplace() public {
        // Add facet1 to diamond
        MockUpgradeBranchFacet facet1 = new MockUpgradeBranchFacet();
        bytes4[] memory selectors1 = new bytes4[](1);
        selectors1[0] = facet1.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors1);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(facet1), selectors1);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Replace facet1 and add facet2 in registry
        MockUpgradeBranchFacet facet2 = new MockUpgradeBranchFacet();
        vm.prank(owner);
        facetRegistry.replaceFunctions(address(facet2), selectors1);

        MockUpgradeBranchFacet facet3 = new MockUpgradeBranchFacet();
        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = bytes4(keccak256("function2()"));

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet3), selectors2);

        // Upgrade should do both replace and add
        _upgradeWithCurrentPlan();

        assertEq(getDiamondLoupe().facetAddress(selectors1[0]), address(facet2));
        assertEq(getDiamondLoupe().facetAddress(selectors2[0]), address(facet3));
    }

    function test_Upgrade_WithReplaceAndRemove() public {
        // Add two facets to diamond
        MockUpgradeBranchFacet facet1 = new MockUpgradeBranchFacet();
        MockUpgradeBranchFacet facet2 = new MockUpgradeBranchFacet();

        bytes4[] memory selectors1 = new bytes4[](1);
        selectors1[0] = facet1.function1.selector;

        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = bytes4(keccak256("function2()"));

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors1);

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet2), selectors2);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](2);
        addCuts[0] = createAddCut(address(facet1), selectors1);
        addCuts[1] = createAddCut(address(facet2), selectors2);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Replace facet1 and remove facet2 in registry
        MockUpgradeBranchFacet facet3 = new MockUpgradeBranchFacet();
        vm.prank(owner);
        facetRegistry.replaceFunctions(address(facet3), selectors1);

        vm.prank(owner);
        facetRegistry.removeFunctions(address(0), selectors2);

        // Upgrade should do both replace and remove
        _upgradeWithCurrentPlan();

        assertEq(getDiamondLoupe().facetAddress(selectors1[0]), address(facet3));
        assertEq(getDiamondLoupe().facetAddress(selectors2[0]), address(0));
    }

    function test_Upgrade_WithAddAndRemove() public {
        // Add facet1 to diamond
        MockUpgradeBranchFacet facet1 = new MockUpgradeBranchFacet();
        bytes4[] memory selectors1 = new bytes4[](1);
        selectors1[0] = facet1.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors1);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(facet1), selectors1);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Remove facet1 and add facet2 in registry
        vm.prank(owner);
        facetRegistry.removeFunctions(address(0), selectors1);

        MockUpgradeBranchFacet facet2 = new MockUpgradeBranchFacet();
        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = bytes4(keccak256("function2()"));

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet2), selectors2);

        // Upgrade should do both remove and add
        _upgradeWithCurrentPlan();

        assertEq(getDiamondLoupe().facetAddress(selectors1[0]), address(0));
        assertEq(getDiamondLoupe().facetAddress(selectors2[0]), address(facet2));
    }

    function test_Upgrade_WithAllOperations() public {
        // Add two facets to diamond
        MockUpgradeBranchFacet facet1 = new MockUpgradeBranchFacet();
        MockUpgradeBranchFacet facet2 = new MockUpgradeBranchFacet();

        bytes4[] memory selectors1 = new bytes4[](1);
        selectors1[0] = facet1.function1.selector;

        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = bytes4(keccak256("function2()"));

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors1);

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet2), selectors2);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](2);
        addCuts[0] = createAddCut(address(facet1), selectors1);
        addCuts[1] = createAddCut(address(facet2), selectors2);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Replace facet1, remove facet2, and add facet3 in registry
        MockUpgradeBranchFacet facet3 = new MockUpgradeBranchFacet();
        vm.prank(owner);
        facetRegistry.replaceFunctions(address(facet3), selectors1);

        vm.prank(owner);
        facetRegistry.removeFunctions(address(0), selectors2);

        MockUpgradeBranchFacet facet4 = new MockUpgradeBranchFacet();
        bytes4[] memory selectors3 = new bytes4[](1);
        selectors3[0] = bytes4(keccak256("function3()"));

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet4), selectors3);

        // Upgrade should do replace, remove, and add
        _upgradeWithCurrentPlan();

        assertEq(getDiamondLoupe().facetAddress(selectors1[0]), address(facet3));
        assertEq(getDiamondLoupe().facetAddress(selectors2[0]), address(0));
        assertEq(getDiamondLoupe().facetAddress(selectors3[0]), address(facet4));
    }

    function test_Upgrade_WithMultipleFacetsSameOperation() public {
        // Add multiple facets, then replace multiple in registry
        MockUpgradeBranchFacet facet1 = new MockUpgradeBranchFacet();
        MockUpgradeBranchFacet facet2 = new MockUpgradeBranchFacet();

        bytes4[] memory selectors1 = new bytes4[](1);
        selectors1[0] = facet1.function1.selector;

        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = bytes4(keccak256("function2()"));

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors1);

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet2), selectors2);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](2);
        addCuts[0] = createAddCut(address(facet1), selectors1);
        addCuts[1] = createAddCut(address(facet2), selectors2);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Replace both with new facets
        MockUpgradeBranchFacet facet3 = new MockUpgradeBranchFacet();
        MockUpgradeBranchFacet facet4 = new MockUpgradeBranchFacet();

        vm.prank(owner);
        facetRegistry.replaceFunctions(address(facet3), selectors1);

        vm.prank(owner);
        facetRegistry.replaceFunctions(address(facet4), selectors2);

        // Upgrade should replace both
        _upgradeWithCurrentPlan();

        assertEq(getDiamondLoupe().facetAddress(selectors1[0]), address(facet3));
        assertEq(getDiamondLoupe().facetAddress(selectors2[0]), address(facet4));
    }

    function test_UpgradeDetails_WithComplexState() public {
        // Setup complex state with multiple facets
        MockUpgradeBranchFacet facet1 = new MockUpgradeBranchFacet();
        MockUpgradeBranchFacet facet2 = new MockUpgradeBranchFacet();

        bytes4[] memory selectors1 = new bytes4[](1);
        selectors1[0] = facet1.function1.selector;

        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = bytes4(keccak256("function2()"));

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors1);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(facet1), selectors1);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Add to registry but not diamond
        vm.prank(owner);
        facetRegistry.addFunctions(address(facet2), selectors2);

        // Get upgrade details
        (IDiamondCut.FacetCut[] memory cuts, uint256 diamondVersion, uint256 registryVersion, bytes32 hashData) =
            _prepareUpgrade();

        // Verify details
        assertTrue(cuts.length > 0);
        assertEq(diamondVersion, getDiamondUpgrade().getCurrentVersion());
        assertEq(registryVersion, facetRegistry.getCurrentVersion());
        assertTrue(hashData != bytes32(0));

        // Verify hash matches
        bytes32 computedHash = keccak256(abi.encode(cuts, diamondVersion, registryVersion));
        assertEq(hashData, computedHash);
    }
}

contract MockUpgradeBranchFacet {
    function function1() external pure returns (uint256) {
        return 8888;
    }
}
