// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title UpgradeFacet
    @author BLOK Capital DAO
    @notice Facet that manages Diamond upgrades by syncing with the FacetRegistry.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

// Local Interfaces
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";
import { IUpgrade } from "./IUpgrade.sol";

// Local Libraries
import { UpgradeStorage } from "./UpgradeStorage.sol";
import { DiamondCutStorage } from "../cut/DiamondCutStorage.sol";
import { DiamondCutBase } from "../cut/DiamondCutBase.sol";
// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when attempting to upgrade but already at the latest version
/// @param registryVersion The registry version that is already applied
error UpgradeFacet_AlreadyAtLatestVersion(uint256 registryVersion);

/// @notice Thrown when the computed hash does not match the provided hash data
error UpgradeFacet_HashMismatch();

/// @notice Thrown when no facet cuts are required for upgrade
error UpgradeFacet_NoFacetCutsRequired();

/// @notice Thrown when a facet is not found
error UpgradeFacet_FacetNotFound();

/**
 * @title UpgradeBase
 * @notice Facet that manages Diamond upgrades by syncing with the FacetRegistry
 * @dev This base contract allows upgrading the diamond to match the latest state of the FacetRegistry
 */
abstract contract UpgradeBase is DiamondCutBase {
    event GardenUpgraded(IDiamondCut.FacetCut[] facetCuts, uint256 indexed oldVersion, uint256 indexed newVersion);

    function _upgradeDetails()
        internal
        view
        returns (
            IDiamondCut.FacetCut[] memory facetCuts,
            uint256 diamondVersion,
            uint256 registryVersion,
            bytes32 hashData
        )
    {
        IFacetRegistry facetRegistry = IFacetRegistry(DiamondCutStorage.layout().facetRegistry);
        diamondVersion = UpgradeStorage.layout().diamondVersion;
        registryVersion = facetRegistry.getCurrentVersion();
        if (diamondVersion >= registryVersion) {
            revert UpgradeFacet_AlreadyAtLatestVersion(registryVersion);
        }
        facetCuts = facetRegistry.getFacetCutsByVersionRange(diamondVersion + 1, registryVersion);
        hashData = keccak256(abi.encode(facetCuts, diamondVersion, registryVersion));
    }

    function _upgrade(bytes32 _hashData) internal {
        IFacetRegistry facetRegistry = IFacetRegistry(DiamondCutStorage.layout().facetRegistry);
        uint256 diamondVersion = UpgradeStorage.layout().diamondVersion;
        uint256 registryVersion = facetRegistry.getCurrentVersion();
        if (diamondVersion >= registryVersion) {
            revert UpgradeFacet_AlreadyAtLatestVersion(registryVersion);
        }
        IDiamondCut.FacetCut[] memory facetCuts =
            facetRegistry.getFacetCutsByVersionRange(diamondVersion + 1, registryVersion);
        if (_hashData != keccak256(abi.encode(facetCuts, diamondVersion, registryVersion))) {
            revert UpgradeFacet_HashMismatch();
        }
        _applyDiamondCut(facetCuts, address(0), "");
        UpgradeStorage.layout().diamondVersion = registryVersion;
        emit GardenUpgraded(facetCuts, diamondVersion, registryVersion);
    }

    function _getCurrentVersion() internal view returns (uint256) {
        return UpgradeStorage.layout().diamondVersion;
    }
}
