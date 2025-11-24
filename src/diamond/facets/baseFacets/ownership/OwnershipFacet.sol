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
import { OwnershipBase } from "./OwnershipBase.sol";
import { Facet } from "src/diamond/facets/Facet.sol";

contract OwnershipFacet is OwnershipBase, Facet {
    /// @notice Transfers ownership of the contract to a new address
    /// @param _newOwner The address of the new owner
    function transferOwnership(address _newOwner) external override onlyDiamondOwner {
        _transferOwnership(_newOwner);
    }

    /// @notice Retrieves the address of the current owner
    /// @return owner_ The address of the current owner, or address(0) if ownerless
    function owner() external view override returns (address owner_) {
        owner_ = _owner();
    }
}
