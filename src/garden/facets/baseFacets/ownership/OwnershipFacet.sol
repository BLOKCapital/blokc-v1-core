// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

// Local Interfaces
import { OwnershipBase } from "src/garden/facets/baseFacets/ownership/OwnershipBase.sol";
import { Facet } from "src/garden/facets/Facet.sol";

/**
 * @title OwnershipFacet
 * @author Blok Capital DAO
 * @notice Facet that implements the ERC-173 ownership standard by inheriting from OwnershipBase. This facet provides
 * external functions to transfer ownership and query the current owner, with access control to restrict ownership
 * transfer to the current owner. This facet is included in the base set of facets for all gardens to provide a
 * standardized ownership mechanism.
 */
contract OwnershipFacet is OwnershipBase, Facet {
    /// @notice Transfers ownership of the contract to a new address
    /// @param _newOwner The address of the new owner
    function transferOwnership(address _newOwner) external override onlyGardenOwner {
        _transferOwnership(_newOwner);
    }

    /// @notice Retrieves the address of the current owner
    /// @return owner_ The address of the current owner, or address(0) if ownerless
    function owner() external view override returns (address owner_) {
        owner_ = _owner();
    }
}
