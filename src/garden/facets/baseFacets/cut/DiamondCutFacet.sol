// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    @title DiamondCutFacet
    @author BLOK Capital DAO (based on EIP-2535 by Nick Mudge)
    @notice Facet that provides the diamondCut function for managing diamond facets
    @dev This facet allows the owner to add, replace, and remove diamond facets

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

contract DiamondCutFacet is IDiamondCut, DiamondCutBase, Facet {
    /// @notice Intentionally blocked to prevent ambiguity in upgrade flows
    /// @dev This function is not allowed to be called
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
