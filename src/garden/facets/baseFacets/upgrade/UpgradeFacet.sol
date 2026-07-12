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
import { UpgradeStorage } from "src/garden/facets/baseFacets/upgrade/UpgradeStorage.sol";
import { Facet } from "src/garden/facets/Facet.sol";

/// @notice Emitted when the auto-upgrade setting is changed
/// @param enabled Whether automatic upgrades are now enabled
event AutoUpgradeEnabledSet(bool indexed enabled);

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
    function upgrade(bytes32 _hashData) external onlyOwnerUnlessIndexConnected nonReentrant {
        _upgrade(_hashData);
    }

    /// @inheritdoc IUpgrade
    function getModuleVersion(bytes32 moduleId) external view returns (uint256 version) {
        version = _getModuleVersion(moduleId);
    }

    /// @notice Enable or disable automatic upgrades when connected to an index.
    /// @dev Only callable by the garden owner. When enabled, anyone can trigger upgrades
    ///      on this garden (subject to FacetRegistry validation). When disabled (default),
    ///      only the garden owner can upgrade regardless of index connection status.
    /// @param _enabled True to allow non-owner callers to trigger upgrades when connected to an index.
    function setAutoUpgradeEnabled(bool _enabled) external onlyGardenOwner {
        UpgradeStorage.layout().autoUpgradeEnabled = _enabled;
        emit AutoUpgradeEnabledSet(_enabled);
    }
}
