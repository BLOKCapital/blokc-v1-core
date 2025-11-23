//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title Facet
    @author BLOK Capital DAO
    @notice Base facet contract for all facets
    @dev This contract is used as a base for all facets.
         It provides a common interface for all facets.

################################################################################*/

import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { OwnershipStorage } from "src/diamond/facets/baseFacets/ownership/OwnershipStorage.sol";

error Diamond_NotOwner();

abstract contract Facet is ReentrancyGuardUpgradeable {
    modifier onlyDiamondOwner() {
        if (msg.sender != OwnershipStorage.layout().owner) {
            revert Diamond_NotOwner();
        }
        _;
    }
}
