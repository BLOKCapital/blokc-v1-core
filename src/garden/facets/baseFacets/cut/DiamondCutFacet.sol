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

// Local Libraries
import { DiamondCutBase } from "src/garden/facets/baseFacets/cut/DiamondCutBase.sol";
import { Facet } from "src/garden/facets/Facet.sol";

/// @notice Thrown when diamondCut is called
error DiamondCutFacet_DiamondCutNotAllowed();

/**
 * @title DiamondCutFacet
 * @author Blok Capital DAO
 * @notice Facet that implements the IDiamondCut interface but intentionally blocks the diamondCut function
 * to prevent ambiguity in upgrade flows. This facet is included in the base set of facets for all gardens to ensure
 * that the diamondCut function is always present but not callable.
 */
contract DiamondCutFacet is IDiamondCut, DiamondCutBase, Facet {
    /// @inheritdoc IDiamondCut
    function diamondCut(
        FacetCut[] memory _diamondCut,
        address _init,
        bytes calldata _calldata
    )
        external
        override
        onlyGardenOwner
        ifIndexNotConnected
    {
        revert DiamondCutFacet_DiamondCutNotAllowed();
    }
}
