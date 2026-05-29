// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import { SwapInstruction, QuoteInstruction } from "src/interfaces/ISwapInstruction.sol";

/// @title IBalancerV3
/// @author BLOK Capital DAO
/// @notice Interface for the Balancer V3 DEX facet. Exposes the standardised single-swap
///         and single-quote selectors used by the Garden rebalance / routing path.
///         Multi-hop paths are not supported: the facet reverts when
///         `instruction.pools.length != 1`.
interface IBalancerV3 {
    /// @notice Execute a single-pool Balancer V3 swap.
    /// @dev For `exactOutput == false`: `amountIn` is the exact spend, `amountOut` is the minimum accepted output.
    ///      For `exactOutput == true`:  `amountIn` is the maximum accepted spend, `amountOut` is the exact desired
    /// output. Only single-hop paths are accepted: `instruction.pools.length == 1` and `instruction.tokens.length ==
    /// 2`.
    /// @param instruction The standardised swap instruction.
    function balancerV3Swap(SwapInstruction calldata instruction) external;

    /// @notice Return a best-effort on-chain quote for a single-pool Balancer V3 swap.
    /// @dev Quote is computed from current Balancer Vault live balances as a constant-product
    ///      approximation: `out ≈ in * balanceOut / balanceIn`. This is NOT router-consistent
    ///      for weighted / stable / custom pool types and is intended as a cheap, safety-bounded
    ///      hint for the off-chain routing engine — actual swap execution still enforces
    ///      `amountOut` (min-output for exactIn, exact for exactOut) at the router level.
    /// @param instruction Quote instruction. Must be single-hop.
    /// @return result For `exactOutput == false`: estimated output; for `exactOutput == true`: estimated input.
    function balancerV3Quote(QuoteInstruction calldata instruction) external view returns (uint256 result);
}
