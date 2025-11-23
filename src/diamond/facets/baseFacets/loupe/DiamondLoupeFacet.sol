// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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

/**
 * @author Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
 * EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
 *
 * The functions in DiamondLoupeFacet MUST be added to a diamond.
 * The EIP-2535 Diamond standard requires these functions.
 */

// Local Interfaces
import { IDiamondLoupe } from "./IDiamondLoupe.sol";
import { IERC165 } from "src/interfaces/IERC165.sol";

// Local Libraries
import { DiamondLoupeBase } from "./DiamondLoupeBase.sol";
import { Facet } from "src/diamond/facets/Facet.sol";

// ============================================================================
// DiamondLoupeFacet
// ============================================================================

/**
 * @title DiamondLoupeFacet
 * @notice Facet that provides diamond inspection functions (loupe functions)
 * @dev A loupe is a small magnifying glass used to look at diamonds.
 *      These functions look at the diamond's internal structure. All functions
 *      are view-only and called frequently by tools for introspection.
 *
 *      This facet implements:
 *      - IDiamondLoupe: Required by EIP-2535 for diamond inspection
 *      - IERC165: Interface detection standard
 *
 *      The functions provide read-only access to the diamond's facet registry,
 *      allowing anyone to inspect which facets are installed and which functions
 *      they provide.
 */
contract DiamondLoupeFacet is IDiamondLoupe, IERC165, DiamondLoupeBase, Facet {
    // ========================================================================
    // IDiamondLoupe Implementation
    // ========================================================================

    /**
     * @notice Gets all facet addresses and their function selectors
     * @dev Returns a complete snapshot of all facets and their selectors in the diamond.
     *      This is useful for tooling and verification of diamond state.
     * @return facets_ Array of Facet structs, each containing a facet address and its function selectors
     */
    function facets() external view override returns (Facet[] memory) {
        return _facets();
    }

    /**
     * @notice Gets all the function selectors provided by a specific facet
     * @dev Returns all function selectors registered for a given facet address.
     *      Returns an empty array if the facet is not registered in the diamond.
     * @param _facet The facet address to query
     * @return facetFunctionSelectors_ Array of function selectors for the facet
     */
    function facetFunctionSelectors(address _facet) external view override returns (bytes4[] memory) {
        return _facetFunctionSelectors(_facet);
    }

    /**
     * @notice Get all the facet addresses used by the diamond
     * @dev Returns a list of all facet addresses currently installed in the diamond.
     *      Useful for iterating through facets or verifying facet installation.
     * @return facetAddresses_ Array of facet addresses
     */
    function facetAddresses() external view override returns (address[] memory) {
        return _facetAddresses();
    }

    /**
     * @notice Gets the facet that supports the given function selector
     * @dev Returns the facet address that implements a specific function selector.
     *      Returns address(0) if the selector is not found in any facet.
     * @param _functionSelector The 4-byte function selector to look up
     * @return facetAddress_ The facet address that implements the selector, or address(0) if not found
     */
    function facetAddress(bytes4 _functionSelector) external view override returns (address facetAddress_) {
        return _facetAddress(_functionSelector);
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
    function supportsInterface(bytes4 _interfaceId) external view override onlyDiamondOwner returns (bool) {
        return _supportsInterface(_interfaceId);
    }
}
