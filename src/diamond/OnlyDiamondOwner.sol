//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title OnlyDiamondOwner
    @author BLOK Capital DAO
    @notice OnlyDiamondOwner facet

################################################################################*/

contract OnlyDiamondOwner {
    modifier onlyDiamondOwner() {
        _;
    }
}
