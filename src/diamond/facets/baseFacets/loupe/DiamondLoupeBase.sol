//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title DiamondLoupeBase
    @author BLOK Capital DAO
    @notice Base contract for DiamondLoupeFacet

################################################################################*/

import { IDiamondLoupe } from "./IDiamondLoupe.sol";
import { DiamondLoupeStorage } from "./DiamondLoupeStorage.sol";
import { DiamondCutStorage } from "../cut/DiamondCutStorage.sol";

abstract contract DiamondLoupeBase is IDiamondLoupe {
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

    /**
     * @notice Gets all the function selectors provided by a specific facet
     * @dev Returns all function selectors registered for a given facet address.
     *      Returns an empty array if the facet is not registered in the diamond.
     * @param _facet The facet address to query
     * @return facetFunctionSelectors_ Array of function selectors for the facet
     */
    function _facetFunctionSelectors(address _facet) internal view returns (bytes4[] memory facetFunctionSelectors_) {
        facetFunctionSelectors_ = DiamondCutStorage.layout().facetFunctionSelectors[_facet].functionSelectors;
    }

    /**
     * @notice Get all the facet addresses used by the diamond
     * @dev Returns a list of all facet addresses currently installed in the diamond.
     *      Useful for iterating through facets or verifying facet installation.
     * @return facetAddresses_ Array of facet addresses
     */
    function _facetAddresses() internal view returns (address[] memory facetAddresses_) {
        facetAddresses_ = DiamondCutStorage.layout().facetAddresses;
    }

    /**
     * @notice Gets the facet that supports the given function selector
     * @dev Returns the facet address that implements a specific function selector.
     *      Returns address(0) if the selector is not found in any facet.
     * @param _functionSelector The 4-byte function selector to look up
     * @return facetAddress_ The facet address that implements the selector, or address(0) if not found
     */
    function _facetAddress(bytes4 _functionSelector) internal view returns (address facetAddress_) {
        facetAddress_ = DiamondCutStorage.layout().selectorToFacetAndPosition[_functionSelector].facetAddress;
    }

    // ========================================================================
    // IERC165 Implementation
    // ========================================================================

    /**
     * @notice Query if a contract implements an interface
     * @dev Implements ERC-165 interface detection. Returns true if the diamond
     *      supports the given interface ID, false otherwise.
     *
     *      Interface IDs are registered in the diamond storage during initialization
     *      and diamond cuts. Standard interfaces like ERC-165, IDiamondCut, IDiamondLoupe,
     *      IERC173, and IUpgrade are registered automatically.
     *
     * @param _interfaceId The 4-byte interface identifier (e.g., 0x01ffc9a7 for ERC-165)
     * @return True if the interface is supported, false otherwise
     */
    function _supportsInterface(bytes4 _interfaceId) internal view returns (bool) {
        DiamondLoupeStorage.Layout storage ds = DiamondLoupeStorage.layout();
        return ds.supportedInterfaces[_interfaceId];
    }
}
