// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title DiamondCutFacet
    @author BLOK Capital DAO (based on EIP-2535 by Nick Mudge)
    @notice Facet that provides the diamondCut function for managing facets
    @dev This is a base facet required by EIP-2535. It provides the ability to add,
         replace, and remove facets from the diamond. All operations are protected
         by owner-only access control.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

/**
 * @author Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
 * EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
 */

// Local Interfaces
import { IDiamondCut } from "src/interfaces/IDiamondCut.sol";

// Local Libraries
import { LibDiamond } from "src/diamond/libraries/LibDiamond.sol";

// ============================================================================
// DiamondCutFacet
// ============================================================================

/**
 * @title DiamondCutFacet
 * @notice Facet that provides the diamondCut function for managing diamond facets
 * @dev This facet is a core component required by EIP-2535. It enables the owner to:
 *      - Add new facets and their function selectors
 *      - Replace existing facet implementations
 *      - Remove facets and function selectors
 *      - Execute initialization code after cuts via delegatecall
 *
 *      All operations are protected by owner-only access control. The actual logic
 *      is implemented in LibDiamond, which validates against the FacetRegistry
 *      to ensure only registered facets and selectors can be used.
 */
contract DiamondCutFacet is IDiamondCut {
    // ========================================================================
    // External Functions
    // ========================================================================

    /**
     * @notice Add/replace/remove any number of functions and optionally execute a function with delegatecall
     * @dev This function is protected by owner-only access control. It performs validation through
     *      LibDiamond which ensures:
     *      - All facets are registered in the FacetRegistry
     *      - All function selectors are registered for their respective facets
     *      - No duplicate selectors are added
     *      - Removed selectors are not still registered in the FacetRegistry
     *
     *      The initialization contract (_init) runs in the diamond's context via delegatecall,
     *      allowing it to modify diamond storage during upgrades.
     *
     * @param _diamondCut Array of facet cuts to apply. Each cut specifies a facet address,
     *                    action (Add/Replace/Remove), and function selectors
     * @param _init The address of the contract or facet to execute _calldata (optional, can be address(0))
     * @param _calldata A function call, including function selector and arguments.
     *                  _calldata is executed with delegatecall on _init (optional, can be empty)
     */
    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external override {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.diamondCut(_diamondCut, _init, _calldata);
    }
}
