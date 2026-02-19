// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

// Local Interfaces
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { IUpgrade } from "src/garden/facets/baseFacets/upgrade/IUpgrade.sol";

// Local Libraries
import { UpgradeStorage } from "src/garden/facets/baseFacets/upgrade/UpgradeStorage.sol";
import { DiamondCutBase } from "src/garden/facets/baseFacets/cut/DiamondCutBase.sol";
import { LibDiamond } from "src/garden/libraries/LibDiamond.sol";

/// @notice Thrown when attempting to upgrade but already at the latest version
error UpgradeFacet_AlreadyAtLatestVersion();

/// @notice Thrown when the computed hash does not match the provided hash data
error UpgradeFacet_HashMismatch();

/// @notice Thrown when no facet cuts are required for upgrade
error UpgradeFacet_NoFacetCutsRequired();

/// @notice Thrown when a facet is not found
error UpgradeFacet_FacetNotFound();

/// @notice Thrown when no module upgrades are available
error UpgradeFacet_NoModuleUpgradesAvailable();

/**
 * @title UpgradeBase
 * @notice Base contract that implements internal functions for upgrading the diamond to the latest facets from the
 * FacetRegistry. This contract is intended to be inherited by an UpgradeFacet that exposes the upgrade functions with
 * appropriate access control and user-facing error messages.
 */
abstract contract UpgradeBase is DiamondCutBase, IUpgrade {
    /// @notice Emitted when the diamond is upgraded
    /// @param facetCuts The facet cuts applied in the upgrade
    event GardenUpgraded(IDiamondCut.FacetCut[] facetCuts);

    /// @notice Retrieves the upgrade details by checking all modules allowed for this garden's type
    /// @return facetCuts The aggregated facet cuts from all modules that need upgrading
    /// @return hashData The hash for verification
    function _upgradeDetails() internal view returns (IDiamondCut.FacetCut[] memory facetCuts, bytes32 hashData) {
        LibDiamond.Layout storage ld = LibDiamond.layout();
        IFacetRegistry registry = IFacetRegistry(ld.facetRegistry);
        UpgradeStorage.Layout storage us = UpgradeStorage.layout();

        facetCuts = _collectModuleUpgrades(registry, ld.gardenType, us);

        if (facetCuts.length == 0) {
            revert UpgradeFacet_NoModuleUpgradesAvailable();
        }

        hashData = keccak256(abi.encode(facetCuts, ld.gardenType));
    }

    /// @notice Upgrades the diamond by applying per-module facet cuts
    /// @param _hashData The hash for verification (from upgradeDetails)
    function _upgrade(bytes32 _hashData) internal {
        LibDiamond.Layout storage ld = LibDiamond.layout();
        IFacetRegistry registry = IFacetRegistry(ld.facetRegistry);
        UpgradeStorage.Layout storage us = UpgradeStorage.layout();

        IDiamondCut.FacetCut[] memory facetCuts = _collectModuleUpgrades(registry, ld.gardenType, us);

        if (facetCuts.length == 0) {
            revert UpgradeFacet_NoModuleUpgradesAvailable();
        }

        if (_hashData != keccak256(abi.encode(facetCuts, ld.gardenType))) {
            revert UpgradeFacet_HashMismatch();
        }

        _applyDiamondCut(facetCuts, address(0), "");
        _syncModuleVersions(registry, ld.gardenType, us);

        emit GardenUpgraded(facetCuts);
    }

    /// @notice Collects facet cuts from all modules that have newer versions
    /// @dev Iterates only gardenType modules (BASE_MODULE is immutable and never needs upgrades)
    /// @param registry The FacetRegistry to query
    /// @param gardenType The garden type identifier
    /// @param us The UpgradeStorage layout
    /// @return facetCuts Aggregated facet cuts from all modules needing upgrade
    function _collectModuleUpgrades(
        IFacetRegistry registry,
        bytes32 gardenType,
        UpgradeStorage.Layout storage us
    )
        internal
        view
        returns (IDiamondCut.FacetCut[] memory facetCuts)
    {
        bytes32[] memory typeModules = registry.getGardenTypeModules(gardenType);

        // First pass: count total cuts needed
        uint256 totalCuts = 0;
        for (uint256 i = 0; i < typeModules.length; i++) {
            bytes32 moduleId = typeModules[i];
            uint256 storedVersion = us.moduleVersions[moduleId];
            uint256 currentVersion = registry.getModuleVersion(moduleId);
            if (currentVersion > storedVersion) {
                totalCuts += currentVersion - storedVersion;
            }
        }

        // Second pass: collect cuts
        facetCuts = new IDiamondCut.FacetCut[](totalCuts);
        uint256 index = 0;
        for (uint256 i = 0; i < typeModules.length; i++) {
            bytes32 moduleId = typeModules[i];
            uint256 storedVersion = us.moduleVersions[moduleId];
            uint256 currentVersion = registry.getModuleVersion(moduleId);
            if (currentVersion > storedVersion) {
                IDiamondCut.FacetCut[] memory moduleCuts =
                    registry.getModuleFacetCutsByVersionRange(moduleId, storedVersion + 1, currentVersion);
                for (uint256 j = 0; j < moduleCuts.length; j++) {
                    facetCuts[index++] = moduleCuts[j];
                }
            }
        }
    }

    /// @notice Syncs per-module versions to current registry versions
    /// @dev BASE_MODULE is immutable and never changes, so we don't sync it
    /// @param registry The FacetRegistry to query
    /// @param gardenType The garden type identifier
    /// @param us The UpgradeStorage layout
    function _syncModuleVersions(
        IFacetRegistry registry,
        bytes32 gardenType,
        UpgradeStorage.Layout storage us
    )
        internal
    {
        bytes32[] memory typeModules = registry.getGardenTypeModules(gardenType);
        for (uint256 i = 0; i < typeModules.length; i++) {
            us.moduleVersions[typeModules[i]] = registry.getModuleVersion(typeModules[i]);
        }
    }

    /// @notice Returns the current version of a module installed in garden
    /// @param moduleId The module to query
    /// @return version The current module version
    function _getModuleVersion(bytes32 moduleId) internal view returns (uint256 version) {
        UpgradeStorage.Layout storage us = UpgradeStorage.layout();
        version = us.moduleVersions[moduleId];
    }
}
