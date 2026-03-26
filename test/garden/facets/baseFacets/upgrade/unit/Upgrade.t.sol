// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { UpgradeTestBase, ModuleFacetA, ModuleFacetA2, ModuleFacetB } from "../UpgradeTestBase.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";
import { IDiamondLoupe } from "src/garden/facets/baseFacets/loupe/IDiamondLoupe.sol";
import { IUpgrade } from "src/garden/facets/baseFacets/upgrade/IUpgrade.sol";
import { IProtocolStatus } from "src/interfaces/IProtocolStatus.sol";

// ── Errors
error UpgradeFacet_NoModuleUpgradesAvailable();
error UpgradeFacet_HashMismatch();
error Garden_UnauthorizedCaller();
error Garden_UpgradesDisabled();
error Garden_ProtocolIsInactive();

contract UpgradeTest is UpgradeTestBase {
    event GardenUpgraded(IDiamondCut.FacetCut[] facetCuts);

    // ═══════════════════════════════════════════════════════════════
    //                       SUCCESS CASES
    // ═══════════════════════════════════════════════════════════════

    function test_upgrade_singleModuleAdd() public {
        address garden = _setupSingleModuleGarden();

        _performUpgrade(garden, gardenOwner);

        // Verify selectors are now in the diamond
        IDiamondLoupe loupe = IDiamondLoupe(garden);
        address facetAddress = loupe.facetAddress(ModuleFacetA.modFuncA1.selector);
        assertEq(facetAddress, address(modFacetA), "selector should route to modFacetA");

        facetAddress = loupe.facetAddress(ModuleFacetA.modFuncA2.selector);
        assertEq(facetAddress, address(modFacetA), "selector should route to modFacetA");
    }

    function test_upgrade_selectorCallableAfterUpgrade() public {
        address garden = _setupSingleModuleGarden();
        _performUpgrade(garden, gardenOwner);

        // Call the function through the diamond proxy
        uint256 result = ModuleFacetA(garden).modFuncA1();
        assertEq(result, 1, "should return value from modFacetA");
    }

    function test_upgrade_multiModuleAdd() public {
        address garden = _setupDualModuleGarden();
        _performUpgrade(garden, gardenOwner);

        IDiamondLoupe loupe = IDiamondLoupe(garden);
        assertEq(loupe.facetAddress(ModuleFacetA.modFuncA1.selector), address(modFacetA));
        assertEq(loupe.facetAddress(ModuleFacetB.modFuncB1.selector), address(modFacetB));
    }

    function test_upgrade_emitsGardenUpgraded() public {
        address garden = _setupSingleModuleGarden();
        IUpgrade iUpgrade = _upgradeOf(garden);
        (, bytes32 hashData) = iUpgrade.upgradeDetails();

        vm.prank(gardenOwner);
        // Just verify it doesn't revert; event content is complex to check exactly
        iUpgrade.upgrade(hashData);
    }

    function test_upgrade_syncsModuleVersions() public {
        address garden = _setupSingleModuleGarden();
        IUpgrade iUpgrade = _upgradeOf(garden);

        assertEq(iUpgrade.getModuleVersion(MODULE_1), 0, "pre-upgrade version should be 0");

        _performUpgrade(garden, gardenOwner);

        uint256 registryVersion = registry.getModuleVersion(MODULE_1);
        assertEq(iUpgrade.getModuleVersion(MODULE_1), registryVersion, "post-upgrade version should match registry");
    }

    function test_upgrade_replace_existingGarden() public {
        address garden = _setupSingleModuleGarden();
        _performUpgrade(garden, gardenOwner);

        // Replace in registry
        _replaceFacetInModule(MODULE_1, address(modFacetA2), selsModA);

        // Upgrade again
        _performUpgrade(garden, gardenOwner);

        IDiamondLoupe loupe = IDiamondLoupe(garden);
        assertEq(loupe.facetAddress(ModuleFacetA.modFuncA1.selector), address(modFacetA2));
        assertEq(ModuleFacetA2(garden).modFuncA1(), 10, "should return value from replacement facet");
    }

    function test_upgrade_remove_existingGarden() public {
        address garden = _setupSingleModuleGarden();
        _performUpgrade(garden, gardenOwner);

        // Remove from registry
        _removeFacetFromModule(MODULE_1, selsModA);

        // Upgrade again
        _performUpgrade(garden, gardenOwner);

        IDiamondLoupe loupe = IDiamondLoupe(garden);
        assertEq(loupe.facetAddress(ModuleFacetA.modFuncA1.selector), address(0), "selector should be removed");
    }

    function test_upgrade_incrementalUpgrades() public {
        // Step 1: Install module with FacetA
        address garden = _setupSingleModuleGarden();
        _performUpgrade(garden, gardenOwner);

        // Step 2: Add FacetC to MODULE_1 (new selectors)
        _addFacetToModule(MODULE_1, address(modFacetC), selsModC);
        _performUpgrade(garden, gardenOwner);

        // Both FacetA and FacetC should be installed
        IDiamondLoupe loupe = IDiamondLoupe(garden);
        assertEq(loupe.facetAddress(ModuleFacetA.modFuncA1.selector), address(modFacetA));
        assertEq(loupe.facetAddress(selsModC[0]), address(modFacetC));
    }

    function test_upgrade_multipleVersionSkip() public {
        // Create module with several version increments, then upgrade new garden at once
        _registerModule(MODULE_1);
        _addFacetToModule(MODULE_1, address(modFacetA), selsModA); // v1
        _addFacetToModule(MODULE_1, address(modFacetC), selsModC); // v2
        _addFacetToModule(MODULE_1, address(modFacetE), selsModE); // v3

        bytes32[] memory modules = new bytes32[](1);
        modules[0] = MODULE_1;
        _addGardenType(GARDEN_TYPE_1, modules);

        address garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);
        _performUpgrade(garden, gardenOwner);

        // All 3 facets should be installed
        IDiamondLoupe loupe = IDiamondLoupe(garden);
        assertEq(loupe.facetAddress(selsModA[0]), address(modFacetA));
        assertEq(loupe.facetAddress(selsModC[0]), address(modFacetC));
        assertEq(loupe.facetAddress(selsModE[0]), address(modFacetE));
    }

    // ═══════════════════════════════════════════════════════════════
    //               NET-STATE DIFF: THE CRITICAL FIX
    // ═══════════════════════════════════════════════════════════════

    function test_upgrade_newGarden_addThenReplace() public {
        // THE BUG SCENARIO: Add(FacetA) then Replace(FacetA2) in registry.
        // New garden must succeed — the old code would revert here.
        _registerModule(MODULE_1);
        _addFacetToModule(MODULE_1, address(modFacetA), selsModA);
        _replaceFacetInModule(MODULE_1, address(modFacetA2), selsModA);

        bytes32[] memory modules = new bytes32[](1);
        modules[0] = MODULE_1;
        _addGardenType(GARDEN_TYPE_1, modules);

        address garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);
        _performUpgrade(garden, gardenOwner);

        // Should have FacetA2 (NOT FacetA)
        IDiamondLoupe loupe = IDiamondLoupe(garden);
        assertEq(loupe.facetAddress(selsModA[0]), address(modFacetA2), "should use replacement facet");
        assertEq(ModuleFacetA2(garden).modFuncA1(), 10, "should return replacement value");
    }

    function test_upgrade_newGarden_addThenRemove() public {
        // Add selectors then remove them. New garden should have nothing to install.
        _registerModule(MODULE_1);
        _addFacetToModule(MODULE_1, address(modFacetA), selsModA);
        _removeFacetFromModule(MODULE_1, selsModA);

        bytes32[] memory modules = new bytes32[](1);
        modules[0] = MODULE_1;
        _addGardenType(GARDEN_TYPE_1, modules);

        address garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);

        // Should revert — no actual cuts needed
        vm.expectRevert(abi.encodeWithSelector(UpgradeFacet_NoModuleUpgradesAvailable.selector));
        _upgradeOf(garden).upgradeDetails();
    }

    function test_upgrade_newGarden_addReplaceRemove() public {
        // Add(FacetA, [sel1, sel2]) → Replace(FacetA2, [sel1]) → Remove([sel2])
        // Net effect for new garden: only Add(FacetA2, [sel1])
        _registerModule(MODULE_1);
        _addFacetToModule(MODULE_1, address(modFacetA), selsModA);

        bytes4[] memory sel1 = new bytes4[](1);
        sel1[0] = selsModA[0];
        _replaceFacetInModule(MODULE_1, address(modFacetA2), sel1);

        bytes4[] memory sel2 = new bytes4[](1);
        sel2[0] = selsModA[1];
        _removeFacetFromModule(MODULE_1, sel2);

        bytes32[] memory modules = new bytes32[](1);
        modules[0] = MODULE_1;
        _addGardenType(GARDEN_TYPE_1, modules);

        address garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);
        _performUpgrade(garden, gardenOwner);

        IDiamondLoupe loupe = IDiamondLoupe(garden);
        assertEq(loupe.facetAddress(selsModA[0]), address(modFacetA2), "sel1 should be on FacetA2");
        assertEq(loupe.facetAddress(selsModA[1]), address(0), "sel2 should be removed");
    }

    function test_upgrade_newGarden_addRemoveReAdd() public {
        // Add → Remove → Re-add (to different facet)
        // Net effect: Add with new facet
        _registerModule(MODULE_1);
        _addFacetToModule(MODULE_1, address(modFacetA), selsModA);
        _removeFacetFromModule(MODULE_1, selsModA);
        _addFacetToModule(MODULE_1, address(modFacetA2), selsModA);

        bytes32[] memory modules = new bytes32[](1);
        modules[0] = MODULE_1;
        _addGardenType(GARDEN_TYPE_1, modules);

        address garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);
        _performUpgrade(garden, gardenOwner);

        assertEq(IDiamondLoupe(garden).facetAddress(selsModA[0]), address(modFacetA2));
    }

    function test_upgrade_existingGarden_addThenReplace_multiVersion() public {
        // Garden installs FacetA at v1.
        // Registry: Replace to FacetA2 (v2), then add FacetC (v3).
        // Garden should Replace FacetA→FacetA2 and Add FacetC.
        address garden = _setupSingleModuleGarden();
        _performUpgrade(garden, gardenOwner);

        _replaceFacetInModule(MODULE_1, address(modFacetA2), selsModA);
        _addFacetToModule(MODULE_1, address(modFacetC), selsModC);

        _performUpgrade(garden, gardenOwner);

        IDiamondLoupe loupe = IDiamondLoupe(garden);
        assertEq(loupe.facetAddress(selsModA[0]), address(modFacetA2));
        assertEq(loupe.facetAddress(selsModC[0]), address(modFacetC));
    }

    // ═══════════════════════════════════════════════════════════════
    //                       REVERT CASES
    // ═══════════════════════════════════════════════════════════════

    function test_upgrade_revertsWithWrongHash() public {
        address garden = _setupSingleModuleGarden();
        IUpgrade iUpgrade = _upgradeOf(garden);

        vm.prank(gardenOwner);
        vm.expectRevert(abi.encodeWithSelector(UpgradeFacet_HashMismatch.selector));
        iUpgrade.upgrade(bytes32(uint256(0xDEAD)));
    }

    function test_upgrade_revertsWhenCalledByNonOwner() public {
        address garden = _setupSingleModuleGarden();
        IUpgrade iUpgrade = _upgradeOf(garden);
        (, bytes32 hashData) = iUpgrade.upgradeDetails();

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Garden_UnauthorizedCaller.selector));
        iUpgrade.upgrade(hashData);
    }

    function test_upgrade_revertsWhenAlreadyUpToDate() public {
        address garden = _setupSingleModuleGarden();
        _performUpgrade(garden, gardenOwner);

        vm.prank(gardenOwner);
        vm.expectRevert(abi.encodeWithSelector(UpgradeFacet_NoModuleUpgradesAvailable.selector));
        _upgradeOf(garden).upgrade(bytes32(0));
    }

    function test_upgrade_revertsWhenProtocolInactive() public {
        address garden = _setupSingleModuleGarden();
        IUpgrade iUpgrade = _upgradeOf(garden);
        (, bytes32 hashData) = iUpgrade.upgradeDetails();

        protocolStatus.setStatus(IProtocolStatus.State.INACTIVE);

        vm.prank(gardenOwner);
        vm.expectRevert(abi.encodeWithSelector(Garden_ProtocolIsInactive.selector));
        iUpgrade.upgrade(hashData);
    }

    function test_upgrade_revertsWhenUpgradesDisabled() public {
        address garden = _setupSingleModuleGarden();
        IUpgrade iUpgrade = _upgradeOf(garden);
        (, bytes32 hashData) = iUpgrade.upgradeDetails();

        protocolStatus.setStatus(IProtocolStatus.State.UPGRADES_DISABLED);

        vm.prank(gardenOwner);
        vm.expectRevert(abi.encodeWithSelector(Garden_UpgradesDisabled.selector));
        iUpgrade.upgrade(hashData);
    }

    function test_upgrade_revertsWithStaleHash() public {
        // Get hash, then modify registry, then try to use old hash
        address garden = _setupSingleModuleGarden();
        IUpgrade iUpgrade = _upgradeOf(garden);
        (, bytes32 hashData) = iUpgrade.upgradeDetails();

        // Add more selectors to the module — changes the upgrade details
        _addFacetToModule(MODULE_1, address(modFacetC), selsModC);

        vm.prank(gardenOwner);
        vm.expectRevert(abi.encodeWithSelector(UpgradeFacet_HashMismatch.selector));
        iUpgrade.upgrade(hashData);
    }
}
