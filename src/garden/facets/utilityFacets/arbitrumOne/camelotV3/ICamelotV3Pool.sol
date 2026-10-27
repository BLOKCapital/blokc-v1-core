// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/// @title ICamelotV3Pool
/// @author BLOK Capital DAO
/// @notice Minimal interface for Camelot V3 (Algebra) pools.
/// @dev Camelot V3 pools do not implement the Uniswap V3 `fee()` or `observe()` methods.
///      The dynamic fee is exposed as the third field of `globalState()`, and TWAP
///      observations are read through `getTimepoints()`.
interface ICamelotV3Pool {
    /// @notice Current pool state. Only the fields used by the facet are declared.
    /// @dev The deployed Algebra variant returns additional fields after `fee`; ABI
    ///      decoding ignores trailing return data, so this prefix works across variants.
    /// @return price Current sqrt price in Q64.96 format
    /// @return tick Current tick
    /// @return fee Current swap fee in hundredths of a bip
    function globalState() external view returns (uint160 price, int24 tick, uint16 fee);

    /// @notice Returns the cumulative tick values at the requested offsets.
    /// @dev Only the tick cumulatives are declared; the deployed Algebra variant also
    ///      returns seconds-per-liquidity, volatility, and volume arrays.
    /// @param secondsAgos Observation offsets in seconds, newest last
    /// @return tickCumulatives Cumulative tick values
    function getTimepoints(uint32[] calldata secondsAgos) external view returns (int56[] memory tickCumulatives);

    /// @notice First token of the pool
    function token0() external view returns (address);

    /// @notice Second token of the pool
    function token1() external view returns (address);
}
