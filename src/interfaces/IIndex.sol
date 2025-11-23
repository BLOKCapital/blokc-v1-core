//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################

    @title IIndex
    @author BLOK Capital DAO
    @notice Interface for the Index contract
    @dev This interface provides functions for the Index contract

################################################################################*/

interface IIndex {
    function getAssetWeights() external view returns (uint256[] memory weights);
}
