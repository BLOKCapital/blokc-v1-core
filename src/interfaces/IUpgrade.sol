//SPDX-License-Identifier: MIT
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

interface IUpgrade {
    /**
     * @notice Trigger the upgrade process to align the diamond with the canonical FacetRegistry.
     * @dev Implementations should perform necessary checks and apply facet add/remove/replace
     *      operations and any required initialization calls.
     */
    function upgrade() external;

    /**
     * @notice Returns the current upgrade version tracked in facet storage.
     * @return The current upgrade version (usually mirrors the FacetRegistry version applied).
     */
    function getCurrentVersion() external view returns (uint256);
}
