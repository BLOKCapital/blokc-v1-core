// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { DiamondTestBase } from "../DiamondTestBase.sol";
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";

/// @title DiamondFallbackTest
/// @notice Tests for Diamond fallback mechanism and function delegation
contract DiamondFallbackTest is DiamondTestBase {
    TestFacet internal testFacet;
    bytes4[] internal testSelectors;

    function setUp() public override {
        super.setUp();

        // Deploy test facet
        testFacet = new TestFacet();

        // Setup selectors
        testSelectors = new bytes4[](3);
        testSelectors[0] = testFacet.getValue.selector;
        testSelectors[1] = testFacet.setValue.selector;
        testSelectors[2] = testFacet.getSum.selector;

        // Register and add to diamond
        vm.prank(owner);
        facetRegistry.addFunctions(address(testFacet), testSelectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(testFacet), testSelectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");
    }

    function test_Fallback_DelegatesToFacet() public {
        // Call function through diamond
        TestFacet diamondAsTestFacet = TestFacet(address(diamond));

        // Note: With delegatecall, storage is in the diamond, not the facet
        // So we need to initialize the value first
        diamondAsTestFacet.setValue(42);
        uint256 value = diamondAsTestFacet.getValue();
        assertEq(value, 42);
    }

    function test_Fallback_StateChanges() public {
        TestFacet diamondAsTestFacet = TestFacet(address(diamond));

        // Set a value
        diamondAsTestFacet.setValue(100);

        // Get the value
        assertEq(diamondAsTestFacet.getValue(), 100);
    }

    function test_Fallback_WithParameters() public {
        TestFacet diamondAsTestFacet = TestFacet(address(diamond));

        uint256 sum = diamondAsTestFacet.getSum(10, 20);
        assertEq(sum, 30);
    }

    function test_Fallback_MultipleCallsToSameFacet() public {
        TestFacet diamondAsTestFacet = TestFacet(address(diamond));

        diamondAsTestFacet.setValue(50);
        assertEq(diamondAsTestFacet.getValue(), 50);

        diamondAsTestFacet.setValue(75);
        assertEq(diamondAsTestFacet.getValue(), 75);
    }

    function test_RevertIf_CallNonExistentSelector() public {
        // Try to call a non-existent function
        (bool success,) = address(diamond).call(abi.encodeWithSignature("nonExistent()"));
        assertFalse(success);
    }

    function test_Fallback_WorksWithDifferentFacets() public {
        // Already have testFacet, add another
        AnotherTestFacet anotherFacet = new AnotherTestFacet();
        bytes4[] memory anotherSelectors = new bytes4[](1);
        anotherSelectors[0] = anotherFacet.anotherFunction.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(anotherFacet), anotherSelectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(anotherFacet), anotherSelectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Call both facets
        TestFacet diamondAsTestFacet = TestFacet(address(diamond));
        AnotherTestFacet diamondAsAnotherFacet = AnotherTestFacet(address(diamond));

        // Initialize value first (delegatecall uses diamond storage)
        diamondAsTestFacet.setValue(42);
        assertEq(diamondAsTestFacet.getValue(), 42);
        assertEq(diamondAsAnotherFacet.anotherFunction(), 999);
    }

    function test_RevertIf_ProtocolInactive() public {
        // Deactivate protocol
        vm.prank(owner);
        protocolStatus.deactivateProtocol();

        // Try to call function
        TestFacet diamondAsTestFacet = TestFacet(address(diamond));

        vm.expectRevert();
        diamondAsTestFacet.getValue();
    }

    function test_Fallback_WorksAfterProtocolReactivation() public {
        // Initialize value first
        TestFacet diamondAsTestFacet = TestFacet(address(diamond));
        diamondAsTestFacet.setValue(42);

        // Deactivate and reactivate
        vm.prank(owner);
        protocolStatus.deactivateProtocol();

        vm.prank(owner);
        protocolStatus.activateProtocol();

        // Should work now and value should persist
        assertEq(diamondAsTestFacet.getValue(), 42);
    }

    function test_Fallback_RegistryValidation() public {
        // Remove function from registry but not from diamond
        vm.prank(owner);
        facetRegistry.removeFunctions(address(0), testSelectors);

        // Call should fail due to registry validation
        TestFacet diamondAsTestFacet = TestFacet(address(diamond));

        vm.expectRevert();
        diamondAsTestFacet.getValue();
    }

    function test_Fallback_ReceivesETH() public {
        // Send ETH to diamond
        (bool success,) = payable(address(diamond)).call{ value: 1 ether }("");
        assertTrue(success);
        assertEq(address(diamond).balance, 1 ether);
    }
}

contract TestFacet {
    uint256 private value = 42;

    function getValue() external view returns (uint256) {
        return value;
    }

    function setValue(uint256 _value) external {
        value = _value;
    }

    function getSum(uint256 a, uint256 b) external pure returns (uint256) {
        return a + b;
    }
}

contract AnotherTestFacet {
    function anotherFunction() external pure returns (uint256) {
        return 999;
    }
}
