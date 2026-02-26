// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { Test } from "forge-std/Test.sol";
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { FacetRegistryHandler } from "./FacetRegistryHandler.sol";
import { FacetRegistryTestBase, MockFacetA, MockFacetB, MockFacetC, MockFacetD } from "../FacetRegistryTestBase.sol";

contract FacetRegistryInvariantTest is FacetRegistryTestBase {
    FacetRegistryHandler public handler;

    bytes32 public constant HANDLER_BASE_MODULE = keccak256("BASE");

    function setUp() public override {
        super.setUp();
        handler = new FacetRegistryHandler(registry);

        // Transfer ownership to handler so it can perform operations
        registry.transferOwnership(address(handler));

        targetContract(address(handler));
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                           INVARIANTS
    // ═══════════════════════════════════════════════════════════════════════

    /// @dev BASE_MODULE must always exist with exactly 4 facets and 8 selectors
    function invariant_baseModuleAlwaysExists() public view {
        assertTrue(registry.isModuleRegistered(HANDLER_BASE_MODULE));

        address[] memory baseFacetAddrs = registry.getModuleFacetAddresses(HANDLER_BASE_MODULE);
        assertEq(baseFacetAddrs.length, 4);

        // Each base facet should have 2 selectors
        for (uint256 i = 0; i < baseFacetAddrs.length; i++) {
            bytes4[] memory sels = registry.getFacetFunctionSelectors(baseFacetAddrs[i]);
            assertEq(sels.length, 2);
        }
    }

    /// @dev Base facets are immutable - always the same addresses
    function invariant_baseFacetsImmutable() public view {
        address[4] memory baseFacets = registry.getBaseFacets();
        assertEq(baseFacets[0], address(facetA));
        assertEq(baseFacets[1], address(facetB));
        assertEq(baseFacets[2], address(facetC));
        assertEq(baseFacets[3], address(facetD));
    }

    /// @dev Base facets must always belong to BASE_MODULE
    function invariant_baseFacetsBelongToBaseModule() public view {
        address[4] memory baseFacets = registry.getBaseFacets();
        for (uint256 i = 0; i < 4; i++) {
            assertEq(registry.getFacetModule(baseFacets[i]), HANDLER_BASE_MODULE);
        }
    }

    /// @dev Global version must never decrease
    function invariant_versionNeverDecreases() public view {
        // Version starts at 4 (from constructor) and only increases
        assertGe(registry.getCurrentVersion(), 4);
    }

    /// @dev BASE_MODULE version must never decrease below 4
    function invariant_baseModuleVersionNeverDecreases() public view {
        assertGe(registry.getModuleVersion(HANDLER_BASE_MODULE), 4);
    }

    /// @dev Every registered facet must have at least one selector
    function invariant_registeredFacetsHaveSelectors() public view {
        address[] memory allFacets = registry.getFacetAddresses();
        for (uint256 i = 0; i < allFacets.length; i++) {
            bytes4[] memory sels = registry.getFacetFunctionSelectors(allFacets[i]);
            assertGt(sels.length, 0, "Registered facet must have selectors");
        }
    }

    /// @dev Every selector must map to a registered facet
    function invariant_selectorsMapToRegisteredFacets() public view {
        IFacetRegistry.Facet[] memory facets = registry.getFacets();
        for (uint256 i = 0; i < facets.length; i++) {
            for (uint256 j = 0; j < facets[i].functionSelectors.length; j++) {
                bytes4 sel = facets[i].functionSelectors[j];
                address mapped = registry.getFacetAddress(sel);
                assertEq(mapped, facets[i].facetAddress, "Selector must map to its facet");
            }
        }
    }

    /// @dev Module IDs array must always include BASE_MODULE as first entry
    function invariant_baseModuleAlwaysFirst() public view {
        bytes32[] memory moduleIds = registry.getAllModuleIds();
        assertGe(moduleIds.length, 1);
        assertEq(moduleIds[0], HANDLER_BASE_MODULE);
    }

    /// @dev The number of registered facets in getFacets must equal getFacetAddresses length
    function invariant_facetCountConsistency() public view {
        IFacetRegistry.Facet[] memory facets = registry.getFacets();
        address[] memory addrs = registry.getFacetAddresses();
        assertEq(facets.length, addrs.length, "Facet count mismatch");
    }

    /// @dev Each facet appears exactly once in the global facet addresses
    function invariant_noFacetDuplicates() public view {
        address[] memory addrs = registry.getFacetAddresses();
        for (uint256 i = 0; i < addrs.length; i++) {
            for (uint256 j = i + 1; j < addrs.length; j++) {
                assertTrue(addrs[i] != addrs[j], "Duplicate facet in global addresses");
            }
        }
    }

    /// @dev All base selectors must always be registered
    function invariant_baseSelectorsAlwaysRegistered() public view {
        assertTrue(registry.isSelectorRegistered(MockFacetA.funcA1.selector));
        assertTrue(registry.isSelectorRegistered(MockFacetA.funcA2.selector));
        assertTrue(registry.isSelectorRegistered(MockFacetB.funcB1.selector));
        assertTrue(registry.isSelectorRegistered(MockFacetB.funcB2.selector));
        assertTrue(registry.isSelectorRegistered(MockFacetC.funcC1.selector));
        assertTrue(registry.isSelectorRegistered(MockFacetC.funcC2.selector));
        assertTrue(registry.isSelectorRegistered(MockFacetD.funcD1.selector));
        assertTrue(registry.isSelectorRegistered(MockFacetD.funcD2.selector));
    }

    /// @dev Global facet addresses length must always be >= 4 (base facets)
    function invariant_minimumFourFacets() public view {
        address[] memory addrs = registry.getFacetAddresses();
        assertGe(addrs.length, 4, "Must have at least 4 base facets");
    }

    /// @dev Registry owner must be the handler (we transferred)
    function invariant_ownerIsHandler() public view {
        assertEq(registry.owner(), address(handler));
    }
}
