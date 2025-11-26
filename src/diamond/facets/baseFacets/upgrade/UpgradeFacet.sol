// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title UpgradeFacet
    @author BLOK Capital DAO
    @notice Facet that manages Diamond upgrades by syncing with the FacetRegistry.
    @dev This facet allows upgrading the diamond to match the latest state of the
         FacetRegistry.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

// Local Interfaces
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";
import { IUpgrade } from "src/diamond/facets/baseFacets/upgrade/IUpgrade.sol";

// Local Libraries
import { UpgradeBase } from "src/diamond/facets/baseFacets/upgrade/UpgradeBase.sol";
import { Facet } from "src/diamond/facets/Facet.sol";

contract UpgradeFacet is IUpgrade, UpgradeBase, Facet {
    /// @notice Retrieves the upgrade details including facet cuts, diamond version, registry version, and hash data
    /// @return facetCuts Array of facet cuts required for the upgrade
    /// @return diamondVersion The current diamond version
    /// @return registryVersion The current registry version
    /// @return hashData Hash of the facet cuts and registry version for verification
    function upgradeDetails()
        external
        view
        returns (
            IDiamondCut.FacetCut[] memory facetCuts,
            uint256 diamondVersion,
            uint256 registryVersion,
            bytes32 hashData
        )
    {
        (facetCuts, diamondVersion, registryVersion, hashData) = _upgradeDetails();
    }

    /// @notice Upgrades the diamond to the latest version
    /// @param _hashData The hash of the upgrade details from upgradeDetails() for verification
    function upgrade(bytes32 _hashData) external onlyDiamondOwner ifIndexNotConnected {
        _upgrade(_hashData);
    }

    /// @notice Returns the current upgrade version tracked in facet storage
    /// @return currentVersion The current upgrade version (usually mirrors the FacetRegistry version applied)
    function getCurrentVersion() external view returns (uint256 currentVersion) {
        currentVersion = _getCurrentVersion();
    }
}
