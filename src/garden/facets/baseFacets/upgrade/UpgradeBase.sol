// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    @title UpgradeBase
    @author BLOK Capital DAO
    @notice Base contract for UpgradeFacet
    @dev This base contract allows upgrading the diamond to match the latest state of the FacetRegistry

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
import { DiamondCutStorage } from "src/garden/facets/baseFacets/cut/DiamondCutStorage.sol";
import { DiamondCutBase } from "src/garden/facets/baseFacets/cut/DiamondCutBase.sol";
import { LibDiamond } from "src/garden/libraries/LibDiamond.sol";

/// @notice Thrown when attempting to upgrade but already at the latest version
/// @param registryVersion The registry version that is already applied
error UpgradeFacet_AlreadyAtLatestVersion(uint256 registryVersion);

/// @notice Thrown when the computed hash does not match the provided hash data
error UpgradeFacet_HashMismatch();

/// @notice Thrown when no facet cuts are required for upgrade
error UpgradeFacet_NoFacetCutsRequired();

/// @notice Thrown when a facet is not found
error UpgradeFacet_FacetNotFound();

abstract contract UpgradeBase is DiamondCutBase, IUpgrade {
    /// @notice Emitted when the diamond is upgraded
    /// @param facetCuts The facet cuts applied in the upgrade
    /// @param diamondVersion The previous diamond version
    /// @param diamondVersion The new diamond version
    /// @param registryVersion The current registry version
    event GardenUpgraded(
        IDiamondCut.FacetCut[] facetCuts, uint256 indexed diamondVersion, uint256 indexed registryVersion
    );

    /// @notice Retrieves the upgrade details
    /// @return facetCuts The facet cuts required for the upgrade
    /// @return diamondVersion The current diamond version
    /// @return registryVersion The current registry version
    /// @return hashData The hash data for the upgrade
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
        IFacetRegistry facetRegistry = IFacetRegistry(LibDiamond.layout().facetRegistry);
        diamondVersion = UpgradeStorage.layout().diamondVersion;
        registryVersion = facetRegistry.getCurrentVersion();
        if (diamondVersion >= registryVersion) {
            revert UpgradeFacet_AlreadyAtLatestVersion(registryVersion);
        }
        facetCuts = facetRegistry.getFacetCutsByVersionRange(diamondVersion + 1, registryVersion);
        hashData = keccak256(abi.encode(facetCuts, diamondVersion, registryVersion));
    }

    /// @notice Upgrades the diamond to the latest version
    /// @param _hashData The hash data for the upgrade
    function _upgrade(bytes32 _hashData) internal {
        IFacetRegistry facetRegistry = IFacetRegistry(LibDiamond.layout().facetRegistry);
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

    /// @notice Retrieves the current diamond version
    /// @return The current diamond version
    function _getCurrentVersion() internal view returns (uint256) {
        return UpgradeStorage.layout().diamondVersion;
    }
}
