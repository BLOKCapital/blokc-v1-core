// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title IDiamondLoupe
    @author BLOK Capital DAO (based on EIP-2535 by Nick Mudge)
    @notice Interface for the DiamondLoupeFacet
    @dev This interface is used to query the diamond facets and their function selectors

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

interface IDiamondLoupe {
    /// @notice A struct containing the facet address and its function selectors
    /// @param facetAddress The address of the facet
    /// @param functionSelectors The function selectors of the facet
    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    /// @notice Retrieves all the facets and their function selectors
    /// @return facets_ Array of facets and their function selectors
    function facets() external view returns (Facet[] memory facets_);

    /// @notice Retrieves all the function selectors supported by a specific facet
    /// @param _facet The facet address to query
    /// @return facetFunctionSelectors_ Array of function selectors for the facet
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetFunctionSelectors_);

    /// @notice Retrieves all the facet addresses used by the diamond
    /// @return facetAddresses_ Array of facet addresses
    function facetAddresses() external view returns (address[] memory facetAddresses_);

    /// @notice Retrieves the facet that supports the given selector
    /// @param _functionSelector The function selector to look up
    /// @return facetAddress_ The facet address that implements the selector, or address(0) if not found
    function facetAddress(bytes4 _functionSelector) external view returns (address facetAddress_);
}
