// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { DiamondTestBase } from "./DiamondTestBase.sol";
import { Diamond } from "src/diamond/Diamond.sol";
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";
import { IDiamondLoupe } from "src/diamond/facets/baseFacets/loupe/IDiamondLoupe.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";

// Define errors for testing
error Diamond_ProtocolIsInactive();
error Diamond_UpgradesDisabled();
error Diamond_InvalidCallToDiamond(address facet, bytes4 selector);
error Diamond_SelectorNotInDiamond(address facet, bytes4 selector);
error Diamond_SelectorRemoved(address facet, bytes4 selector);
error Diamond_SelectorMoved(address facet, bytes4 selector);

/// @title DiamondFallbackErrorsTest
/// @notice Comprehensive tests for all error paths in Diamond fallback function
contract DiamondFallbackErrorsTest is DiamondTestBase {
    function test_RevertIf_ProtocolIsInactive() public {
        // Protocol starts inactive, but setUp activates it
        // So we need to deactivate it first
        vm.prank(owner);
        protocolStatus.deactivateProtocol();

        // Try to call a function on diamond - should revert
        vm.expectRevert(Diamond_ProtocolIsInactive.selector);
        getDiamondLoupe().facets();
    }

    function test_RevertIf_UpgradesDisabled_CannotCallUpgrade() public {
        // Protocol is already active from setUp, just disable upgrades
        vm.prank(owner);
        protocolStatus.disableUpgrades();

        // Try to call upgrade - should revert
        vm.prank(owner);
        vm.expectRevert(Diamond_UpgradesDisabled.selector);
        getDiamondUpgrade().upgrade(bytes32(0));
    }

    function test_UpgradesDisabled_CanCallOtherFunctions() public {
        // Protocol is already active from setUp, just disable upgrades
        vm.prank(owner);
        protocolStatus.disableUpgrades();

        // Should be able to call other functions
        IDiamondLoupe.Facet[] memory facets = getDiamondLoupe().facets();
        assertTrue(facets.length > 0);
    }

    function test_RevertIf_InvalidCallToDiamond_SelectorNotInRegistry() public {
        // Protocol is already active from setUp
        // Try to call a non-existent selector that's not in registry
        bytes4 nonExistentSelector = bytes4(keccak256("nonExistentFunction()"));

        // Verify selector is not in registry
        assertFalse(facetRegistry.isSelectorRegistered(nonExistentSelector));

        // Verify selector is not in diamond
        assertEq(getDiamondLoupe().facetAddress(nonExistentSelector), address(0));

        // Expect revert with InvalidCallToDiamond error
        vm.expectRevert(abi.encodeWithSelector(Diamond_InvalidCallToDiamond.selector, address(0), nonExistentSelector));

        // Attempt to call non-existent function - should revert
        address(diamond).call(abi.encodeWithSelector(nonExistentSelector));
    }

    function test_RevertIf_SelectorNotInDiamond_ButInRegistry() public {
        // Protocol is already active from setUp
        // Add a facet to registry but NOT to diamond
        MockErrorFacet mockFacet = new MockErrorFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.testFunction.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        // Verify selector is in registry but not in diamond
        assertTrue(facetRegistry.isSelectorRegistered(selectors[0]));
        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(0));

        // Try to call the function - selector is in registry but not in diamond
        vm.expectRevert(
            abi.encodeWithSelector(Diamond_SelectorNotInDiamond.selector, address(0), mockFacet.testFunction.selector)
        );

        // Attempt to call function that exists in registry but not diamond
        address(diamond).call(abi.encodeWithSelector(mockFacet.testFunction.selector));
    }

    function test_RevertIf_SelectorRemoved_FromRegistry() public {
        // Protocol is already active from setUp
        // Add facet to both registry and diamond
        MockErrorFacet mockFacet = new MockErrorFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mockFacet.testFunction.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(mockFacet), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(mockFacet), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Verify selector is in both registry and diamond
        assertTrue(facetRegistry.isSelectorRegistered(selectors[0]));
        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(mockFacet));

        // Remove from registry
        vm.prank(owner);
        facetRegistry.removeFunctions(address(0), selectors);

        // Verify selector is no longer in registry
        assertFalse(facetRegistry.isSelectorRegistered(selectors[0]));

        // Try to call the function - selector was removed from registry
        vm.expectRevert(
            abi.encodeWithSelector(
                Diamond_SelectorRemoved.selector, address(mockFacet), mockFacet.testFunction.selector
            )
        );

        address(diamond).call(abi.encodeWithSelector(mockFacet.testFunction.selector));
    }

    function test_RevertIf_SelectorMoved_ToDifferentFacet() public {
        // Protocol is already active from setUp
        // Add facet1 to both registry and diamond
        MockErrorFacet facet1 = new MockErrorFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = facet1.testFunction.selector;

        vm.prank(owner);
        facetRegistry.addFunctions(address(facet1), selectors);

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = createAddCut(address(facet1), selectors);

        vm.prank(owner);
        getDiamondCut().diamondCut(cuts, address(0), "");

        // Verify selector points to facet1 in both
        assertTrue(facetRegistry.isSelectorRegisteredWithFacet(address(facet1), selectors[0]));
        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(facet1));

        // Replace in registry with facet2 (selector moved to different facet)
        MockErrorFacet facet2 = new MockErrorFacet();

        vm.prank(owner);
        facetRegistry.replaceFunctions(address(facet2), selectors);

        // Verify selector now points to facet2 in registry but still facet1 in diamond
        assertTrue(facetRegistry.isSelectorRegisteredWithFacet(address(facet2), selectors[0]));
        assertFalse(facetRegistry.isSelectorRegisteredWithFacet(address(facet1), selectors[0]));
        assertEq(getDiamondLoupe().facetAddress(selectors[0]), address(facet1)); // Still facet1 in diamond

        // Try to call the function - selector moved to different facet in registry
        vm.expectRevert(
            abi.encodeWithSelector(Diamond_SelectorMoved.selector, address(facet1), facet1.testFunction.selector)
        );

        address(diamond).call(abi.encodeWithSelector(facet1.testFunction.selector));
    }

    function test_Receive_Ether() public {
        // Receive function doesn't go through fallback, so protocol status doesn't matter
        // Send ETH directly to diamond (triggers receive())
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        (bool success,) = address(diamond).call{ value: 1 ether }("");
        assertTrue(success);

        // Verify ETH was received
        assertEq(address(diamond).balance, 1 ether);
    }

    function test_Receive_Ether_WhenProtocolActive() public {
        // Receive function doesn't check protocol status
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        (bool success,) = address(diamond).call{ value: 1 ether }("");
        assertTrue(success);

        assertEq(address(diamond).balance, 1 ether);
    }
}

contract MockErrorFacet {
    function testFunction() external pure returns (uint256) {
        return 999;
    }
}
