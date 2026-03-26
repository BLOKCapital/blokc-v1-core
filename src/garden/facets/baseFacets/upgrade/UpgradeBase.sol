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
import { DiamondCutStorage } from "src/garden/facets/baseFacets/cut/DiamondCutStorage.sol";
import { LibDiamond } from "src/garden/libraries/LibDiamond.sol";

// OpenZeppelin
import { Arrays } from "@openzeppelin/contracts/utils/Arrays.sol";

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

        (facetCuts,,) = _collectModuleUpgrades(registry, ld.gardenType, us);

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

        (
            IDiamondCut.FacetCut[] memory facetCuts,
            bytes32[] memory gardenTypeModules,
            uint256[] memory registryVersions
        ) = _collectModuleUpgrades(registry, ld.gardenType, us);

        if (facetCuts.length == 0) {
            revert UpgradeFacet_NoModuleUpgradesAvailable();
        }

        if (_hashData != keccak256(abi.encode(facetCuts, ld.gardenType))) {
            revert UpgradeFacet_HashMismatch();
        }

        _applyDiamondCut(facetCuts, address(0), "");
        _syncModuleVersions(gardenTypeModules, registryVersions, us);

        emit GardenUpgraded(facetCuts);
    }

    /// @notice Collects facet cuts from all modules that have newer versions
    /// @dev Computes the net-state diff between the garden's diamond and the registry's current state,
    ///      rather than replaying raw version history.
    ///
    ///      Complexity: O(S·log(S) + H) where S = total selectors across upgradeable modules,
    ///      H = total version history entries. Each selector requires exactly one O(1) storage lookup
    ///      against the diamond. The sort (via OZ Arrays.sort) enables O(log S) binary search for the
    ///      re-add check in the Remove phase. New gardens (storedVersion == 0) skip the Remove phase
    ///      entirely since no module selectors exist in the diamond.
    ///
    /// @param registry The FacetRegistry to query
    /// @param gardenType The garden type identifier
    /// @param us The UpgradeStorage layout
    /// @return facetCuts Aggregated facet cuts from all modules needing upgrade
    /// @return gardenTypeModules The cached module IDs for this garden type
    /// @return registryVersions The cached current version for each module
    function _collectModuleUpgrades(
        IFacetRegistry registry,
        bytes32 gardenType,
        UpgradeStorage.Layout storage us
    )
        internal
        view
        returns (
            IDiamondCut.FacetCut[] memory facetCuts,
            bytes32[] memory gardenTypeModules,
            uint256[] memory registryVersions
        )
    {
        gardenTypeModules = registry.getGardenTypeModules(gardenType);
        DiamondCutStorage.Layout storage ds = DiamondCutStorage.layout();
        uint256 moduleCount = gardenTypeModules.length;

        // ── Phase 1: Cache module data and estimate allocation in a single pass ──
        uint256[] memory storedVersions = new uint256[](moduleCount);
        registryVersions = new uint256[](moduleCount);
        IFacetRegistry.Facet[][] memory cachedModuleFacets = new IFacetRegistry.Facet[][](moduleCount);
        uint256 maxFacetCuts = 0;

        for (uint256 moduleIndex = 0; moduleIndex < moduleCount; moduleIndex++) {
            bytes32 moduleId = gardenTypeModules[moduleIndex];
            storedVersions[moduleIndex] = us.moduleVersions[moduleId];
            registryVersions[moduleIndex] = registry.getModuleVersion(moduleId);

            if (registryVersions[moduleIndex] > storedVersions[moduleIndex]) {
                cachedModuleFacets[moduleIndex] = registry.getModuleFacets(moduleId);
                maxFacetCuts += cachedModuleFacets[moduleIndex].length * 2 + 1;
            }
        }

        if (maxFacetCuts == 0) {
            return (new IDiamondCut.FacetCut[](0), gardenTypeModules, registryVersions);
        }

        IDiamondCut.FacetCut[] memory pendingFacetCuts = new IDiamondCut.FacetCut[](maxFacetCuts);
        uint256 cutCount = 0;

        // ── Phase 2: Process each upgradeable module ──
        for (uint256 moduleIndex = 0; moduleIndex < moduleCount; moduleIndex++) {
            if (registryVersions[moduleIndex] <= storedVersions[moduleIndex]) continue;

            cutCount = _processModuleUpgrade(
                registry,
                cachedModuleFacets[moduleIndex],
                gardenTypeModules[moduleIndex],
                storedVersions[moduleIndex],
                registryVersions[moduleIndex],
                ds,
                pendingFacetCuts,
                cutCount
            );
        }

        // ── Phase 4: Compact the result array to exact size ──
        facetCuts = new IDiamondCut.FacetCut[](cutCount);
        for (uint256 cutIndex = 0; cutIndex < cutCount; cutIndex++) {
            facetCuts[cutIndex] = pendingFacetCuts[cutIndex];
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                     PHASE EXTRACTION HELPERS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Processes a single module upgrade: diffs facets, collects removals, appends to pending cuts
    /// @dev Extracted from the main loop to reduce stack depth in _collectModuleUpgrades.
    /// @param registry The FacetRegistry to query for version history
    /// @param moduleFacets The cached current facets for this module
    /// @param moduleId The module identifier
    /// @param storedVersion The garden's current version for this module
    /// @param registryVersion The registry's current version for this module
    /// @param ds The DiamondCutStorage layout
    /// @param pendingFacetCuts The output array to append cuts into
    /// @param cutCount The current write position in pendingFacetCuts
    /// @return newCutCount The updated write position after appending this module's cuts
    function _processModuleUpgrade(
        IFacetRegistry registry,
        IFacetRegistry.Facet[] memory moduleFacets,
        bytes32 moduleId,
        uint256 storedVersion,
        uint256 registryVersion,
        DiamondCutStorage.Layout storage ds,
        IDiamondCut.FacetCut[] memory pendingFacetCuts,
        uint256 cutCount
    )
        internal
        view
        returns (uint256 newCutCount)
    {
        newCutCount = cutCount;

        // Phase 2a-2c: Diff module facets against diamond + build sorted selector set
        (IDiamondCut.FacetCut[] memory addReplaceCuts, bytes4[] memory sortedModuleSelectors) =
            _diffModuleFacets(moduleFacets, ds);

        for (uint256 cutIndex = 0; cutIndex < addReplaceCuts.length; cutIndex++) {
            pendingFacetCuts[newCutCount++] = addReplaceCuts[cutIndex];
        }

        // Phase 3: Remove — only for existing gardens (storedVersion > 0)
        // New gardens have no module selectors in the diamond so historical removals
        // are irrelevant — skip the version history scan entirely.
        if (storedVersion > 0) {
            IDiamondCut.FacetCut[] memory versionHistory = registry.getModuleFacetCutsByVersionRange(
                moduleId, storedVersion + 1, registryVersion
            );

            bytes4[] memory removedSelectors =
                _collectRemovedSelectors(versionHistory, sortedModuleSelectors, ds);

            if (removedSelectors.length > 0) {
                pendingFacetCuts[newCutCount++] = IDiamondCut.FacetCut({
                    facetAddress: address(0),
                    action: IDiamondCut.FacetCutAction.Remove,
                    functionSelectors: removedSelectors
                });
            }
        }
    }

    /// @notice Diffs module facets against the diamond to produce Add/Replace cuts and a sorted selector set
    /// @dev Extracted from _collectModuleUpgrades Phase 2 to reduce stack depth (OZ Arrays.sol uses
    ///      non-memory-safe assembly which prevents the Yul optimizer from spilling stack to memory).
    /// @param moduleFacets The current registry facets for this module
    /// @param ds The DiamondCutStorage layout for O(1) selector lookups
    /// @return addReplaceCuts The Add and Replace FacetCut entries for this module
    /// @return sortedModuleSelectors All selectors in the module's current state, sorted ascending
    function _diffModuleFacets(
        IFacetRegistry.Facet[] memory moduleFacets,
        DiamondCutStorage.Layout storage ds
    )
        internal
        view
        returns (IDiamondCut.FacetCut[] memory addReplaceCuts, bytes4[] memory sortedModuleSelectors)
    {
        // Count total selectors across all facets in this module
        uint256 totalModuleSelectors = 0;
        for (uint256 facetIndex = 0; facetIndex < moduleFacets.length; facetIndex++) {
            totalModuleSelectors += moduleFacets[facetIndex].functionSelectors.length;
        }

        sortedModuleSelectors = new bytes4[](totalModuleSelectors);
        uint256 selectorCount = 0;

        // Over-allocate: at most 2 cuts per facet (Add + Replace)
        IDiamondCut.FacetCut[] memory pendingCuts = new IDiamondCut.FacetCut[](moduleFacets.length * 2);
        uint256 cutCount = 0;

        for (uint256 facetIndex = 0; facetIndex < moduleFacets.length; facetIndex++) {
            address facetAddress = moduleFacets[facetIndex].facetAddress;
            bytes4[] memory functionSelectors = moduleFacets[facetIndex].functionSelectors;

            bytes4[] memory selectorsToAdd = new bytes4[](functionSelectors.length);
            bytes4[] memory selectorsToReplace = new bytes4[](functionSelectors.length);
            uint256 addCount = 0;
            uint256 replaceCount = 0;

            for (uint256 selectorIndex = 0; selectorIndex < functionSelectors.length; selectorIndex++) {
                bytes4 selector = functionSelectors[selectorIndex];
                sortedModuleSelectors[selectorCount++] = selector;

                address diamondFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
                if (diamondFacetAddress == address(0)) {
                    selectorsToAdd[addCount++] = selector;
                } else if (diamondFacetAddress != facetAddress) {
                    selectorsToReplace[replaceCount++] = selector;
                }
            }

            if (addCount > 0) {
                pendingCuts[cutCount++] = IDiamondCut.FacetCut({
                    facetAddress: facetAddress,
                    action: IDiamondCut.FacetCutAction.Add,
                    functionSelectors: _trimBytes4Array(selectorsToAdd, addCount)
                });
            }
            if (replaceCount > 0) {
                pendingCuts[cutCount++] = IDiamondCut.FacetCut({
                    facetAddress: facetAddress,
                    action: IDiamondCut.FacetCutAction.Replace,
                    functionSelectors: _trimBytes4Array(selectorsToReplace, replaceCount)
                });
            }
        }

        // Sort for O(log S) binary search in Remove phase
        _sortBytes4Array(sortedModuleSelectors);

        // Compact to exact size
        addReplaceCuts = new IDiamondCut.FacetCut[](cutCount);
        for (uint256 cutIndex = 0; cutIndex < cutCount; cutIndex++) {
            addReplaceCuts[cutIndex] = pendingCuts[cutIndex];
        }
    }

    /// @notice Filters version history to find selectors that need removal from the diamond
    /// @dev Extracted from _collectModuleUpgrades Phase 3 to reduce stack depth.
    ///      Uses O(1) diamond check → O(log S) binary search → O(survivors) dedup.
    /// @param versionHistory The FacetCut history for the version range being upgraded
    /// @param sortedModuleSelectors The sorted current module selectors (from _diffModuleFacets)
    /// @param ds The DiamondCutStorage layout for O(1) selector lookups
    /// @return removedSelectors The deduplicated selectors to remove (empty array if none)
    function _collectRemovedSelectors(
        IDiamondCut.FacetCut[] memory versionHistory,
        bytes4[] memory sortedModuleSelectors,
        DiamondCutStorage.Layout storage ds
    )
        internal
        view
        returns (bytes4[] memory removedSelectors)
    {
        // Count max possible removed selectors
        uint256 maxRemovedSelectors = 0;
        for (uint256 historyIndex = 0; historyIndex < versionHistory.length; historyIndex++) {
            if (versionHistory[historyIndex].action == IDiamondCut.FacetCutAction.Remove) {
                maxRemovedSelectors += versionHistory[historyIndex].functionSelectors.length;
            }
        }

        if (maxRemovedSelectors == 0) {
            return new bytes4[](0);
        }

        bytes4[] memory selectorsToRemove = new bytes4[](maxRemovedSelectors);
        uint256 removeCount = 0;

        for (uint256 historyIndex = 0; historyIndex < versionHistory.length; historyIndex++) {
            if (versionHistory[historyIndex].action != IDiamondCut.FacetCutAction.Remove) continue;
            bytes4[] memory historySelectors = versionHistory[historyIndex].functionSelectors;

            for (uint256 selectorIndex = 0; selectorIndex < historySelectors.length; selectorIndex++) {
                bytes4 selector = historySelectors[selectorIndex];

                // O(1): skip if not in diamond
                if (ds.selectorToFacetAndPosition[selector].facetAddress == address(0)) continue;

                // O(log S): skip if re-added to current module state
                if (_containsBytes4(sortedModuleSelectors, selector)) continue;

                // O(removeCount): dedup among survivors — removeCount is bounded by
                // selectors actually in the diamond AND not re-added, typically 0-5
                bool isDuplicate = false;
                for (uint256 dedupIndex = 0; dedupIndex < removeCount; dedupIndex++) {
                    if (selectorsToRemove[dedupIndex] == selector) {
                        isDuplicate = true;
                        break;
                    }
                }
                if (!isDuplicate) selectorsToRemove[removeCount++] = selector;
            }
        }

        return _trimBytes4Array(selectorsToRemove, removeCount);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                        INTERNAL HELPERS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Sorts a bytes4 array in-place using OpenZeppelin's Arrays.sort (quicksort)
    /// @dev Casts bytes4[] to uint256[] via assembly. Safe because each bytes4 element occupies
    ///      a full 32-byte memory slot (left-aligned), preserving sort ordering when compared as uint256.
    ///      This is the same technique OZ uses internally for bytes32[] → uint256[].
    /// @param array The bytes4 array to sort in ascending order
    function _sortBytes4Array(bytes4[] memory array) internal pure {
        Arrays.sort(_castBytes4ToUint256Array(array));
    }

    /// @notice Checks if a sorted bytes4 array contains a target value using OZ's binary search
    /// @dev Uses Arrays.lowerBoundMemory for O(log n) lookup, then verifies exact match.
    /// @param sortedArray The sorted bytes4 array (sorted via _sortBytes4Array)
    /// @param target The bytes4 value to find
    /// @return True if the target exists in the array
    function _containsBytes4(bytes4[] memory sortedArray, bytes4 target) internal pure returns (bool) {
        uint256[] memory asUint = _castBytes4ToUint256Array(sortedArray);
        uint256 targetAsUint = uint256(bytes32(target));
        uint256 index = Arrays.lowerBoundMemory(asUint, targetAsUint);
        return index < asUint.length && asUint[index] == targetAsUint;
    }

    /// @notice Casts a bytes4[] memory array to uint256[] memory via assembly
    /// @dev Safe because each bytes4 element occupies a full 32-byte memory slot (left-aligned),
    ///      matching uint256 memory layout. This is the same technique OZ uses for bytes32[] → uint256[].
    function _castBytes4ToUint256Array(bytes4[] memory input) internal pure returns (uint256[] memory output) {
        assembly ("memory-safe") {
            output := input
        }
    }

    /// @notice Creates a trimmed copy of a bytes4 array
    /// @param sourceArray The source array (may be oversized)
    /// @param targetLength The number of elements to copy
    /// @return trimmedArray The trimmed array of exact length
    function _trimBytes4Array(
        bytes4[] memory sourceArray,
        uint256 targetLength
    )
        internal
        pure
        returns (bytes4[] memory trimmedArray)
    {
        trimmedArray = new bytes4[](targetLength);
        for (uint256 i = 0; i < targetLength; i++) {
            trimmedArray[i] = sourceArray[i];
        }
    }

    /// @notice Syncs per-module versions to current registry versions using pre-cached data
    /// @dev Uses cached gardenTypeModules and registryVersions from _collectModuleUpgrades
    ///      to avoid redundant external calls to getGardenTypeModules and getModuleVersion.
    ///      BASE_MODULE is immutable and never included in gardenTypeModules.
    /// @param gardenTypeModules The cached module IDs for this garden type
    /// @param registryVersions The cached current version for each module
    /// @param us The UpgradeStorage layout
    function _syncModuleVersions(
        bytes32[] memory gardenTypeModules,
        uint256[] memory registryVersions,
        UpgradeStorage.Layout storage us
    )
        internal
    {
        for (uint256 moduleIndex = 0; moduleIndex < gardenTypeModules.length; moduleIndex++) {
            us.moduleVersions[gardenTypeModules[moduleIndex]] = registryVersions[moduleIndex];
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
