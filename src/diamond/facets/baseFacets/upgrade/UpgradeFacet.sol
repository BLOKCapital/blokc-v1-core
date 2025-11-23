// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title UpgradeFacet
    @author BLOK Capital DAO
    @notice Facet that manages Diamond upgrades by syncing with the FacetRegistry.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

// Local Interfaces
import { IDiamondCut } from "../cut/IDiamondCut.sol";
import { IUpgrade } from "./IUpgrade.sol";

// Local Libraries
import { UpgradeBase } from "./UpgradeBase.sol";
import { Facet } from "src/diamond/facets/Facet.sol";

// ============================================================================
// UpgradeFacet
// ============================================================================

/**
 * @title UpgradeFacet
 * @notice Facet that manages Diamond upgrades by syncing with the FacetRegistry
 * @dev This facet allows upgrading the diamond to match the latest state of the FacetRegistry
 */
contract UpgradeFacet is IUpgrade, UpgradeBase, Facet {
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

    function upgrade(bytes32 _hashData) external onlyDiamondOwner {
        _upgrade(_hashData);
    }

    function getCurrentVersion() external view returns (uint256) {
        return _getCurrentVersion();
    }
}
