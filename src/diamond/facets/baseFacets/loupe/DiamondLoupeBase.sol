//SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    @title DiamondLoupeBase
    @author BLOK Capital DAO
    @notice Base contract for DiamondLoupeFacet
    @dev This base contract allows querying the diamond facets and their function selectors

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { IDiamondLoupe } from "src/diamond/facets/baseFacets/loupe/IDiamondLoupe.sol";
import { DiamondLoupeStorage } from "src/diamond/facets/baseFacets/loupe/DiamondLoupeStorage.sol";
import { DiamondCutStorage } from "src/diamond/facets/baseFacets/cut/DiamondCutStorage.sol";

abstract contract DiamondLoupeBase is IDiamondLoupe {
    /// @notice Retrieves all the facets and their function selectors
    /// @return facets_ Array of facets and their function selectors
    function _facets() internal view returns (IDiamondLoupe.Facet[] memory facets_) {
        DiamondCutStorage.Layout storage ds = DiamondCutStorage.layout();
        uint256 numFacets = ds.facetAddresses.length;
        facets_ = new Facet[](numFacets);
        for (uint256 i; i < numFacets; i++) {
            address facetAddress_ = ds.facetAddresses[i];
            facets_[i].facetAddress = facetAddress_;
            facets_[i].functionSelectors = ds.facetFunctionSelectors[facetAddress_].functionSelectors;
        }
    }

    /// @notice Retrieves all the function selectors provided by a specific facet
    /// @param _facet The facet address to query
    /// @return facetFunctionSelectors_ Array of function selectors for the facet
    function _facetFunctionSelectors(address _facet) internal view returns (bytes4[] memory facetFunctionSelectors_) {
        facetFunctionSelectors_ = DiamondCutStorage.layout().facetFunctionSelectors[_facet].functionSelectors;
    }

    /// @notice Retrieves all the facet addresses used by the diamond
    /// @return facetAddresses_ Array of facet addresses
    function _facetAddresses() internal view returns (address[] memory facetAddresses_) {
        facetAddresses_ = DiamondCutStorage.layout().facetAddresses;
    }

    /// @notice Retrieves the facet that supports the given function selector
    /// @param _functionSelector The 4-byte function selector to look up
    /// @return facetAddress_ The facet address that implements the selector, or address(0) if not found
    function _facetAddress(bytes4 _functionSelector) internal view returns (address facetAddress_) {
        facetAddress_ = DiamondCutStorage.layout().selectorToFacetAndPosition[_functionSelector].facetAddress;
    }

    /// @notice Queries if a contract implements an interface
    /// @param _interfaceId The 4-byte interface identifier (e.g., 0x01ffc9a7 for ERC-165)
    /// @return True if the interface is supported, false otherwise
    function _supportsInterface(bytes4 _interfaceId) internal view returns (bool) {
        DiamondLoupeStorage.Layout storage ds = DiamondLoupeStorage.layout();
        return ds.supportedInterfaces[_interfaceId];
    }
}
