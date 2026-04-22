// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { IBalancerV3 } from "src/garden/facets/utilityFacets/ethereum/balancerV3/IBalancerV3.sol";
import { BalancerV3Base } from "src/garden/facets/utilityFacets/ethereum/balancerV3/BalancerV3Base.sol";
import { Facet } from "src/garden/facets/Facet.sol";
import { SwapInstruction, QuoteInstruction } from "src/interfaces/ISwapInstruction.sol";

/// @title BalancerV3Facet
/// @author BLOK Capital DAO
/// @notice Ethereum mainnet Balancer V3 DEX facet. Single swap selector + single quote selector
///         following the standardised DEX facet shape. Single-hop only — multi-hop instructions
///         revert with `BalancerV3Facet_MultiHopUnsupported`.
contract BalancerV3Facet is IBalancerV3, BalancerV3Base, Facet {
    /// @inheritdoc IBalancerV3
    function balancerV3Swap(SwapInstruction calldata instruction)
        external
        override
        onlyGardenCanCallDexWhenIndexConnected
        nonReentrant
    {
        _balancerV3Swap(instruction);
    }

    /// @inheritdoc IBalancerV3
    function balancerV3Quote(QuoteInstruction calldata instruction) external view override returns (uint256 result) {
        return _balancerV3Quote(instruction);
    }
}
