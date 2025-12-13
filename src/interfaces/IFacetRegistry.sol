// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.31;

/*###############################################################################

    @title IFacetRegistry
    @author BLOK Capital DAO
    @notice Interface for Facet Registry

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import { IDiamondCut } from "src/garden/facets/baseFacets/cut/IDiamondCut.sol";

interface IFacetRegistry {
    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    struct FacetAddressAndPosition {
        address facetAddress;
        uint96 functionSelectorPosition; // position in facetFunctionSelectors.functionSelectors array
    }

    struct FacetFunctionSelectors {
        bytes4[] functionSelectors;
        uint256 facetAddressPosition; // position of facetAddress in facetAddresses array
    }

    /// @notice Adds a new facet to the registry.
    /// @param _facetAddress Address of the facet to add.
    /// @param _functionSelectors Function selectors of the facet to add.
    function addFunctions(address _facetAddress, bytes4[] memory _functionSelectors) external;

    /// @notice Removes functions from a facet in the registry.
    /// @param _facetAddress Address of the facet to remove functions from.
    /// @param _functionSelectors Function selectors to remove.
    function replaceFunctions(address _facetAddress, bytes4[] memory _functionSelectors) external;

    /// @notice Removes functions from a facet in the registry.
    /// @param _facetAddress Address of the facet to remove functions from.
    /// @param _functionSelectors Function selectors to remove.
    function removeFunctions(address _facetAddress, bytes4[] memory _functionSelectors) external;

    /// @notice Returns all facets and their selectors.
    /// @return facets_ Array of Facet structs containing facet addresses and their function selectors.
    function getFacets() external view returns (Facet[] memory facets_);

    /// @notice Returns all the function selectors provided by a facet.
    /// @param _facet The facet address.
    /// @return selectors Array of function selectors.
    function getFacetFunctionSelectors(address _facet) external view returns (bytes4[] memory selectors);

    /// @notice Returns all the facet addresses used by the registry.
    /// @return facetAddresses_ Array of facet addresses.
    function getFacetAddresses() external view returns (address[] memory facetAddresses_);

    /// @notice Returns the facet that supports the given selector.
    /// @param _functionSelector The function selector.
    /// @return facetAddress_ The facet address.
    function getFacetAddress(bytes4 _functionSelector) external view returns (address facetAddress_);

    /// @notice Returns base facets
    /// @return baseFacets_ Array of base facet addresses
    function getBaseFacets() external view returns (address[4] memory baseFacets_);

    /// @notice Returns the facet cuts for the version range
    /// @param _startVersion The start version
    /// @param _endVersion The end version
    /// @return facetCuts The facet cuts for the version range
    function getFacetCutsByVersionRange(
        uint256 _startVersion,
        uint256 _endVersion
    )
        external
        view
        returns (IDiamondCut.FacetCut[] memory facetCuts);

    /// @notice Returns if a facet registered or not
    /// @param facet The address of the facet
    /// @return isRegistered True if the facet is registered, false otherwise
    function isFacetRegistered(address facet) external view returns (bool isRegistered);

    /// @notice Checks if a function selector is registered in the registry (any facet)
    /// @param selector The function selector to check
    /// @return isRegistered True if the selector is registered for any facet, false otherwise
    function isSelectorRegistered(bytes4 selector) external view returns (bool isRegistered);

    /// @notice Checks if a function selector is registered for a specific facet
    /// @param facet The address of the facet to check
    /// @param selector The function selector to check
    /// @return isRegistered True if the selector is registered for the specified facet, false otherwise
    function isSelectorRegisteredWithFacet(address facet, bytes4 selector) external view returns (bool isRegistered);

    /// @notice Returns the current version of the registry.
    /// @return version The current version number.
    function getCurrentVersion() external view returns (uint256 version);
}
