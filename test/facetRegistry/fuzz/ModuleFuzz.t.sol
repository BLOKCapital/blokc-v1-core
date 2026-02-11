// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { FacetRegistryTestBase } from "../FacetRegistryTestBase.sol";
import { FacetRegistry } from "src/facetRegistry/FacetRegistry.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";

import {
    FacetRegistry_ModuleIdIsZero,
    FacetRegistry_ModuleAlreadyExists
} from "src/facetRegistry/FacetRegistry.sol";

/// @dev Minimal mock that always deploys with some code
contract FuzzMockFacet {
    uint256 private _x;
    function setX(uint256 x) external { _x = x; }
}

contract ModuleFuzzTest is FacetRegistryTestBase {
    // ─── registerModule fuzzing ─────────────────────────────────────────

    function testFuzz_registerModule_arbitraryId(bytes32 moduleId) public {
        vm.assume(moduleId != bytes32(0));
        vm.assume(moduleId != BASE_MODULE);

        registry.registerModule(moduleId);
        assertTrue(registry.isModuleRegistered(moduleId));
        assertEq(registry.getModuleVersion(moduleId), 0);
    }

    function testFuzz_registerModule_revert_zeroId(bytes32 moduleId) public {
        // Only test with zero
        moduleId = bytes32(0);
        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_ModuleIdIsZero.selector));
        registry.registerModule(moduleId);
    }

    function testFuzz_registerModule_revert_duplicate(bytes32 moduleId) public {
        vm.assume(moduleId != bytes32(0));
        vm.assume(moduleId != BASE_MODULE);

        registry.registerModule(moduleId);

        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_ModuleAlreadyExists.selector, moduleId));
        registry.registerModule(moduleId);
    }

    // ─── upgradeModule Add fuzzing ──────────────────────────────────────

    function testFuzz_addFacetToModule_versionIncrement(uint8 numAdds) public {
        numAdds = uint8(bound(numAdds, 1, 10));

        _registerModule(MODULE_1);

        uint256 versionBefore = registry.getCurrentVersion();
        uint256 moduleVersionBefore = registry.getModuleVersion(MODULE_1);

        for (uint8 i = 0; i < numAdds; i++) {
            FuzzMockFacet mock = new FuzzMockFacet();
            bytes4[] memory sels = new bytes4[](1);
            // Create unique selectors by hashing the index
            sels[0] = bytes4(keccak256(abi.encodePacked("fuzz", i)));

            // We need to construct this manually since the selector is fake
            // but the facet is a real contract
            IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
            cuts[0] = IDiamondCut.FacetCut({
                facetAddress: address(mock),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: sels
            });
            registry.upgradeModule(MODULE_1, cuts);
        }

        assertEq(registry.getCurrentVersion(), versionBefore + numAdds);
        assertEq(registry.getModuleVersion(MODULE_1), moduleVersionBefore + numAdds);
    }

    function testFuzz_addFacetToModule_facetTracking(uint8 numFacets) public {
        numFacets = uint8(bound(numFacets, 1, 8));

        _registerModule(MODULE_1);

        for (uint8 i = 0; i < numFacets; i++) {
            FuzzMockFacet mock = new FuzzMockFacet();
            bytes4[] memory sels = new bytes4[](1);
            sels[0] = bytes4(keccak256(abi.encodePacked("track", i)));

            _addFacetToModuleRaw(MODULE_1, address(mock), sels);

            assertTrue(registry.isFacetRegistered(address(mock)));
            assertEq(registry.getFacetModule(address(mock)), MODULE_1);
        }

        address[] memory addrs = registry.getModuleFacetAddresses(MODULE_1);
        assertEq(addrs.length, numFacets);

        // Global addresses = 4 base + numFacets
        address[] memory allAddrs = registry.getFacetAddresses();
        assertEq(allAddrs.length, 4 + numFacets);
    }

    // ─── upgradeModule Replace fuzzing ──────────────────────────────────

    function testFuzz_replaceFacet_selectorMapping(uint8 numSelectors) public {
        numSelectors = uint8(bound(numSelectors, 1, 5));

        _registerModule(MODULE_1);

        // Deploy original facet and add with numSelectors selectors
        FuzzMockFacet original = new FuzzMockFacet();
        bytes4[] memory sels = new bytes4[](numSelectors);
        for (uint8 i = 0; i < numSelectors; i++) {
            sels[i] = bytes4(keccak256(abi.encodePacked("replace", i)));
        }
        _addFacetToModuleRaw(MODULE_1, address(original), sels);

        // Replace with new facet
        FuzzMockFacet replacement = new FuzzMockFacet();
        _replaceFacetInModuleRaw(MODULE_1, address(replacement), sels);

        // All selectors should map to replacement
        for (uint8 i = 0; i < numSelectors; i++) {
            assertEq(registry.getFacetAddress(sels[i]), address(replacement));
        }

        // Original should be removed (no selectors)
        assertFalse(registry.isFacetRegistered(address(original)));
    }

    // ─── upgradeModule Remove fuzzing ───────────────────────────────────

    function testFuzz_removeFacet_cleansUpState(uint8 numSelectors) public {
        numSelectors = uint8(bound(numSelectors, 1, 5));

        _registerModule(MODULE_1);

        FuzzMockFacet mock = new FuzzMockFacet();
        bytes4[] memory sels = new bytes4[](numSelectors);
        for (uint8 i = 0; i < numSelectors; i++) {
            sels[i] = bytes4(keccak256(abi.encodePacked("remove", i)));
        }
        _addFacetToModuleRaw(MODULE_1, address(mock), sels);

        assertTrue(registry.isFacetRegistered(address(mock)));

        _removeFacetFromModule(MODULE_1, sels);

        assertFalse(registry.isFacetRegistered(address(mock)));
        for (uint8 i = 0; i < numSelectors; i++) {
            assertFalse(registry.isSelectorRegistered(sels[i]));
        }
        assertEq(registry.getFacetModule(address(mock)), bytes32(0));
    }

    // ─── Helpers ────────────────────────────────────────────────────────

    function _addFacetToModuleRaw(bytes32 moduleId, address facet, bytes4[] memory sels) internal {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: sels
        });
        registry.upgradeModule(moduleId, cuts);
    }

    function _replaceFacetInModuleRaw(bytes32 moduleId, address newFacet, bytes4[] memory sels) internal {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: newFacet,
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: sels
        });
        registry.upgradeModule(moduleId, cuts);
    }
}
