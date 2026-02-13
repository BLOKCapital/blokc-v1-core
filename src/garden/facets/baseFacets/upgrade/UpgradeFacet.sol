// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

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
import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";
import { IUpgrade } from "src/garden/facets/baseFacets/upgrade/IUpgrade.sol";

// Local Libraries
import { UpgradeBase } from "src/garden/facets/baseFacets/upgrade/UpgradeBase.sol";
import { Facet } from "src/garden/facets/Facet.sol";

contract UpgradeFacet is IUpgrade, UpgradeBase, Facet {
    /// @notice Retrieves the upgrade details: facet cuts, registry version, and hash for verification
    function upgradeDetails() external view returns (IDiamondCut.FacetCut[] memory facetCuts, bytes32 hashData) {
        (facetCuts, hashData) = _upgradeDetails();
    }

    /// @notice Upgrades the diamond to the latest version
    /// @param _hashData The hash of the upgrade details from upgradeDetails() for verification
    function upgrade(bytes32 _hashData) external onlyGardenOwner ifIndexNotConnected nonReentrant {
        _upgrade(_hashData);
    }
}
