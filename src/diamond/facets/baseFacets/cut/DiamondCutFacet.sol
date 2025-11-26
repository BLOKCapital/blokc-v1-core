// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
import { IDiamondCut } from "src/diamond/facets/baseFacets/cut/IDiamondCut.sol";

// Local Libraries
import { DiamondCutBase } from "src/diamond/facets/baseFacets/cut/DiamondCutBase.sol";
import { Facet } from "src/diamond/facets/Facet.sol";

contract DiamondCutFacet is IDiamondCut, DiamondCutBase, Facet {
    /// @notice Adds, replaces, or removes any number of functions and optionally executes a function with delegatecall
    /// @param _diamondCut Array of facet cuts to apply. Each cut specifies a facet address, action
    /// (Add/Replace/Remove), and function selectors
    /// @param _init The address of the contract or facet to execute _calldata (optional, can be address(0))
    /// @param _calldata A function call, including function selector and arguments. _calldata is executed with
    /// delegatecall on _init (optional, can be empty)
    function diamondCut(
        FacetCut[] memory _diamondCut,
        address _init,
        bytes calldata _calldata
    )
        external
        override
        onlyDiamondOwner
    {
        _applyDiamondCut(_diamondCut, _init, _calldata);
    }
}
