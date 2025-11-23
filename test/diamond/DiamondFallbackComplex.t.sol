// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { DiamondTestBase } from "./DiamondTestBase.sol";
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";
import { IDiamondLoupe } from "src/diamond/facets/baseFacets/loupe/IDiamondLoupe.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";

/// @title DiamondFallbackComplexTest
/// @notice Complex scenarios and edge cases for Diamond fallback
contract DiamondFallbackComplexTest is DiamondTestBase {
    function test_Fallback_WorksAfterProtocolReactivation() public {
        // Deactivate protocol
        vm.prank(owner);
        protocolStatus.deactivateProtocol();

        // Calls should fail
        vm.expectRevert();
        getDiamondLoupe().facets();

        // Reactivate protocol
        vm.prank(owner);
        protocolStatus.activateProtocol();

        // Calls should work again
        IDiamondLoupe.Facet[] memory facets = getDiamondLoupe().facets();
        assertTrue(facets.length > 0);
    }

    function test_Fallback_WorksWithMultipleFacets() public {
        // Add multiple facets
        MockComplexFacet facet1 = new MockComplexFacet();
        MockComplexFacet facet2 = new MockComplexFacet();
        MockComplexFacet facet3 = new MockComplexFacet();

        bytes4[] memory selectors1 = new bytes4[](1);
        selectors1[0] = facet1.function1.selector;

        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = bytes4(keccak256("function2()"));

        bytes4[] memory selectors3 = new bytes4[](1);
        selectors3[0] = bytes4(keccak256("function3()"));

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors1);

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet2), selectors2);

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet3), selectors3);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](3);
        cuts[0] = createAddCut(address(facet1), selectors1);
        cuts[1] = createAddCut(address(facet2), selectors2);
        cuts[2] = createAddCut(address(facet3), selectors3);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // All functions should work
        assertEq(getDiamondLoupe().facetAddress(selectors1[0]), address(facet1));
        assertEq(getDiamondLoupe().facetAddress(selectors2[0]), address(facet2));
        assertEq(getDiamondLoupe().facetAddress(selectors3[0]), address(facet3));
    }

    function test_Fallback_ProtocolStatusTransition() public {
        // Start active
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.ACTIVE));
        getDiamondLoupe().facets(); // Should work

        // Disable upgrades
        vm.prank(owner);
        protocolStatus.disableUpgrades();
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.UPGRADES_DISABLED));
        getDiamondLoupe().facets(); // Should still work

        // Deactivate
        vm.prank(owner);
        protocolStatus.deactivateProtocol();
        assertEq(uint256(protocolStatus.getProtocolStatus()), uint256(IProtocolStatus.State.INACTIVE));

        // Should fail
        vm.expectRevert();
        getDiamondLoupe().facets();
    }

    function test_Fallback_UpgradeBlockedWhenDisabled() public {
        // Disable upgrades
        vm.prank(owner);
        protocolStatus.disableUpgrades();

        // Upgrade should be blocked
        vm.prank(owner);
        vm.expectRevert();
        getDiamondUpgrade().upgrade(bytes32(0));

        // But other functions should work
        getDiamondLoupe().facets();
        getDiamondOwnership().owner();
    }

    function test_Fallback_DelegatecallPreservesStorage() public {
        // Add a facet with storage
        TestStorageFacet storageFacet = new TestStorageFacet();
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = storageFacet.setValue.selector;
        selectors[1] = storageFacet.getValue.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(storageFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(storageFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Set value through diamond
        TestStorageFacet diamondFacet = TestStorageFacet(address(diamond));
        diamondFacet.setValue(42);

        // Get value through diamond
        uint256 value = diamondFacet.getValue();
        assertEq(value, 42);
    }

    function test_Fallback_MultipleCallsToSameFacet() public {
        // Add facet with multiple functions
        MockMultiFunctionFacet multiFacet = new MockMultiFunctionFacet();
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = multiFacet.function1.selector;
        selectors[1] = multiFacet.function2.selector;
        selectors[2] = multiFacet.function3.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(multiFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(multiFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Call all functions
        MockMultiFunctionFacet diamondFacet = MockMultiFunctionFacet(address(diamond));
        assertEq(diamondFacet.function1(), 100);
        assertEq(diamondFacet.function2(), 200);
        assertEq(diamondFacet.function3(), 300);
    }

    function test_Fallback_SelectorLookupAfterReplace() public {
        // Add facet1
        MockComplexFacet facet1 = new MockComplexFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = facet1.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(facet1), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(facet1));

        // Replace with facet2
        MockComplexFacet facet2 = new MockComplexFacet();

        vm.prank(owner);
        facetRegistry.replaceFunctions(address(facet2), selectors);

        IDiamondCut.FacetCut[] memory replaceCuts = new IDiamondCut.FacetCut[](1);
        replaceCuts[0] = createReplaceCut(address(facet2), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(replaceCuts, address(0), "");

        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(facet2));
    }

    function test_Fallback_SelectorLookupAfterRemove() public {
        // Add facet
        MockComplexFacet mockFacet = new MockComplexFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(mockFacet));

        // Remove from registry
        vm.prank(owner);
        facetRegistry.removeFunctions(address(0), selectors);

        // Remove from diamond
        IDiamondCut.FacetCut[] memory removeCuts = new IDiamondCut.FacetCut[](1);
        removeCuts[0] = createRemoveCut(selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(removeCuts, address(0), "");

        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(0));
    }
}

contract MockComplexFacet {
    function function1() external pure returns (uint256) {
        return 1000;
    }
}

contract TestStorageFacet {
    uint256 private value;

    function setValue(uint256 _value) external {
        value = _value;
    }

    function getValue() external view returns (uint256) {
        return value;
    }
}

contract MockMultiFunctionFacet {
    function function1() external pure returns (uint256) {
        return 100;
    }

    function function2() external pure returns (uint256) {
        return 200;
    }

    function function3() external pure returns (uint256) {
        return 300;
    }
}
