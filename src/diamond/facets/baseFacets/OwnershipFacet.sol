// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title OwnershipFacet
    @author BLOK Capital DAO
    @notice Facet that provides ownership management functions following ERC-173
    @dev This facet implements the ERC-173 standard for contract ownership, allowing
         the current owner to transfer ownership to a new address. Ownership can be
         renounced by transferring to address(0).

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

// Local Interfaces
import { IERC173 } from "src/interfaces/IERC173.sol";

// Local Libraries
import { LibDiamond } from "src/diamond/libraries/LibDiamond.sol";

// ============================================================================
// OwnershipFacet
// ============================================================================

/**
 * @title OwnershipFacet
 * @notice Facet that provides ownership management functions following ERC-173
 * @dev This facet implements the ERC-173 standard for contract ownership management.
 *      It allows the current owner to:
 *      - Query the current owner address
 *      - Transfer ownership to a new address
 *      - Renounce ownership by transferring to address(0)
 *
 *      All state-changing operations are protected by owner-only access control.
 *      Ownership is stored in LibDiamond's diamond storage, ensuring consistency
 *      across all facets that need to check ownership.
 *
 *      Note: Transferring ownership to address(0) effectively renounces ownership,
 *      making the contract ownerless. This is irreversible and should be done with
 *      extreme caution.
 */
contract OwnershipFacet is IERC173 {
    // ========================================================================
    // External Functions
    // ========================================================================

    /**
     * @notice Transfer ownership of the contract to a new address
     * @dev Only the current owner can transfer ownership. The function emits an
     *      OwnershipTransferred event upon successful transfer.
     *
     *      WARNING: Transferring ownership to address(0) will renounce ownership,
     *      making the contract ownerless. This action is irreversible.
     *
     * @param _newOwner The address of the new owner. Can be address(0) to renounce ownership.
     */
    function transferOwnership(address _newOwner) external override {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setContractOwner(_newOwner);
    }

    /**
     * @notice Get the address of the current owner
     * @dev Returns the address that owns the diamond contract. Returns address(0)
     *      if ownership has been renounced.
     * @return owner_ The address of the current owner, or address(0) if ownerless
     */
    function owner() external view override returns (address owner_) {
        owner_ = LibDiamond.contractOwner();
    }
}
