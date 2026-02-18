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

/// @title IUpgrade
/// @author BLOK Capital DAO
/// @notice Interface for upgrading the diamond to the latest facets from the FacetRegistry
/// @dev Allows querying upgrade details and applying per-module upgrades
interface IUpgrade {
    /// @notice Returns the upgrade details: facet cuts to apply, registry version, and hash for verification
    /// @return facetCuts Array of facet cuts required for the upgrade
    /// @return hashData Hash of the facet cuts and garden type for verification
    function upgradeDetails() external view returns (IDiamondCut.FacetCut[] memory facetCuts, bytes32 hashData);

    /// @notice Upgrades the diamond to the latest version
    /// @param _hashData The hash of the upgrade details from upgradeDetails() for verification
    function upgrade(bytes32 _hashData) external;

    /// @notice Returns the current version of a module installed in garden
    /// @param moduleId The module to query
    /// @return version The current module version
    function getModuleVersion(bytes32 moduleId) external view returns (uint256 version);
}
