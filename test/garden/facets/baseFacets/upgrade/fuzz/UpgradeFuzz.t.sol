// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { UpgradeTestBase, ModuleFacetA2, ModuleFacetB2 } from "../UpgradeTestBase.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";
import { IDiamondLoupe } from "src/garden/facets/baseFacets/loupe/IDiamondLoupe.sol";
import { IUpgrade } from "src/garden/facets/baseFacets/upgrade/IUpgrade.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";

error UpgradeFacet_NoModuleUpgradesAvailable();
error UpgradeFacet_HashMismatch();

contract UpgradeFuzzTest is UpgradeTestBase {
    // ═══════════════════════════════════════════════════════════════
    //                  FUZZ: UPGRADE HASH INTEGRITY
    // ═══════════════════════════════════════════════════════════════

    function testFuzz_upgrade_wrongHashAlwaysReverts(bytes32 fuzzHash) public {
        address garden = _setupSingleModuleGarden();
        IUpgrade iUpgrade = _upgradeOf(garden);
        (, bytes32 correctHash) = iUpgrade.upgradeDetails();

        // Skip if fuzzer accidentally generates the correct hash
        vm.assume(fuzzHash != correctHash);

        vm.prank(gardenOwner);
        vm.expectRevert(abi.encodeWithSelector(UpgradeFacet_HashMismatch.selector));
        iUpgrade.upgrade(fuzzHash);
    }

    // ═══════════════════════════════════════════════════════════════
    //                FUZZ: VERSION SYNC CORRECTNESS
    // ═══════════════════════════════════════════════════════════════

    function testFuzz_upgrade_versionAlwaysSyncsAfterUpgrade(uint8 extraOps) public {
        uint256 ops = bound(extraOps, 0, 5);

        _registerModule(MODULE_1);
        _addFacetToModule(MODULE_1, address(modFacetA), selsModA);

        bytes32[] memory modules = new bytes32[](1);
        modules[0] = MODULE_1;
        _addGardenType(GARDEN_TYPE_1, modules);

        address garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);
        _performUpgrade(garden, gardenOwner);

        IUpgrade iUpgrade = _upgradeOf(garden);

        // Apply ops extra registry operations and upgrade each time
        for (uint256 i = 0; i < ops; i++) {
            // Alternate between add and replace to increment version
            if (i % 2 == 0) {
                _addFacetToModule(MODULE_1, address(modFacetC), selsModC);
                _performUpgrade(garden, gardenOwner);
                // Remove it so we can add it again next iteration
                _removeFacetFromModule(MODULE_1, selsModC);
                _performUpgrade(garden, gardenOwner);
            } else {
                _replaceFacetInModule(MODULE_1, address(modFacetA2), selsModA);
                _performUpgrade(garden, gardenOwner);
                _replaceFacetInModule(MODULE_1, address(modFacetA), selsModA);
                _performUpgrade(garden, gardenOwner);
            }
        }

        assertEq(
            iUpgrade.getModuleVersion(MODULE_1),
            registry.getModuleVersion(MODULE_1),
            "garden module version must always equal registry version after upgrade"
        );
    }

    // ═══════════════════════════════════════════════════════════════
    //          FUZZ: UPGRADE DETAILS HASH DETERMINISM
    // ═══════════════════════════════════════════════════════════════

    function testFuzz_upgradeDetails_hashDeterministic(uint8 callCount) public {
        uint256 calls = bound(callCount, 2, 10);

        address garden = _setupSingleModuleGarden();
        IUpgrade iUpgrade = _upgradeOf(garden);

        (, bytes32 firstHash) = iUpgrade.upgradeDetails();

        for (uint256 i = 1; i < calls; i++) {
            (, bytes32 h) = iUpgrade.upgradeDetails();
            assertEq(h, firstHash, "hash must be deterministic across calls");
        }
    }

    // ═══════════════════════════════════════════════════════════════
    //      FUZZ: MULTIPLE VERSION SKIP FOR NEW GARDEN
    // ═══════════════════════════════════════════════════════════════

    function testFuzz_upgrade_newGarden_multipleVersionSkip(uint8 numAddsBeforeReplace) public {
        uint256 n = bound(numAddsBeforeReplace, 1, 4);

        _registerModule(MODULE_1);

        // Add FacetA (version 1)
        _addFacetToModule(MODULE_1, address(modFacetA), selsModA);

        // Add extra facets
        if (n >= 2) _addFacetToModule(MODULE_1, address(modFacetC), selsModC);
        if (n >= 3) _addFacetToModule(MODULE_1, address(modFacetE), selsModE);
        if (n >= 4) _addFacetToModule(MODULE_1, address(modFacetF), selsModF);

        // Replace FacetA with FacetA2
        _replaceFacetInModule(MODULE_1, address(modFacetA2), selsModA);

        bytes32[] memory modules = new bytes32[](1);
        modules[0] = MODULE_1;
        _addGardenType(GARDEN_TYPE_1, modules);

        // Deploy fresh garden at version 0 — must handle the full history
        address garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);
        _performUpgrade(garden, gardenOwner);

        // Verify FacetA2 is installed (NOT FacetA)
        IDiamondLoupe loupe = IDiamondLoupe(garden);
        assertEq(loupe.facetAddress(selsModA[0]), address(modFacetA2), "net-state diff should resolve to FacetA2");

        // Verify extra facets are installed
        if (n >= 2) assertEq(loupe.facetAddress(selsModC[0]), address(modFacetC));
        if (n >= 3) assertEq(loupe.facetAddress(selsModE[0]), address(modFacetE));
        if (n >= 4) assertEq(loupe.facetAddress(selsModF[0]), address(modFacetF));
    }

    // ═══════════════════════════════════════════════════════════════
    //          FUZZ: DUAL MODULE UPGRADE ORDERING
    // ═══════════════════════════════════════════════════════════════

    function testFuzz_upgrade_dualModule_versionSync(bool replaceFirst) public {
        _registerModule(MODULE_1);
        _registerModule(MODULE_2);
        _addFacetToModule(MODULE_1, address(modFacetA), selsModA);
        _addFacetToModule(MODULE_2, address(modFacetB), selsModB);

        bytes32[] memory modules = new bytes32[](2);
        modules[0] = MODULE_1;
        modules[1] = MODULE_2;
        _addGardenType(GARDEN_TYPE_1, modules);

        address garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);
        _performUpgrade(garden, gardenOwner);

        // Replace in one module based on fuzz input
        if (replaceFirst) {
            _replaceFacetInModule(MODULE_1, address(modFacetA2), selsModA);
        } else {
            _replaceFacetInModule(MODULE_2, address(modFacetB2), selsModB);
        }

        _performUpgrade(garden, gardenOwner);

        IUpgrade iUpgrade = _upgradeOf(garden);
        assertEq(iUpgrade.getModuleVersion(MODULE_1), registry.getModuleVersion(MODULE_1));
        assertEq(iUpgrade.getModuleVersion(MODULE_2), registry.getModuleVersion(MODULE_2));
    }

    // ═══════════════════════════════════════════════════════════════
    //     FUZZ: NO DOUBLE UPGRADE (IDEMPOTENCY CHECK)
    // ═══════════════════════════════════════════════════════════════

    function testFuzz_upgrade_noDoubleUpgrade(uint8 upgradeCount) public {
        uint256 count = bound(upgradeCount, 1, 5);

        address garden = _setupSingleModuleGarden();
        _performUpgrade(garden, gardenOwner);

        // Subsequent upgrade attempts should revert
        for (uint256 i = 0; i < count; i++) {
            vm.expectRevert(abi.encodeWithSelector(UpgradeFacet_NoModuleUpgradesAvailable.selector));
            _upgradeOf(garden).upgradeDetails();
        }
    }

    // ═══════════════════════════════════════════════════════════════
    //     FUZZ: UPGRADE WITH MIXED ADD/REPLACE/REMOVE HISTORY
    // ═══════════════════════════════════════════════════════════════

    function testFuzz_upgrade_complexHistory_newGarden(bool doPartialReplace, bool doRemove) public {
        _registerModule(MODULE_1);
        _addFacetToModule(MODULE_1, address(modFacetA), selsModA); // v1: Add A[sel1, sel2]

        if (doPartialReplace) {
            // v2: Replace sel1 from FacetA to FacetA2
            bytes4[] memory sel1 = new bytes4[](1);
            sel1[0] = selsModA[0];
            _replaceFacetInModule(MODULE_1, address(modFacetA2), sel1);
        }

        if (doRemove && !doPartialReplace) {
            // v2: Remove sel2 from FacetA
            bytes4[] memory sel2 = new bytes4[](1);
            sel2[0] = selsModA[1];
            _removeFacetFromModule(MODULE_1, sel2);
        }

        bytes32[] memory modules = new bytes32[](1);
        modules[0] = MODULE_1;
        _addGardenType(GARDEN_TYPE_1, modules);

        address garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);

        // Check if there are actual cuts
        IUpgrade iUpgrade = _upgradeOf(garden);
        try iUpgrade.upgradeDetails() returns (IDiamondCut.FacetCut[] memory, bytes32) {
            _performUpgrade(garden, gardenOwner);

            // Verify the diamond matches the current registry state
            IFacetRegistry.Facet[] memory moduleFacets = registry.getModuleFacets(MODULE_1);
            IDiamondLoupe loupe = IDiamondLoupe(garden);
            for (uint256 facetIndex = 0; facetIndex < moduleFacets.length; facetIndex++) {
                for (
                    uint256 selectorIndex = 0;
                    selectorIndex < moduleFacets[facetIndex].functionSelectors.length;
                    selectorIndex++
                ) {
                    assertEq(
                        loupe.facetAddress(moduleFacets[facetIndex].functionSelectors[selectorIndex]),
                        moduleFacets[facetIndex].facetAddress,
                        "diamond state must match registry"
                    );
                }
            }
        } catch {
            // No upgrades available (all selectors were added then removed)
        }
    }
}
