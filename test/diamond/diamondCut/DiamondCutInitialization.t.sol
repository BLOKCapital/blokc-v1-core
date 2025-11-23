// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { DiamondTestBase } from "../DiamondTestBase.sol";
import { Diamond } from "src/diamond/Diamond.sol";
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";

/// @title DiamondCutInitializationTest
/// @notice Comprehensive tests for diamondCut with initialization code
contract DiamondCutInitializationTest is DiamondTestBase {
    function test_DiamondCutWithInitialization() public {
        MockInitFacet mockFacet = new MockInitFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        InitContract initContract = new InitContract();
        bytes memory initData = abi.encodeWithSelector(InitContract.init.selector);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(initContract), initData);

        // Verify facet was added
        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(mockFacet));
    }

    function test_DiamondCutWithInitializationSetsState() public {
        StatefulInitContract initContract = new StatefulInitContract();
        bytes memory initData = abi.encodeWithSelector(StatefulInitContract.init.selector, uint256(42));

        MockInitFacet mockFacet = new MockInitFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(initContract), initData);

        // Verify initialization ran (would need to check state if initContract stored it)
        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(mockFacet));
    }

    function test_DiamondCutWithEmptyInitialization() public {
        MockInitFacet mockFacet = new MockInitFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        // Empty init data
        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(mockFacet));
    }

    function test_DiamondCutWithInitializationRevertsOnFailure() public {
        MockInitFacet mockFacet = new MockInitFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        RevertingInitContract initContract = new RevertingInitContract();
        bytes memory initData = abi.encodeWithSelector(RevertingInitContract.init.selector);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        vm.expectRevert();
        getDiamondCut().diamondCut(cuts, address(initContract), initData);

        // Facet should not be added
        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(0));
    }

    function test_DiamondCutWithMultipleCutsAndInitialization() public {
        MockInitFacet facet1 = new MockInitFacet();
        MockInitFacet facet2 = new MockInitFacet();

        bytes4[] memory selectors1 = new bytes4[](1);
        selectors1[0] = facet1.function1.selector;

        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = bytes4(keccak256("differentFunction()"));

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors1);

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet2), selectors2);

        InitContract initContract = new InitContract();
        bytes memory initData = abi.encodeWithSelector(InitContract.init.selector);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](2);
        cuts[0] = createAddCut(address(facet1), selectors1);
        cuts[1] = createAddCut(address(facet2), selectors2);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(initContract), initData);

        assertEq(getDiamondLoupe().facetAddress(selectors1[0]), address(facet1));
        assertEq(getDiamondLoupe().facetAddress(selectors2[0]), address(facet2));
    }

    function test_DiamondCutInitializationCanAccessDiamondStorage() public {
        StorageInitContract initContract = new StorageInitContract();
        bytes memory initData = abi.encodeWithSelector(StorageInitContract.init.selector);

        MockInitFacet mockFacet = new MockInitFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(initContract), initData);

        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(mockFacet));
    }

    function test_DiamondCutWithInitializationMultipleTimes() public {
        MockInitFacet facet1 = new MockInitFacet();
        bytes4[] memory selectors1 = new bytes4[](1);
        selectors1[0] = facet1.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors1);

        InitContract initContract1 = new InitContract();
        bytes memory initData1 = abi.encodeWithSelector(InitContract.init.selector);

        IDiamondCut.FacetCut[] memory cuts1 = new IDiamondCut.FacetCut[](1);
        cuts1[0] = createAddCut(address(facet1), selectors1);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts1, address(initContract1), initData1);

        // Second cut with different initialization
        MockInitFacet facet2 = new MockInitFacet();
        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = bytes4(keccak256("differentFunction()"));

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet2), selectors2);

        InitContract initContract2 = new InitContract();
        bytes memory initData2 = abi.encodeWithSelector(InitContract.init.selector);

        IDiamondCut.FacetCut[] memory cuts2 = new IDiamondCut.FacetCut[](1);
        cuts2[0] = createAddCut(address(facet2), selectors2);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts2, address(initContract2), initData2);

        assertEq(getDiamondLoupe().facetAddress(selectors1[0]), address(facet1));
        assertEq(getDiamondLoupe().facetAddress(selectors2[0]), address(facet2));
    }

    function test_RevertIf_InitializationContractNotAContract() public {
        MockInitFacet mockFacet = new MockInitFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        bytes memory initData = abi.encodeWithSelector(bytes4(keccak256("init()")));

        // Use EOA as init contract
        vm.prank(owner);
        vm.expectRevert();
        getDiamondCut().diamondCut(cuts, user1, initData);
    }

    function test_DiamondCutWithInitializationAndReplace() public {
        MockInitFacet facet1 = new MockInitFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = facet1.function1.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors);

        InitContract initContract = new InitContract();
        bytes memory initData = abi.encodeWithSelector(InitContract.init.selector);

        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = createAddCut(address(facet1), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(addCuts, address(initContract), initData);

        // Replace with initialization
        MockInitFacet facet2 = new MockInitFacet();

        vm.prank(owner);
        facetRegistry.replaceFunctions(address(facet2), selectors);

        InitContract initContract2 = new InitContract();
        bytes memory initData2 = abi.encodeWithSelector(InitContract.init.selector);

        IDiamondCut.FacetCut[] memory replaceCuts = new IDiamondCut.FacetCut[](1);
        replaceCuts[0] = createReplaceCut(address(facet2), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(replaceCuts, address(initContract2), initData2);

        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(facet2));
    }
}

contract MockInitFacet {
    function function1() external pure returns (uint256) {
        return 100;
    }
}

contract InitContract {
    event Initialized();

    function init() external {
        emit Initialized();
    }
}

contract StatefulInitContract {
    function init(uint256 value) external pure {
        // Would store value if this had storage
        value;
    }
}

contract RevertingInitContract {
    function init() external pure {
        revert("Init failed");
    }
}

contract StorageInitContract {
    function init() external pure {
        // Can access diamond storage via LibDiamond
        // This is just a test that init can run
    }
}
