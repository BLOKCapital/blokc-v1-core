// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { DiamondTestBase } from "./DiamondTestBase.sol";
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";
import { IDiamondLoupe } from "src/diamond/facets/baseFacets/loupe/IDiamondLoupe.sol";

/// @title DiamondAssemblyBranchesTest
/// @notice Tests for assembly branches in Diamond fallback (delegatecall success/failure)
contract DiamondAssemblyBranchesTest is DiamondTestBase {
    function test_Delegatecall_Success_ReturnsValue() public {
        // Add facet that returns a value
        MockReturnFacet returnFacet = new MockReturnFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = returnFacet.getUint.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(returnFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(returnFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Call function - delegatecall should succeed and return value
        MockReturnFacet diamondFacet = MockReturnFacet(address(diamond));
        uint256 result = diamondFacet.getUint();
        assertEq(result, 12_345);
    }

    function test_Delegatecall_Success_ReturnsEmpty() public {
        // Add facet with functions that return nothing and return value
        MockReturnFacet returnFacet = new MockReturnFacet();
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = returnFacet.setValue.selector;
        selectors[1] = returnFacet.getUint.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(returnFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(returnFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Call function - delegatecall should succeed with empty return
        MockReturnFacet diamondFacet = MockReturnFacet(address(diamond));
        diamondFacet.setValue(999);

        // Verify value was set (through storage)
        uint256 value = diamondFacet.getUint();
        assertEq(value, 999);
    }

    function test_Delegatecall_Failure_Reverts() public {
        // Add facet that reverts
        MockRevertFacet revertFacet = new MockRevertFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = revertFacet.revertingFunction.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(revertFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(revertFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Call function - delegatecall should fail and revert
        MockRevertFacet diamondFacet = MockRevertFacet(address(diamond));
        vm.expectRevert("RevertFacet: intentional revert");
        diamondFacet.revertingFunction();
    }

    function test_Delegatecall_Failure_WithCustomError() public {
        // Add facet that reverts with custom error
        MockRevertFacet revertFacet = new MockRevertFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = revertFacet.revertingFunctionWithError.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(revertFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(revertFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Call function - delegatecall should fail with custom error
        MockRevertFacet diamondFacet = MockRevertFacet(address(diamond));
        vm.expectRevert(MockRevertFacet.CustomError.selector);
        diamondFacet.revertingFunctionWithError();
    }

    function test_Delegatecall_Failure_WithReturnData() public {
        // Test that revert data is properly propagated
        MockRevertFacet revertFacet = new MockRevertFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = revertFacet.revertingFunction.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(revertFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(revertFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // The revert should include the original error message
        MockRevertFacet diamondFacet = MockRevertFacet(address(diamond));
        vm.expectRevert("RevertFacet: intentional revert");
        diamondFacet.revertingFunction();
    }

    function test_Delegatecall_Success_MultipleReturns() public {
        // Add facet with function that returns multiple values
        MockReturnFacet returnFacet = new MockReturnFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = returnFacet.getMultiple.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(returnFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(returnFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Call function - should return multiple values
        MockReturnFacet diamondFacet = MockReturnFacet(address(diamond));
        (uint256 a, uint256 b, bool c) = diamondFacet.getMultiple();
        assertEq(a, 100);
        assertEq(b, 200);
        assertTrue(c);
    }

    function test_Delegatecall_Success_WithParameters() public {
        // Add facet with function that takes parameters
        MockReturnFacet returnFacet = new MockReturnFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = returnFacet.add.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(returnFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(returnFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Call function with parameters
        MockReturnFacet diamondFacet = MockReturnFacet(address(diamond));
        uint256 result = diamondFacet.add(10, 20);
        assertEq(result, 30);
    }
}

contract MockReturnFacet {
    uint256 private value;

    function getUint() external view returns (uint256) {
        return value == 0 ? 12_345 : value;
    }

    function setValue(uint256 _value) external {
        value = _value;
    }

    function getMultiple() external pure returns (uint256, uint256, bool) {
        return (100, 200, true);
    }

    function add(uint256 a, uint256 b) external pure returns (uint256) {
        return a + b;
    }
}

contract MockRevertFacet {
    error CustomError();

    function revertingFunction() external pure {
        revert("RevertFacet: intentional revert");
    }

    function revertingFunctionWithError() external pure {
        revert CustomError();
    }
}
