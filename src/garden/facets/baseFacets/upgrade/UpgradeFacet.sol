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
import { IUpgrade } from "src/garden/facets/baseFacets/upgrade/IUpgrade.sol";

// Local Libraries
import { UpgradeBase } from "src/garden/facets/baseFacets/upgrade/UpgradeBase.sol";
import { Facet } from "src/garden/facets/Facet.sol";

/**
 * @title UpgradeFacet
 * @author Blok Capital DAO
 * @notice Facet that implements the IUpgrade interface to allow upgrading the diamond to the latest facets from the
 * FacetRegistry. This facet is intended to be included in the base set of facets for all gardens to provide a
 * standardized upgrade mechanism. It inherits from UpgradeBase which contains the internal logic for performing the
 * upgrade, while UpgradeFacet itself provides the external interface with appropriate access control and user-facing
 * error messages.
 */
contract UpgradeFacet is IUpgrade, UpgradeBase, Facet {
    /// @inheritdoc IUpgrade
    function upgradeDetails() external view returns (IDiamondCut.FacetCut[] memory facetCuts, bytes32 hashData) {
        (facetCuts, hashData) = _upgradeDetails();
    }

    /// @inheritdoc IUpgrade
    function upgrade(bytes32 _hashData) external onlyGardenOwner ifIndexNotConnected nonReentrant {
        _upgrade(_hashData);
    }

    /// @inheritdoc IUpgrade
    function getModuleVersion(bytes32 moduleId) external view returns (uint256 version) {
        version = _getModuleVersion(moduleId);
    }
}
