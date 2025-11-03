// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title Upgrade Interface
    @author BLOK Capital DAO
    @notice Public interface for the upgrade facet which allows upgrading the diamond to the
            latest set of facets published in the external FacetRegistry and querying the
            current upgrade version.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import { IDiamondCut } from "src/interfaces/IDiamondCut.sol";

interface IUpgrade {
    /**
     * @notice Returns upgrade details including facet cuts, registry version, and verification hash
     * @dev This function calculates the facet cuts needed to upgrade the diamond to match
     *      the latest state of the FacetRegistry. The hash can be used to verify the upgrade
     *      plan before execution using upgrade(bytes32).
     * @return facetCuts Array of facet cuts required for the upgrade
     * @return registryVersion The target registry version for the upgrade
     * @return hashData Hash of the facet cuts and registry version for verification
     */
    function upgradeDetails()
        external
        view
        returns (IDiamondCut.FacetCut[] memory facetCuts, uint256 registryVersion, bytes32 hashData);

    /**
     * @notice Trigger the upgrade process to align the diamond with the canonical FacetRegistry.
     * @dev Verifies the hash before executing to ensure the upgrade plan hasn't changed.
     *      This is the recommended method for upgrades as it provides safety through verification.
     *      Get the hash from upgradeDetails() first, then call this function with the hash.
     *      Note: Passing bytes32(0) will skip hash verification (not recommended for production).
     * @param _hashData The hash of the upgrade details from upgradeDetails() for verification.
     *                  Pass bytes32(0) to skip verification (not recommended for production use)
     */
    function upgrade(bytes32 _hashData) external;

    /**
     * @notice Returns the current upgrade version tracked in facet storage.
     * @return The current upgrade version (usually mirrors the FacetRegistry version applied).
     */
    function getCurrentVersion() external view returns (uint256);
}
