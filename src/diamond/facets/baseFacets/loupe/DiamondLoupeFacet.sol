// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    @title DiamondLoupeFacet
    @author BLOK Capital DAO (based on EIP-2535 by Nick Mudge)
    @notice Facet that provides diamond inspection functions (loupe functions)
    @dev This facet implements the EIP-2535 required loupe functions and ERC-165
         interface detection. All functions are view-only and provide transparency
         into the diamond's facet structure.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

// Local Interfaces
import { IDiamondLoupe } from "src/diamond/facets/baseFacets/loupe/IDiamondLoupe.sol";
import { IERC165 } from "src/interfaces/IERC165.sol";

// Local Libraries
import { DiamondLoupeBase } from "src/diamond/facets/baseFacets/loupe/DiamondLoupeBase.sol";
import { Facet } from "src/diamond/facets/Facet.sol";

// ============================================================================
// DiamondLoupeFacet
// ============================================================================

contract DiamondLoupeFacet is IDiamondLoupe, IERC165, DiamondLoupeBase, Facet {
    /// @notice Retrieves all the facets and their function selectors
    /// @return facets_ Array of facets and their function selectors
    function facets() external view override returns (IDiamondLoupe.Facet[] memory facets_) {
        facets_ = _facets();
    }

    /// @notice Retrieves all the function selectors provided by a specific facet
    /// @param _facet The facet address to query
    /// @return facetFunctionSelectors_ Array of function selectors for the facet
    function facetFunctionSelectors(address _facet)
        external
        view
        override
        returns (bytes4[] memory facetFunctionSelectors_)
    {
        facetFunctionSelectors_ = _facetFunctionSelectors(_facet);
    }

    /// @notice Retrieves all the facet addresses used by the diamond
    /// @return facetAddresses_ Array of facet addresses
    function facetAddresses() external view override returns (address[] memory facetAddresses_) {
        facetAddresses_ = _facetAddresses();
    }

    /// @notice Retrieves the facet that supports the given function selector
    /// @param _functionSelector The 4-byte function selector to look up
    /// @return facetAddress_ The facet address that implements the selector, or address(0) if not found
    function facetAddress(bytes4 _functionSelector) external view override returns (address facetAddress_) {
        facetAddress_ = _facetAddress(_functionSelector);
    }

    // ========================================================================
    // IERC165 Implementation
    // ========================================================================

    /// @notice Queries if a contract implements an interface
    /// @param _interfaceId The 4-byte interface identifier (e.g., 0x01ffc9a7 for ERC-165)
    /// @return True if the interface is supported, false otherwise
    function supportsInterface(bytes4 _interfaceId) external view override onlyDiamondOwner returns (bool) {
        return _supportsInterface(_interfaceId);
    }
}
