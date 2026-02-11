// SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

import { FacetRegistryTestBase } from "../FacetRegistryTestBase.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";

import {
    FacetRegistry_InvalidVersionRange,
    FacetRegistry_VersionOutOfBounds
} from "src/facetRegistry/FacetRegistry.sol";

/// @dev Minimal mock that always deploys with some code
contract VersionFuzzMockFacet {
    uint256 private _x;
    function setX(uint256 x) external { _x = x; }
}

contract VersioningFuzzTest is FacetRegistryTestBase {
    // ─── Global version range queries ───────────────────────────────────

    function testFuzz_getFacetCutsByVersionRange_valid(uint256 start, uint256 end) public view {
        uint256 current = registry.getCurrentVersion();
        start = bound(start, 1, current);
        end = bound(end, start, current);

        IDiamondCut.FacetCut[] memory cuts = registry.getFacetCutsByVersionRange(start, end);
        assertEq(cuts.length, end - start + 1);
    }

    function testFuzz_getFacetCutsByVersionRange_revert_startZero(uint256 end) public {
        end = bound(end, 0, type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_InvalidVersionRange.selector, 0, end));
        registry.getFacetCutsByVersionRange(0, end);
    }

    function testFuzz_getFacetCutsByVersionRange_revert_startGtEnd(uint256 start, uint256 end) public {
        uint256 current = registry.getCurrentVersion();
        start = bound(start, 2, current);
        end = bound(end, 1, start - 1);

        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_InvalidVersionRange.selector, start, end));
        registry.getFacetCutsByVersionRange(start, end);
    }

    function testFuzz_getFacetCutsByVersionRange_revert_endOutOfBounds(uint256 end) public {
        uint256 current = registry.getCurrentVersion();
        end = bound(end, current + 1, current + 100);

        vm.expectRevert(
            abi.encodeWithSelector(FacetRegistry_VersionOutOfBounds.selector, end, current)
        );
        registry.getFacetCutsByVersionRange(1, end);
    }

    // ─── Module version range queries ───────────────────────────────────

    function testFuzz_getModuleFacetCutsByVersionRange_valid(uint256 start, uint256 end) public view {
        uint256 current = registry.getModuleVersion(BASE_MODULE);
        start = bound(start, 1, current);
        end = bound(end, start, current);

        IDiamondCut.FacetCut[] memory cuts =
            registry.getModuleFacetCutsByVersionRange(BASE_MODULE, start, end);
        assertEq(cuts.length, end - start + 1);
    }

    function testFuzz_getModuleFacetCutsByVersionRange_revert_startZero(uint256 end) public {
        end = bound(end, 0, type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(FacetRegistry_InvalidVersionRange.selector, 0, end));
        registry.getModuleFacetCutsByVersionRange(BASE_MODULE, 0, end);
    }

    function testFuzz_getModuleFacetCutsByVersionRange_revert_endOutOfBounds(uint256 end) public {
        uint256 current = registry.getModuleVersion(BASE_MODULE);
        end = bound(end, current + 1, current + 100);

        vm.expectRevert(
            abi.encodeWithSelector(FacetRegistry_VersionOutOfBounds.selector, end, current)
        );
        registry.getModuleFacetCutsByVersionRange(BASE_MODULE, 1, end);
    }

    // ─── Version monotonicity ───────────────────────────────────────────

    function testFuzz_versionAlwaysIncreases(uint8 numOps) public {
        numOps = uint8(bound(numOps, 1, 15));

        _registerModule(MODULE_1);

        uint256 lastGlobalVersion = registry.getCurrentVersion();
        uint256 lastModuleVersion = registry.getModuleVersion(MODULE_1);

        for (uint8 i = 0; i < numOps; i++) {
            VersionFuzzMockFacet mock = new VersionFuzzMockFacet();
            bytes4[] memory sels = new bytes4[](1);
            sels[0] = bytes4(keccak256(abi.encodePacked("ver", i)));

            IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
            cuts[0] = IDiamondCut.FacetCut({
                facetAddress: address(mock),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: sels
            });
            registry.upgradeModule(MODULE_1, cuts);

            uint256 newGlobalVersion = registry.getCurrentVersion();
            uint256 newModuleVersion = registry.getModuleVersion(MODULE_1);

            assertGt(newGlobalVersion, lastGlobalVersion);
            assertGt(newModuleVersion, lastModuleVersion);

            lastGlobalVersion = newGlobalVersion;
            lastModuleVersion = newModuleVersion;
        }
    }

    // ─── Global and module version sync ─────────────────────────────────

    function testFuzz_globalAndModuleVersionSync(uint8 numOps) public {
        numOps = uint8(bound(numOps, 1, 10));

        _registerModule(MODULE_1);

        for (uint8 i = 0; i < numOps; i++) {
            VersionFuzzMockFacet mock = new VersionFuzzMockFacet();
            bytes4[] memory sels = new bytes4[](1);
            sels[0] = bytes4(keccak256(abi.encodePacked("sync", i)));

            IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
            cuts[0] = IDiamondCut.FacetCut({
                facetAddress: address(mock),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: sels
            });
            registry.upgradeModule(MODULE_1, cuts);
        }

        // Module version should equal numOps (started at 0)
        assertEq(registry.getModuleVersion(MODULE_1), numOps);
        // Global version should be 4 (base) + numOps
        assertEq(registry.getCurrentVersion(), 4 + numOps);
    }
}
