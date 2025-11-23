//SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/*###############################################################################

    @title IIndexCalculation
    @author BLOK Capital DAO
    @notice Interface for the IndexCalculation contract

################################################################################*/

interface IIndexCalculation {
    /// @notice Get normalized weights for assets
    /// @param componentAddresses Array of component addresses
    /// @return weights Array of weights normalized to 1e18 (100%)
    function getWeights(address[] memory componentAddresses) external view returns (uint256[] memory weights);
}
