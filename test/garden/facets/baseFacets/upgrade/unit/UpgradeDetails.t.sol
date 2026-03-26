// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { UpgradeTestBase, ModuleFacetA, ModuleFacetA2 } from "../UpgradeTestBase.sol";
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";
import { IUpgrade } from "src/garden/facets/baseFacets/upgrade/IUpgrade.sol";

/// @notice Thrown when no module upgrades are available
error UpgradeFacet_NoModuleUpgradesAvailable();

contract UpgradeDetailsTest is UpgradeTestBase {
    // ═══════════════════════════════════════════════════════════════
    //                       SUCCESS CASES
    // ═══════════════════════════════════════════════════════════════

    function test_upgradeDetails_singleModuleAdd() public {
        address garden = _setupSingleModuleGarden();
        IUpgrade iUpgrade = _upgradeOf(garden);

        (IDiamondCut.FacetCut[] memory cuts, bytes32 hashData) = iUpgrade.upgradeDetails();

        assertGt(cuts.length, 0, "should have cuts");
        assertEq(cuts[0].facetAddress, address(modFacetA), "facet should be modFacetA");
        assertEq(uint8(cuts[0].action), uint8(IDiamondCut.FacetCutAction.Add), "action should be Add");
        assertEq(cuts[0].functionSelectors.length, 2, "should have 2 selectors");
        assertTrue(hashData != bytes32(0), "hash should not be zero");
    }

    function test_upgradeDetails_multiModuleAdd() public {
        address garden = _setupDualModuleGarden();
        IUpgrade iUpgrade = _upgradeOf(garden);

        (IDiamondCut.FacetCut[] memory cuts,) = iUpgrade.upgradeDetails();

        assertEq(cuts.length, 2, "should have 2 cuts (one per module facet)");
    }

    function test_upgradeDetails_hashDeterministic() public {
        address garden = _setupSingleModuleGarden();
        IUpgrade iUpgrade = _upgradeOf(garden);

        (, bytes32 hash1) = iUpgrade.upgradeDetails();
        (, bytes32 hash2) = iUpgrade.upgradeDetails();

        assertEq(hash1, hash2, "hash should be deterministic");
    }

    function test_upgradeDetails_afterReplace_netStateDiff() public {
        // Registry: Add(FacetA, [sel1,sel2]) then Replace(FacetA2, [sel1,sel2])
        // New garden should see Add(FacetA2, [sel1,sel2]) — NOT the stale Add(FacetA)
        _registerModule(MODULE_1);
        _addFacetToModule(MODULE_1, address(modFacetA), selsModA);
        _replaceFacetInModule(MODULE_1, address(modFacetA2), selsModA);

        bytes32[] memory modules = new bytes32[](1);
        modules[0] = MODULE_1;
        _addGardenType(GARDEN_TYPE_1, modules);

        address garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);
        IUpgrade iUpgrade = _upgradeOf(garden);

        (IDiamondCut.FacetCut[] memory cuts,) = iUpgrade.upgradeDetails();

        assertEq(cuts.length, 1, "should have 1 cut");
        assertEq(cuts[0].facetAddress, address(modFacetA2), "should point to replacement facet");
        assertEq(uint8(cuts[0].action), uint8(IDiamondCut.FacetCutAction.Add), "should be Add for new garden");
        assertEq(cuts[0].functionSelectors.length, 2, "should have both selectors");
    }

    function test_upgradeDetails_afterAddThenRemove_netEmpty() public {
        // Registry: Add then Remove same selectors.
        // New garden at version 0: net effect is nothing for those selectors.
        // But the module version is > 0, and the module has no current facets.
        _registerModule(MODULE_1);
        _addFacetToModule(MODULE_1, address(modFacetA), selsModA);
        _removeFacetFromModule(MODULE_1, selsModA);

        bytes32[] memory modules = new bytes32[](1);
        modules[0] = MODULE_1;
        _addGardenType(GARDEN_TYPE_1, modules);

        address garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);
        IUpgrade iUpgrade = _upgradeOf(garden);

        // Module version is 2 but net effect is zero cuts.
        // upgradeDetails should revert because there are no actual cuts needed.
        vm.expectRevert(abi.encodeWithSelector(UpgradeFacet_NoModuleUpgradesAvailable.selector));
        iUpgrade.upgradeDetails();
    }

    function test_upgradeDetails_partialReplace() public {
        // Add [sel1, sel2] to FacetA, then Replace only sel1 to FacetA2.
        // New garden should see: Add(FacetA, [sel2]) and Add(FacetA2, [sel1])
        _registerModule(MODULE_1);
        _addFacetToModule(MODULE_1, address(modFacetA), selsModA);

        bytes4[] memory replSel = new bytes4[](1);
        replSel[0] = selsModA[0]; // only modFuncA1
        _replaceFacetInModule(MODULE_1, address(modFacetA2), replSel);

        bytes32[] memory modules = new bytes32[](1);
        modules[0] = MODULE_1;
        _addGardenType(GARDEN_TYPE_1, modules);

        address garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);
        IUpgrade iUpgrade = _upgradeOf(garden);

        (IDiamondCut.FacetCut[] memory cuts,) = iUpgrade.upgradeDetails();

        // Should have 2 Add cuts: one for FacetA (remaining sel), one for FacetA2 (replaced sel)
        assertEq(cuts.length, 2, "should have 2 cuts");

        // Find which is which
        bool foundA = false;
        bool foundA2 = false;
        for (uint256 i = 0; i < cuts.length; i++) {
            assertEq(uint8(cuts[i].action), uint8(IDiamondCut.FacetCutAction.Add), "all should be Add for new garden");
            if (cuts[i].facetAddress == address(modFacetA)) {
                foundA = true;
                assertEq(cuts[i].functionSelectors.length, 1);
                assertEq(cuts[i].functionSelectors[0], ModuleFacetA.modFuncA2.selector);
            } else if (cuts[i].facetAddress == address(modFacetA2)) {
                foundA2 = true;
                assertEq(cuts[i].functionSelectors.length, 1);
                assertEq(cuts[i].functionSelectors[0], ModuleFacetA.modFuncA1.selector);
            }
        }
        assertTrue(foundA, "should find FacetA cut");
        assertTrue(foundA2, "should find FacetA2 cut");
    }

    function test_upgradeDetails_existingGarden_replace() public {
        // Garden upgrades to version 1 (installs FacetA).
        // Then registry replaces FacetA with FacetA2.
        // upgradeDetails should return Replace, not Add.
        address garden = _setupSingleModuleGarden();
        _performUpgrade(garden, gardenOwner);

        // Now replace in registry
        _replaceFacetInModule(MODULE_1, address(modFacetA2), selsModA);

        IUpgrade iUpgrade = _upgradeOf(garden);
        (IDiamondCut.FacetCut[] memory cuts,) = iUpgrade.upgradeDetails();

        assertEq(cuts.length, 1, "should have 1 cut");
        assertEq(cuts[0].facetAddress, address(modFacetA2), "should be new facet");
        assertEq(uint8(cuts[0].action), uint8(IDiamondCut.FacetCutAction.Replace), "should be Replace for existing");
    }

    function test_upgradeDetails_existingGarden_remove() public {
        // Garden installs FacetA. Registry removes the selectors.
        // upgradeDetails should return Remove.
        address garden = _setupSingleModuleGarden();
        _performUpgrade(garden, gardenOwner);

        // Remove from registry
        _removeFacetFromModule(MODULE_1, selsModA);

        IUpgrade iUpgrade = _upgradeOf(garden);
        (IDiamondCut.FacetCut[] memory cuts,) = iUpgrade.upgradeDetails();

        assertEq(cuts.length, 1, "should have 1 cut");
        assertEq(cuts[0].facetAddress, address(0), "remove facet address should be zero");
        assertEq(uint8(cuts[0].action), uint8(IDiamondCut.FacetCutAction.Remove), "should be Remove");
        assertEq(cuts[0].functionSelectors.length, 2, "should remove both selectors");
    }

    // ═══════════════════════════════════════════════════════════════
    //                       REVERT CASES
    // ═══════════════════════════════════════════════════════════════

    function test_upgradeDetails_revertsWhenAlreadyUpToDate() public {
        address garden = _setupSingleModuleGarden();
        _performUpgrade(garden, gardenOwner);

        vm.expectRevert(abi.encodeWithSelector(UpgradeFacet_NoModuleUpgradesAvailable.selector));
        _upgradeOf(garden).upgradeDetails();
    }

    function test_upgradeDetails_revertsWhenNoModuleChanges() public {
        // Garden type has modules but none have been upgraded
        _registerModule(MODULE_1);
        bytes32[] memory modules = new bytes32[](1);
        modules[0] = MODULE_1;
        _addGardenType(GARDEN_TYPE_1, modules);

        address garden = _deployGarden(GARDEN_TYPE_1, gardenOwner);

        vm.expectRevert(abi.encodeWithSelector(UpgradeFacet_NoModuleUpgradesAvailable.selector));
        _upgradeOf(garden).upgradeDetails();
    }
}
