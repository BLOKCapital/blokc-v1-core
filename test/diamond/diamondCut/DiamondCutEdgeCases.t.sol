// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { DiamondTestBase } from "../DiamondTestBase.sol";
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";
import { IDiamondLoupe } from "src/diamond/facets/baseFacets/loupe/IDiamondLoupe.sol";

/// @title DiamondCutFacetTest
/// @notice Tests for DiamondCutFacet functionality
contract DiamondCutFacetTest is DiamondTestBase {
    // Mock facet for testing
    MockFacet internal mockFacet;
    bytes4[] internal mockSelectors;

    function setUp() public override {
        super.setUp();

        // Deploy mock facet
        mockFacet = new MockFacet();

        // Setup mock selectors
        mockSelectors = new bytes4[](2);
        mockSelectors[0] = mockFacet.mockFunction1.selector;
        mockSelectors[1] = mockFacet.mockFunction2.selector;

        // Register mock facet in registry
        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), mockSelectors);
    }

    function test_AddFacet() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), mockSelectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Verify facet was added
        assertEq(getDiamondLoupe().facetAddress(mockSelectors[0]), address(mockFacet));
        assertEq(getDiamondLoupe().facetAddress(mockSelectors[1]), address(mockFacet));
    }

    function test_ReplaceFacet() public {
        // First add the facet
        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(mockFacet), mockSelectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Deploy new mock facet
        MockFacet newMockFacet = new MockFacet();

        // Register new facet
        vm.prank(owner);
        facetRegistry.replaceFunctions(address(newMockFacet), mockSelectors);

        // Replace the facet
        IDiamondCut.FacetCut[] memory replaceCuts = new IDiamondCut.FacetCut[](1);
        replaceCuts[0] = createReplaceCut(address(newMockFacet), mockSelectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(replaceCuts, address(0), "");

        // Verify facet was replaced
        assertEq(getDiamondLoupe().facetAddress(mockSelectors[0]), address(newMockFacet));
    }

    function test_RemoveFacet() public {
        // First add the facet
        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(mockFacet), mockSelectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(0), "");

        // Remove from registry first (must pass address(0) for removal)
        vm.prank(owner);
        facetRegistry.removeFunctions(address(0), mockSelectors);

        // Remove the facet
        IDiamondCut.FacetCut[] memory removeCuts = new IDiamondCut.FacetCut[](1);
        removeCuts[0] = createRemoveCut(mockSelectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(removeCuts, address(0), "");

        // Verify facet was removed
        assertEq(getDiamondLoupe().facetAddress(mockSelectors[0]), address(0));
    }

    function test_MultipleFacetCuts() public {
        // Deploy second mock facet
        MockFacet mockFacet2 = new MockFacet();
        bytes4[] memory mockSelectors2 = new bytes4[](1);
        mockSelectors2[0] = bytes4(keccak256("mockFunction3()"));

        // Register second facet
        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet2), mockSelectors2);

        // Add multiple facets in one cut
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](2);
        cuts[0] = createAddCut(address(mockFacet), mockSelectors);
        cuts[1] = createAddCut(address(mockFacet2), mockSelectors2);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Verify both facets were added
        assertEq(getDiamondLoupe().facetAddress(mockSelectors[0]), address(mockFacet));
        assertEq(getDiamondLoupe().facetAddress(mockSelectors2[0]), address(mockFacet2));
    }

    function test_RevertIf_NonOwnerCalls() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), mockSelectors);

        vm.prank(nonOwner);
        vm.expectRevert();
        getDiamondCut().diamondCut(cuts, address(0), "");
    }

    function test_RevertIf_FacetNotRegistered() public {
        // Deploy unregistered facet
        MockFacet unregisteredFacet = new MockFacet();

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(unregisteredFacet), mockSelectors);

        vm.prank(owner);
        vm.expectRevert();
        getDiamondCut().diamondCut(cuts, address(0), "");
    }

    function test_DiamondCutSucceeds() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), mockSelectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Verify facet was added
        assertEq(getDiamondLoupe().facetAddress(mockSelectors[0]), address(mockFacet));
    }

    function test_DiamondCutWithInitialization() public {
        // Deploy init contract
        InitContract initContract = new InitContract();
        bytes memory initData = abi.encodeWithSelector(InitContract.init.selector);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), mockSelectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(initContract), initData);

        // Verify facet was added
        assertEq(getDiamondLoupe().facetAddress(mockSelectors[0]), address(mockFacet));
    }
}

/// @dev Mock facet for testing
contract MockFacet {
    function mockFunction1() external pure returns (uint256) {
        return 1;
    }

    function mockFunction2() external pure returns (uint256) {
        return 2;
    }
}

/// @dev Mock initialization contract
contract InitContract {
    event Initialized();

    function init() external {
        emit Initialized();
    }
}
