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
