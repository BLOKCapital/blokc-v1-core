// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    @title Upgrade Interface
    @author BLOK Capital DAO
    @notice Interface for the upgrade facet which allows upgrading the diamond to the
            latest set of facets published in the external FacetRegistry and to query the
            current upgrade version.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

// Local Interfaces
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";

interface IUpgrade {
    /// @notice Returns the upgrade details including facet cuts, diamond version, registry version, and hash data
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
        );

    /// @notice Upgrades the diamond to the latest version
    /// @param _hashData The hash of the upgrade details from upgradeDetails() for verification
    function upgrade(bytes32 _hashData) external;

    /// @notice Returns the current upgrade version tracked in facet storage
    /// @return currentVersion The current upgrade version (usually mirrors the FacetRegistry version applied)
    function getCurrentVersion() external view returns (uint256 currentVersion);
}
