// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { UpgradeTestBase } from "../UpgradeTestBase.sol";
import { IUpgrade } from "src/garden/facets/baseFacets/upgrade/IUpgrade.sol";

contract GetModuleVersionTest is UpgradeTestBase {
    // ═══════════════════════════════════════════════════════════════
    //                       SUCCESS CASES
    // ═══════════════════════════════════════════════════════════════

    function test_getModuleVersion_initiallyZero() public {
        address garden = _setupSingleModuleGarden();
        IUpgrade iUpgrade = _upgradeOf(garden);

        assertEq(iUpgrade.getModuleVersion(MODULE_1), 0, "should be zero before first upgrade");
    }

    function test_getModuleVersion_afterUpgrade() public {
        address garden = _setupSingleModuleGarden();
        _performUpgrade(garden, gardenOwner);

        IUpgrade iUpgrade = _upgradeOf(garden);
        uint256 expected = registry.getModuleVersion(MODULE_1);
        assertEq(iUpgrade.getModuleVersion(MODULE_1), expected, "should match registry version");
    }

    function test_getModuleVersion_multipleModules() public {
        address garden = _setupDualModuleGarden();
        _performUpgrade(garden, gardenOwner);

        IUpgrade iUpgrade = _upgradeOf(garden);
        assertEq(iUpgrade.getModuleVersion(MODULE_1), registry.getModuleVersion(MODULE_1));
        assertEq(iUpgrade.getModuleVersion(MODULE_2), registry.getModuleVersion(MODULE_2));
    }

    function test_getModuleVersion_unregisteredModuleReturnsZero() public {
        address garden = _setupSingleModuleGarden();
        _performUpgrade(garden, gardenOwner);

        IUpgrade iUpgrade = _upgradeOf(garden);
        assertEq(iUpgrade.getModuleVersion(keccak256("NONEXISTENT")), 0, "unknown module should return 0");
    }

    function test_getModuleVersion_incrementalUpgrades() public {
        address garden = _setupSingleModuleGarden();
        _performUpgrade(garden, gardenOwner);

        IUpgrade iUpgrade = _upgradeOf(garden);
        uint256 v1 = iUpgrade.getModuleVersion(MODULE_1);

        // Add more to module
        _addFacetToModule(MODULE_1, address(modFacetC), selsModC);
        _performUpgrade(garden, gardenOwner);

        uint256 v2 = iUpgrade.getModuleVersion(MODULE_1);
        assertGt(v2, v1, "version should increment after second upgrade");
    }

    function test_getModuleVersion_baseModuleAlwaysZero() public {
        address garden = _setupSingleModuleGarden();
        _performUpgrade(garden, gardenOwner);

        IUpgrade iUpgrade = _upgradeOf(garden);
        // BASE_MODULE is never upgraded via the upgrade mechanism
        assertEq(iUpgrade.getModuleVersion(BASE_MODULE), 0, "base module version should always be 0 in garden");
    }
}
