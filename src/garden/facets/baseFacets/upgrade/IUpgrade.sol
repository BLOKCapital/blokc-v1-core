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
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";

interface IUpgrade {
    /// @notice Returns the upgrade details: facet cuts to apply, registry version, and hash for verification
    /// @return facetCuts Array of facet cuts required for the upgrade
    /// @return hashData Hash of the facet cuts and garden type for verification
    function upgradeDetails() external view returns (IDiamondCut.FacetCut[] memory facetCuts, bytes32 hashData);

    /// @notice Upgrades the diamond to the latest version
    /// @param _hashData The hash of the upgrade details from upgradeDetails() for verification
    function upgrade(bytes32 _hashData) external;
}
